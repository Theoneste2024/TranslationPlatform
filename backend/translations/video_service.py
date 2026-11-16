import base64
import json
import os
import re
import shutil
import subprocess
import tempfile
from typing import Any

try:
    from youtube_transcript_api._errors import IpBlocked, NoTranscriptFound, TranscriptsDisabled
except Exception:  # pragma: no cover
    IpBlocked = NoTranscriptFound = TranscriptsDisabled = Exception


def get_client():
    from openai import OpenAI

    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        raise RuntimeError('OPENAI_API_KEY environment variable is not set')
    return OpenAI(api_key=api_key)


def _parse_video_id(url: str) -> str | None:
    url = url.strip()
    if not url:
        return None

    match = re.search(r'(?:v=|youtu\.be/|/embed/)([A-Za-z0-9_-]{11})', url)
    return match.group(1) if match else None


def _get_transcript(video_id: str, source_language: str | None) -> list[dict[str, Any]]:
    from youtube_transcript_api import YouTubeTranscriptApi

    try:
        api = YouTubeTranscriptApi()
        if source_language and source_language != 'auto':
            return api.fetch(video_id, languages=[source_language])
        return api.fetch(video_id)
    except (NoTranscriptFound, TranscriptsDisabled, IpBlocked):
        return []


def _build_transcript_segments(transcript: list[dict[str, Any]] | str) -> list[dict[str, Any]]:
    if isinstance(transcript, str):
        cleaned = re.sub(r'\s+', ' ', transcript).strip()
        if not cleaned:
            return []

        words = cleaned.split()
        if len(words) <= 25:
            return [{'text': cleaned, 'start': 0.0, 'end': 3.0}]

        segments: list[dict[str, Any]] = []
        for index in range(0, len(words), 25):
            chunk = ' '.join(words[index:index + 25])
            start = index / 25 * 3.0
            end = start + 3.0
            segments.append({'text': chunk, 'start': start, 'end': end})
        return segments

    segments: list[dict[str, Any]] = []
    for item in transcript:
        if isinstance(item, dict):
            text = str(item.get('text', '') or '').strip()
            start = float(item.get('start', 0) or 0)
            duration = float(item.get('duration', 3.0) or 3.0)
        else:
            text = str(getattr(item, 'text', '') or '').strip()
            start = float(getattr(item, 'start', 0.0) or 0.0)
            duration = float(getattr(item, 'duration', 3.0) or 3.0)

        if not text:
            continue
        segments.append({'text': text, 'start': start, 'end': start + duration})
    return segments


def _download_youtube_audio(video_id: str) -> str | None:
    try:
        import yt_dlp
    except Exception:
        return None

    video_url = f'https://www.youtube.com/watch?v={video_id}'
    temp_dir = tempfile.mkdtemp(prefix='yt-audio-', dir=None)
    output_template = os.path.join(temp_dir, 'audio.%(ext)s')
    options = {
        'format': 'bestaudio/best',
        'quiet': True,
        'no_warnings': True,
        'noplaylist': True,
        'outtmpl': output_template,
        'socket_timeout': 20,
        'keepvideo': False,
    }

    try:
        with yt_dlp.YoutubeDL(options) as downloader:
            downloader.extract_info(video_url, download=True)
    except Exception:
        return None

    for filename in os.listdir(temp_dir):
        if filename.startswith('audio.') or filename.endswith('.mp3'):
            return os.path.join(temp_dir, filename)
    return None


def _transcribe_audio_file(client: Any, audio_path: str) -> list[dict[str, Any]]:
    with open(audio_path, 'rb') as handle:
        filename = os.path.basename(audio_path)
        transcription = client.audio.transcriptions.create(
            model='gpt-4o-mini-transcribe',
            file=(filename, handle),
            response_format='json',
        )

    raw_segments = getattr(transcription, 'segments', None) or []
    if raw_segments:
        normalized: list[dict[str, Any]] = []
        for item in raw_segments:
            if isinstance(item, dict):
                text = str(item.get('text', '') or '').strip()
                start = float(item.get('start', 0.0) or 0.0)
                end = float(item.get('end', start + 3.0) or (start + 3.0))
            else:
                text = str(getattr(item, 'text', '') or '').strip()
                start = float(getattr(item, 'start', 0.0) or 0.0)
                end = float(getattr(item, 'end', start + 3.0) or (start + 3.0))
            if text:
                normalized.append({'text': text, 'start': start, 'end': end})
        if normalized:
            return normalized

    transcription_text = str(getattr(transcription, 'text', '') or '').strip()
    if transcription_text:
        return [{'text': transcription_text, 'start': 0.0, 'end': max(3.0, min(30.0, len(transcription_text) / 20.0))}]
    return []


def _get_transcript_segments(video_id: str, source_language: str | None, client: Any) -> list[dict[str, Any]]:
    try:
        transcript = _get_transcript(video_id, source_language)
    except Exception as exc:
        raise RuntimeError(f'Unable to load transcription: {exc}') from exc

    segments = _build_transcript_segments(transcript)
    if segments:
        return segments

    try:
        audio_path = _download_youtube_audio(video_id)
    except Exception as exc:
        raise RuntimeError(f'Unable to download YouTube audio for OpenAI transcription: {exc}') from exc

    if not audio_path:
        raise RuntimeError('Unable to download YouTube audio for OpenAI transcription. This can happen when YouTube blocks access to the video or the video is unavailable.')

    try:
        segments = _transcribe_audio_file(client, audio_path)
    except Exception as exc:
        raise RuntimeError(f'OpenAI transcription failed: {exc}') from exc

    if segments:
        return segments

    raise RuntimeError('OpenAI transcription did not return any segments.')


def _translate_segment(client: Any, text: str, source_language: str, target_language: str) -> str:
    if source_language == 'auto':
        user = (
            f"Detect the source language automatically and translate the following text into {target_language}."
            " Return only the translated text without quotes or extra commentary.\n\n" + text
        )
    else:
        user = (
            f"Translate the following text from {source_language} to {target_language}."
            " Return only the translated text without quotes or extra commentary.\n\n" + text
        )

    response = _create_chat_completion(
        client,
        messages=[
            {'role': 'system', 'content': 'You are a professional translator.'},
            {'role': 'user', 'content': user},
        ],
        temperature=0.0,
        max_tokens=1024,
        model_names=('gpt-5.4-mini',),
    )

    return response.choices[0].message.content.strip()


def _translate_batch(client: Any, batch: list[dict[str, Any]], source_language: str, target_language: str) -> list[str]:
    payload_lines = []
    for index, item in enumerate(batch):
        payload_lines.append(f"{index}. {item['text']}")

    prompt = (
        f"Translate the following transcript segments from {source_language if source_language != 'auto' else 'the detected source language'} to {target_language}."
        " Return a JSON array where each entry has the fields: index, translated. "
        "Do not include any additional explanation or text outside the JSON array.\n\n"
        + '\n'.join(payload_lines)
    )

    response = _create_chat_completion(
        client,
        messages=[
            {'role': 'system', 'content': 'You are a translation assistant that outputs only valid JSON.'},
            {'role': 'user', 'content': prompt},
        ],
        temperature=0.0,
        max_tokens=2048,
        model_names=('gpt-5.4-mini',),
    )

    content = response.choices[0].message.content.strip()
    try:
        data = json.loads(content)
        if isinstance(data, list):
            return [item.get('translated', '').strip() for item in data]
    except json.JSONDecodeError:
        pass

    # fallback to translating segments one by one when JSON parsing fails
    translations = []
    for item in batch:
        translations.append(_translate_segment(client, item['text'], source_language, target_language))
    return translations


def _summarize_text(client: Any, transcript_text: str, target_language: str | None) -> str:
    language_desc = target_language if target_language and target_language != 'auto' else 'English'
    prompt = (
        f"Summarize the following spoken transcript in clear {language_desc}. "
        "Include only the summary, do not add bullet points or extra explanation.\n\n"
        + transcript_text
    )

    response = _create_chat_completion(
        client,
        messages=[
            {'role': 'system', 'content': 'You are a helpful summarization assistant.'},
            {'role': 'user', 'content': prompt},
        ],
        temperature=0.2,
        max_tokens=1024,
    )

    return response.choices[0].message.content.strip()


def _prepare_audio_for_transcription(file_bytes: bytes, filename: str) -> tuple[bytes, str]:
    extension = os.path.splitext(filename or '')[1].lower()
    video_extensions = {'.mp4', '.mov', '.m4v', '.avi', '.mkv', '.webm', '.flv', '.wmv'}
    audio_extensions = {'.mp3', '.wav', '.m4a', '.aac', '.ogg', '.opus', '.flac', '.pcm', '.mpga', '.mpeg', '.mp1', '.mp2'}

    if extension in audio_extensions:
        return file_bytes, filename

    if extension not in video_extensions:
        return file_bytes, filename

    ffmpeg_path = shutil.which('ffmpeg')
    if not ffmpeg_path:
        try:
            from imageio_ffmpeg import get_ffmpeg_exe
        except Exception:
            return file_bytes, filename

        ffmpeg_path = get_ffmpeg_exe()
        if not ffmpeg_path:
            return file_bytes, filename

    with tempfile.TemporaryDirectory(prefix='video-audio-', dir=None) as temp_dir:
        source_path = os.path.join(temp_dir, f'input{extension or ".mp4"}')
        output_name = f'{os.path.splitext(os.path.basename(filename))[0] or "audio"}.wav'
        output_path = os.path.join(temp_dir, output_name)
        with open(source_path, 'wb') as handle:
            handle.write(file_bytes)

        try:
            subprocess.run(
                [ffmpeg_path, '-y', '-loglevel', 'error', '-i', source_path, '-vn', '-ac', '1', '-ar', '16000', output_path],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except (subprocess.CalledProcessError, OSError):
            return file_bytes, filename

        with open(output_path, 'rb') as handle:
            return handle.read(), output_name


def _transcribe_file(client: Any, file_bytes: bytes, filename: str) -> list[dict[str, Any]]:
    from io import BytesIO

    audio_bytes, audio_filename = _prepare_audio_for_transcription(file_bytes, filename)

    with BytesIO(audio_bytes) as buffer:
        buffer.name = audio_filename
        transcription = client.audio.transcriptions.create(
            model='gpt-4o-mini-transcribe',
            file=buffer,
            response_format='json',
        )

    raw_segments = getattr(transcription, 'segments', None) or []
    segments: list[dict[str, Any]] = []
    for item in raw_segments:
        if isinstance(item, dict):
            text = str(item.get('text', '') or '').strip()
            start = float(item.get('start', 0.0) or 0.0)
            end = float(item.get('end', start + 3.0) or (start + 3.0))
        else:
            text = str(getattr(item, 'text', '') or '').strip()
            start = float(getattr(item, 'start', 0.0) or 0.0)
            end = float(getattr(item, 'end', start + 3.0) or (start + 3.0))
        if text:
            segments.append({'text': text, 'start': start, 'end': end})

    if segments:
        return segments

    transcription_text = str(getattr(transcription, 'text', '') or '').strip()
    if transcription_text:
        return [{'text': transcription_text, 'start': 0.0, 'end': max(3.0, min(30.0, len(transcription_text) / 20.0))}]
    return []


def _create_chat_completion(client: Any, *, messages: list[dict[str, str]], temperature: float, max_tokens: int, model_names: tuple[str, ...] | None = None) -> Any:
    last_error: Exception | None = None
    if model_names is None:
        model_names = ('gpt-5.4-mini', 'gpt-4.1-mini', 'gpt-4o-mini', 'gpt-4.1', 'gpt-4o')
    for model in model_names:
        try:
            return client.chat.completions.create(
                model=model,
                messages=messages,
                temperature=temperature,
                max_completion_tokens=max_tokens,
            )
        except Exception as exc:  # pragma: no cover - fallback path for model availability
            last_error = exc
            if 'model' in str(exc).lower() or 'does not exist' in str(exc).lower():
                continue
            raise
    if last_error is not None:
        raise last_error
    raise RuntimeError('OpenAI chat completion failed')


def _create_tts_audio(client: Any, text: str, voice: str = 'alloy', audio_format: str = 'mp3') -> str:
    try:
        tts_response = client.audio.speech.create(
            model='gpt-5.4-mini-tts',
            voice=voice,
            input=text,
            format=audio_format,
        )
    except Exception as exc:
        raise RuntimeError(f'OpenAI TTS failed: {exc}') from exc

    if hasattr(tts_response, 'read'):
        audio_bytes = tts_response.read()
    elif isinstance(tts_response, (bytes, bytearray)):
        audio_bytes = bytes(tts_response)
    else:
        audio_bytes = getattr(tts_response, 'content', None) or getattr(tts_response, 'audio', None) or getattr(tts_response, 'data', None)
        if isinstance(audio_bytes, str):
            audio_bytes = audio_bytes.encode('utf-8')

    if not isinstance(audio_bytes, (bytes, bytearray)):
        raise RuntimeError('TTS response did not include audio bytes.')

    return base64.b64encode(audio_bytes).decode('ascii')


def _translate_text_with_audio(client: Any, text: str, source_language: str, target_language: str) -> tuple[str, str]:
    translated_text = _translate_segment(client, text, source_language, target_language)
    audio_base64 = _create_tts_audio(client, translated_text)
    return translated_text, audio_base64


def translate_youtube_with_audio(video_id: str, source_language: str, target_language: str) -> dict[str, Any]:
    client = get_client()
    transcript_segments = _get_transcript_segments(video_id, source_language, client)
    if not transcript_segments:
        raise RuntimeError('No spoken phrases were detected.')

    segments_data = [
        {'text': item['text'].strip(), 'start': float(item['start']), 'end': float(item['end'])}
        for item in transcript_segments
        if item.get('text', '').strip()
    ]

    if not segments_data:
        raise RuntimeError('No spoken phrases were detected.')

    translations = _translate_batch(client, [{'text': item['text']} for item in segments_data], source_language, target_language)
    translated_segments = []
    for index, source_segment in enumerate(segments_data):
        translated_segments.append({
            'original': source_segment['text'],
            'translated': translations[index] if index < len(translations) else '',
            'start': source_segment['start'],
            'end': source_segment['end'],
        })

    joined_translation = ' '.join(segment['translated'] for segment in translated_segments)
    audio_base64 = _create_tts_audio(client, joined_translation)

    return {'segments': translated_segments, 'audio_base64': audio_base64}


def _stream_json_line(event: dict[str, Any]) -> str:
    return json.dumps(event, ensure_ascii=False) + '\n'


def stream_youtube_translation(video_id: str, source_language: str, target_language: str):
    client = get_client()
    transcript_segments = _get_transcript_segments(video_id, source_language, client)

    def generator():
        yield _stream_json_line({'type': 'status', 'message': 'Preparing video transcript...'})

        segments = [
            {
                'start': float(item['start']),
                'end': float(item['end']),
                'original': item['text'].strip(),
            }
            for item in transcript_segments
            if item.get('text', '').strip()
        ]

        if not segments:
            yield _stream_json_line({'type': 'status', 'message': 'No captions were detected; attempting OpenAI audio transcription...'})
            yield _stream_json_line({'type': 'error', 'error': 'No spoken phrases were detected after the fallback transcription step.'})
            return

        batch_size = 10
        for batch_start in range(0, len(segments), batch_size):
            batch = segments[batch_start:batch_start + batch_size]
            yield _stream_json_line({
                'type': 'status',
                'message': f'Translating segments {batch_start + 1} to {batch_start + len(batch)} of {len(segments)}...'
            })

            translations = _translate_batch(client, [{'text': s['original']} for s in batch], source_language, target_language)

            for index, translated in enumerate(translations):
                segment = batch[index]
                yield _stream_json_line({
                    'type': 'segment',
                    'original': segment['original'],
                    'translated': translated,
                    'start': segment['start'],
                    'end': segment['end'],
                })

        yield _stream_json_line({'type': 'complete'})

    return generator()


def summarize_youtube(video_id: str, target_language: str) -> dict[str, str]:
    client = get_client()
    transcript_segments = _get_transcript_segments(video_id, 'auto', client)

    transcript_text = ' '.join(item['text'].strip() for item in transcript_segments if item.get('text'))
    if not transcript_text:
        raise RuntimeError('No spoken phrases were detected.')

    summary_text = _summarize_text(client, transcript_text, target_language)
    return {'summary_text': summary_text, 'summary_language': target_language or 'Auto'}


def translate_uploaded_file(file_bytes: bytes, filename: str, source_language: str, target_language: str) -> dict[str, Any]:
    client = get_client()
    transcript_segments = _transcribe_file(client, file_bytes, filename or 'video.mp4')
    if not transcript_segments:
        raise RuntimeError('Unable to transcribe uploaded media.')

    translations = _translate_batch(client, [{'text': item['text']} for item in transcript_segments], source_language, target_language)
    segments = []
    for index, segment in enumerate(transcript_segments):
        segments.append({
            'original': segment['text'],
            'translated': translations[index] if index < len(translations) else '',
            'start': segment.get('start', 0.0),
            'end': segment.get('end', 0.0),
        })

    return {'segments': segments}


def translate_uploaded_file_with_audio(file_bytes: bytes, filename: str, source_language: str, target_language: str) -> dict[str, Any]:
    client = get_client()
    transcript_segments = _transcribe_file(client, file_bytes, filename or 'video.mp4')
    if not transcript_segments:
        raise RuntimeError('Unable to transcribe uploaded media.')

    translations = _translate_batch(client, [{'text': item['text']} for item in transcript_segments], source_language, target_language)
    segments = []
    for index, segment in enumerate(transcript_segments):
        segments.append({
            'original': segment['text'],
            'translated': translations[index] if index < len(translations) else '',
            'start': segment.get('start', 0.0),
            'end': segment.get('end', 0.0),
        })

    joined_translation = ' '.join(segment['translated'] for segment in segments)
    audio_base64 = _create_tts_audio(client, joined_translation)

    return {'segments': segments, 'audio_base64': audio_base64}


def summarize_uploaded_file(file_bytes: bytes, filename: str, target_language: str) -> dict[str, str]:
    client = get_client()
    transcript_segments = _transcribe_file(client, file_bytes, filename or 'video.mp4')
    transcript_text = ' '.join(item['text'].strip() for item in transcript_segments if item.get('text'))
    if not transcript_text:
        raise RuntimeError('Unable to transcribe uploaded media.')

    summary_text = _summarize_text(client, transcript_text, target_language)
    return {'summary_text': summary_text, 'summary_language': target_language or 'Auto'}
