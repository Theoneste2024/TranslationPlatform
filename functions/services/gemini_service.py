from google import genai
from config import GEMINI_API_KEY
from pydub import AudioSegment
from services.platform_prompt import build_platform_prompt
import speech_recognition as sr
import tempfile
import os
import sys
import traceback
import gc
import subprocess
import glob
import time
import shutil

# Reduce BLAS/MKL thread and memory pressure for CPU-based whisper inference.
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("KMP_INIT_AT_FORK", "FALSE")

# Use a project-local Hugging Face cache to avoid Windows permission issues.
cache_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "cache", "huggingface")
os.makedirs(cache_dir, exist_ok=True)
os.environ.setdefault("HF_HUB_CACHE", cache_dir)
os.environ.setdefault("HF_HOME", cache_dir)

try:
    from faster_whisper import WhisperModel
except ImportError:
    WhisperModel = None

client = None

_whisper_model = None

GEMINI_MODELS = [
    # "gemini-2.5-flash",
    "gemini-2.5-flash-lite"
]

LANGUAGE_MAP = {
    "en": "English",
    "fr": "French",
    "rw": "Kinyarwanda",
    "sw": "Swahili",
    "ar": "Arabic",
    "es": "Spanish",
    "de": "German",
    "pt": "Portuguese",
    "it": "Italian",
    "zh": "Chinese",
    "ja": "Japanese",
    "ko": "Korean",
    "hi": "Hindi",
    "yo": "Yoruba",
    "ig": "Igbo",
    "ha": "Hausa",
    "am": "Amharic"
}

LANGUAGE_CODES = {
    "en": "en-US",
    "fr": "fr-FR",
    "rw": "rw-RW",
    "sw": "sw-KE",
    "ar": "ar-SA",
    "es": "es-ES",
    "de": "de-DE",
    "pt": "pt-PT",
    "it": "it-IT",
    "zh": "zh-CN",
    "ja": "ja-JP",
    "ko": "ko-KR",
    "hi": "hi-IN",
    "yo": "yo-NG",
    "ig": "ig-NG",
    "ha": "ha-NG",
    "am": "am-ET"
}

LANGUAGE_ALIASES = {
    "english": "en",
    "french": "fr",
    "francais": "fr",
    "kinyarwanda": "rw",
    "rwanda": "rw",
    "swahili": "sw",
    "kiswahili": "sw",
    "arabic": "ar",
    "spanish": "es",
    "german": "de",
    "portuguese": "pt",
    "italian": "it",
    "chinese": "zh",
    "japanese": "ja",
    "korean": "ko",
    "hindi": "hi",
    "yoruba": "yo",
    "igbo": "ig",
    "hausa": "ha",
    "amharic": "am"
}

WHISPER_LANGUAGE_CODES = {
    "af", "am", "ar", "as", "az", "ba", "be", "bg", "bn", "bo", "br", "bs",
    "ca", "cs", "cy", "da", "de", "el", "en", "es", "et", "eu", "fa", "fi",
    "fo", "fr", "gl", "gu", "ha", "haw", "he", "hi", "hr", "ht", "hu", "hy",
    "id", "is", "it", "ja", "jw", "ka", "kk", "km", "kn", "ko", "la", "lb",
    "ln", "lo", "lt", "lv", "mg", "mi", "mk", "ml", "mn", "mr", "ms", "mt",
    "my", "ne", "nl", "nn", "no", "oc", "pa", "pl", "ps", "pt", "ro", "ru",
    "sa", "sd", "si", "sk", "sl", "sn", "so", "sq", "sr", "su", "sv", "sw",
    "ta", "te", "tg", "th", "tk", "tl", "tr", "tt", "uk", "ur", "uz", "vi",
    "yi", "yo", "zh", "yue"
}


def normalize_language(language, default="en"):
    if not language:
        return default

    language = language.strip()
    language_key = language.lower().replace("_", "-")

    if language_key == "auto":
        return default

    if language_key in LANGUAGE_CODES:
        return language_key

    short_code = language_key.split("-")[0]
    if short_code in LANGUAGE_CODES:
        return short_code

    return LANGUAGE_ALIASES.get(language_key, language)


def normalize_whisper_language(language):
    normalized_language = normalize_language(language, default="")

    if not normalized_language:
        return None

    short_code = str(normalized_language).strip().lower().split("-")[0]
    if short_code in WHISPER_LANGUAGE_CODES:
        return short_code

    return None


def get_language_name(language):
    normalized_language = normalize_language(language, default=language)

    return LANGUAGE_MAP.get(
        normalized_language,
        str(language).strip()
    )


def _get_genai_client():
    global client
    if client is not None:
        return client
    if not GEMINI_API_KEY:
        return None
    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        return client
    except Exception as e:
        print(f"Gemini client initialization failed: {e}")
        return None


def _is_chunk_file_ready(chunk_path, min_size_bytes=16000, stability_window_seconds=0.5):
    """Return True only when a chunk file exists, is large enough, has stopped changing, and looks like valid audio."""
    if not chunk_path or not os.path.exists(chunk_path):
        return False

    try:
        file_size = os.path.getsize(chunk_path)
        if file_size < min_size_bytes:
            return False

        deadline = time.time() + stability_window_seconds
        while time.time() < deadline:
            if os.path.getsize(chunk_path) >= min_size_bytes:
                try:
                    mtime = os.path.getmtime(chunk_path)
                    if time.time() - mtime >= stability_window_seconds:
                        break
                except OSError:
                    pass
            time.sleep(0.1)

        try:
            result = subprocess.run(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", chunk_path],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode != 0:
                return False

            duration = float(result.stdout.strip() or "0")
            return duration > 0.1
        except (FileNotFoundError, ValueError, subprocess.TimeoutExpired):
            return True
    except OSError:
        return False


def get_speech_language_code(language):
    normalized_language = normalize_language(language)

    if "-" in normalized_language:
        return normalized_language

    return LANGUAGE_CODES.get(normalized_language, "en-US")


def _get_whisper_model():
    global _whisper_model

    if WhisperModel is None:
        return None

    if _whisper_model is not None:
        return _whisper_model

    default_size = (os.getenv("WHISPER_MODEL_SIZE", "tiny") or "tiny").strip().lower()
    device = os.getenv("WHISPER_DEVICE", "cpu")
    compute_type = os.getenv("WHISPER_COMPUTE_TYPE", "int8")

    candidate_sizes = [default_size]
    for fallback in ["tiny", "base", "small"]:
        if fallback not in candidate_sizes:
            candidate_sizes.append(fallback)

    last_error = None
    for size in candidate_sizes:
        try:
            _whisper_model = WhisperModel(
                size,
                device=device,
                compute_type=compute_type
            )
            return _whisper_model
        except Exception as e:
            last_error = e
            error_text = str(e).lower()
            print(f"WhisperModel({size}) load failed: {e}")
            if "mkl_malloc" in error_text or "memory" in error_text or isinstance(e, MemoryError):
                continue
            raise

    # If we only failed due to memory allocation (MKL/ONNX/alloc), treat as "no model available"
    if last_error is not None:
        last_text = str(last_error).lower()
        if "mkl_malloc" in last_text or "memory" in last_text or isinstance(last_error, MemoryError) or "bad allocation" in last_text:
            print("_get_whisper_model: all candidate WhisperModel sizes failed due to memory; falling back to SR-based transcription.")
            return None
        # Otherwise raise the last error to surface configuration problems
        raise last_error


def _transcribe_with_whisper(video_path, source_lang, model=None):
    whisper_model = _get_whisper_model()
    if whisper_model is None:
        return None

    normalized_source = None
    if source_lang and str(source_lang).strip().lower() != "auto":
        normalized_source = normalize_whisper_language(source_lang)

    segments, info = whisper_model.transcribe(
        video_path,
        language=normalized_source,
        vad_filter=False
    )
    raw_transcript = " ".join(segment.text.strip() for segment in segments).strip()
    if not raw_transcript:
        raise Exception("Could not understand audio from video")

    detected_language = normalize_language(
        getattr(info, "language", None) or normalized_source or source_lang,
        default=normalized_source or "en"
    )
    transcript, punctuation_model_used = punctuate_transcript_with_model(
        raw_transcript,
        detected_language,
        model
    )

    return transcript, detected_language

def translate_text(text, target_lang):

    language_name = get_language_name(target_lang)
    task_instruction = (
        f"Translate the provided text into {language_name}. "
        f"Return only the translated text, keeping meaning, tone, and names accurate."
    )
    prompt = build_platform_prompt(task_instruction, text)

    gemini_client = _get_genai_client()
    if gemini_client is None:
        raise Exception("Gemini API key not configured")

    response = gemini_client.models.generate_content(
        model="gemini-2.5-flash-lite",
        contents=prompt
    )

    return response.text.strip()


def transcribe_video(video_path, source_lang, model=None):
    whisper_result = _transcribe_with_whisper(video_path, source_lang, model)
    if whisper_result is not None:
        return whisper_result

    source_lang = normalize_language(source_lang)

    wav_file = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    wav_file.close()

    try:
        _convert_to_wav(video_path, wav_file.name)

        recognizer = sr.Recognizer()
        with sr.AudioFile(wav_file.name) as source:
            recognizer.adjust_for_ambient_noise(source, duration=0.5)
            audio = recognizer.record(source)

        language_code = get_speech_language_code(source_lang)
        raw_transcript = recognizer.recognize_google(audio, language=language_code)
        transcript, punctuation_model_used = punctuate_transcript_with_model(
            raw_transcript,
            source_lang,
            model
        )

        return transcript, source_lang

    except sr.UnknownValueError:
        raise Exception("Could not understand audio from video")

    except sr.RequestError as e:
        raise Exception(f"Speech recognition service error: {str(e)}")

    finally:
        try:
            if os.path.exists(wav_file.name):
                os.remove(wav_file.name)
        except Exception:
            pass


def translate_video(video_path, source_lang, target_lang, model=None):
    target_lang = normalize_language(target_lang, default=target_lang)

    transcript, detected_language = transcribe_video(video_path, source_lang, model)

    try:
        translated_text, model_used = translate_speech_with_model(
            transcript,
            target_lang,
            model
        )

        return {
            "original_text": transcript,
            "translated_text": translated_text,
            "detected_language": detected_language,
            "detected_language_name": get_language_name(detected_language)
        }

    except Exception:
        raise


def _split_audio_for_transcription(audio_path, base_start_seconds=0.0, max_duration_seconds=6.0):
    """Split larger audio chunks into smaller windows so Whisper stays within memory limits."""
    if not audio_path or not os.path.exists(audio_path):
        return []

    try:
        audio_segment = AudioSegment.from_file(audio_path)
    except Exception:
        return [(audio_path, base_start_seconds, base_start_seconds + max_duration_seconds)]

    duration_ms = len(audio_segment)
    max_duration_ms = int(max_duration_seconds * 1000)
    if duration_ms <= max_duration_ms:
        return [(audio_path, base_start_seconds, base_start_seconds + (duration_ms / 1000.0))]

    chunk_paths = []
    for start_ms in range(0, duration_ms, max_duration_ms):
        end_ms = min(start_ms + max_duration_ms, duration_ms)
        sub_segment = audio_segment[start_ms:end_ms]
        if len(sub_segment) < 200:
            continue

        fd, temp_path = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        sub_segment.export(temp_path, format="wav")
        chunk_paths.append((
            temp_path,
            base_start_seconds + (start_ms / 1000.0),
            base_start_seconds + (end_ms / 1000.0),
        ))

    return chunk_paths or [(audio_path, base_start_seconds, base_start_seconds + (duration_ms / 1000.0))]


def _format_ffmpeg_headers(headers):
    return ''.join(
        f'{key}: {value}\r\n'
        for key, value in (headers or {}).items()
        if key and value
    )


def _stream_local_video_in_chunks(video_path, source_lang, target_lang, model=None, chunk_seconds=6):
    """Split a local video into short audio chunks and yield translated segments progressively."""
    temp_dir = None
    ffmpeg_proc = None
    ffmpeg_error_msg = ""

    try:
        temp_dir = tempfile.mkdtemp()
        pattern = os.path.join(temp_dir, "chunk_%04d.wav")

        ffmpeg_cmd = [
            "ffmpeg",
            "-nostdin",
            "-y",
            "-hide_banner",
            "-loglevel",
            "warning",
            "-i",
            video_path,
            "-map",
            "0:a?",
            "-ac",
            "1",
            "-ar",
            "16000",
            "-c:a",
            "pcm_s16le",
            "-f",
            "segment",
            "-segment_time",
            str(chunk_seconds),
            "-segment_format",
            "wav",
            "-reset_timestamps",
            "1",
            pattern,
        ]

        print(f"[_stream_local_video_in_chunks] Starting FFmpeg for {video_path}", file=sys.stderr)
        ffmpeg_proc = subprocess.Popen(ffmpeg_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        processed = set()
        index = 0
        output_index = 0
        start_time = time.time()
        timeout_seconds = 60
        last_chunk_time = start_time

        while True:
            poll_result = ffmpeg_proc.poll()
            try:
                _, stderr_chunk = ffmpeg_proc.communicate(timeout=0.1)
                if stderr_chunk:
                    ffmpeg_error_msg += stderr_chunk
            except subprocess.TimeoutExpired:
                pass

            current_time = time.time()
            time_since_last_chunk = current_time - last_chunk_time

            files = sorted(glob.glob(os.path.join(temp_dir, "chunk_*.wav")))
            for chunk_path in files:
                if chunk_path in processed:
                    continue

                try:
                    if os.path.getmtime(chunk_path) > current_time - 0.5:
                        continue
                except OSError:
                    pass

                try:
                    transcript, detected_language = transcribe_video(chunk_path, source_lang, model)
                    if not transcript or not transcript.strip():
                        continue
                except Exception as e:
                    print(f"[_stream_local_video_in_chunks] Transcription failed for chunk {index}: {e}", file=sys.stderr)
                    yield {"type": "error", "message": "Transcription failed for chunk", "error": str(e)}
                    continue

                try:
                    translated_text, _ = _translate_texts_with_model([transcript], target_lang, model)
                    translated_text = translated_text[0] if isinstance(translated_text, list) else translated_text
                except Exception as e:
                    print(f"[_stream_local_video_in_chunks] Translation failed for chunk {index}: {e}", file=sys.stderr)
                    translated_text = f"[translation unavailable: {e}]"

                yield {
                    "type": "segment",
                    "index": output_index,
                    "start": float(index * chunk_seconds),
                    "end": float((index + 1) * chunk_seconds),
                    "original": transcript,
                    "translated": translated_text,
                    "detected_language": detected_language,
                    "detected_language_name": get_language_name(detected_language),
                    "target_language": target_lang,
                    "model": model,
                }
                output_index += 1
                processed.add(chunk_path)
                last_chunk_time = current_time
                try:
                    os.remove(chunk_path)
                except Exception:
                    pass

                index += 1

            if poll_result is not None and all(path in processed for path in files):
                break

            if time_since_last_chunk > timeout_seconds and index == 0:
                yield {
                    "type": "error",
                    "message": "Stream timeout",
                    "error": "FFmpeg did not produce any audio chunks within the timeout period.",
                    "fallback_needed": True,
                }
                break

            time.sleep(0.2)
    finally:
        try:
            if ffmpeg_proc and ffmpeg_proc.poll() is None:
                ffmpeg_proc.terminate()
                ffmpeg_proc.wait(timeout=2)
        except Exception:
            pass

        try:
            if temp_dir and os.path.exists(temp_dir):
                for root, _, files in os.walk(temp_dir):
                    for file_name in files:
                        try:
                            os.remove(os.path.join(root, file_name))
                        except Exception:
                            pass
                try:
                    os.rmdir(temp_dir)
                except Exception:
                    pass
        except Exception:
            pass


def _stream_remote_url_in_chunks(stream_source, source_lang, target_lang, model=None, chunk_seconds=6):
    """
    Use ffmpeg to segment a remote audio/video stream into short WAV chunks
    and transcribe/translate each chunk sequentially to preserve streaming.
    """
    temp_dir = None
    ffmpeg_proc = None
    ffmpeg_failed = False
    ffmpeg_error_msg = ""
    
    try:
        temp_dir = tempfile.mkdtemp()
        pattern = os.path.join(temp_dir, "chunk_%04d.wav")

        if isinstance(stream_source, dict):
            stream_url = stream_source.get("url") or ""
            request_headers = dict(stream_source.get("headers") or {})
        else:
            stream_url = str(stream_source or "")
            request_headers = {}

        user_agent = request_headers.get('User-Agent') or (
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/125.0.0.0 Safari/537.36'
        )
        request_headers.setdefault('User-Agent', user_agent)
        request_headers.setdefault('Accept-Language', 'en-US,en;q=0.9')
        request_headers.setdefault('Referer', 'https://www.youtube.com/')
        headers = _format_ffmpeg_headers(request_headers)

        ffmpeg_cmd = [
            "ffmpeg",
            "-nostdin",
            "-y",
            "-hide_banner",
            "-loglevel",
            "warning",
            "-fflags",
            "+nobuffer",
            "-flags",
            "low_delay",
            "-user_agent",
            user_agent,
            "-headers",
            headers,
            "-reconnect",
            "1",
            "-reconnect_streamed",
            "1",
            "-reconnect_at_eof",
            "1",
            "-reconnect_delay_max",
            "2",
            "-rw_timeout",
            str(30_000_000),
            "-http_seekable",
            "0",
            "-protocol_whitelist",
            "file,http,https,tcp,tls,hls,crypto",
            "-probesize",
            "10000000",
            "-analyzeduration",
            "10000000",
            "-i",
            stream_url,
            "-map",
            "0:a?",
            "-ac",
            "1",
            "-ar",
            "16000",
            "-c:a",
            "pcm_s16le",
            "-f",
            "segment",
            "-segment_time",
            str(chunk_seconds),
            "-segment_format",
            "wav",
            "-reset_timestamps",
            "1",
            pattern
        ]

        print(f"[_stream_remote_url_in_chunks] Starting FFmpeg with URL: {stream_url[:80]}...", file=sys.stderr)
        
        try:
            ffmpeg_proc = subprocess.Popen(
                ffmpeg_cmd, 
                stdout=subprocess.PIPE, 
                stderr=subprocess.PIPE,
                text=True
            )
        except FileNotFoundError as e:
            yield {"type": "error", "message": "ffmpeg not found", "error": str(e)}
            return

        processed = set()
        index = 0
        output_index = 0
        start_time = time.time()
        timeout_seconds = 45  # Give ffmpeg a longer window to connect and produce chunks
        last_chunk_time = start_time
        
        # Loop until ffmpeg exits and no new files remain
        while True:
            # Check if FFmpeg process is still running
            poll_result = ffmpeg_proc.poll()
            
            # Get any available output to check for errors
            try:
                _, stderr_chunk = ffmpeg_proc.communicate(timeout=0.1)
                if stderr_chunk:
                    ffmpeg_error_msg += stderr_chunk
            except subprocess.TimeoutExpired:
                pass
            
            # Check for timeout or no chunks produced
            current_time = time.time()
            elapsed = current_time - start_time
            time_since_last_chunk = current_time - last_chunk_time
            
            # If FFmpeg exited but produced no chunks, it likely failed
            if poll_result is not None and len(processed) == 0:
                print(f"[_stream_remote_url_in_chunks] FFmpeg exited without producing chunks. Error output:", file=sys.stderr)
                print(ffmpeg_error_msg[-500:], file=sys.stderr)  # Print last 500 chars of error
                
                error_text = ffmpeg_error_msg.lower()
                if (
                    "unable to open" in error_text
                    or "connection" in error_text
                    or "403" in error_text
                    or "forbidden" in error_text
                ):
                    yield {
                        "type": "error",
                        "message": "Stream connection failed",
                        "error": "FFmpeg could not connect to or read from the stream URL. The URL may have expired or require additional headers.",
                        "fallback_needed": True
                    }
                else:
                    yield {
                        "type": "error",
                        "message": "FFmpeg stream processing failed",
                        "error": ffmpeg_error_msg[-200:] or "Unknown FFmpeg error",
                        "fallback_needed": True
                    }
                ffmpeg_failed = True
                break
            
            files = sorted(glob.glob(os.path.join(temp_dir, "chunk_*.wav")))
            
            for f in files:
                if f in processed:
                    continue
                
                # ensure file is fully written
                mtime = os.path.getmtime(f)
                if time.time() - mtime < 1.0:
                    # wait until file is stable
                    continue

                print(f"[_stream_remote_url_in_chunks] Processing chunk {index}: {os.path.basename(f)}", file=sys.stderr)

                chunk_inputs = _split_audio_for_transcription(
                    f,
                    base_start_seconds=index * chunk_seconds,
                    max_duration_seconds=min(chunk_seconds, 6.0)
                )

                for chunk_path, chunk_start, chunk_end in chunk_inputs:
                    # Energy-based prefilter: skip very quiet chunks to avoid wasted transcription
                    try:
                        seg = AudioSegment.from_file(chunk_path)
                        # if segment is extremely quiet, skip it
                        if seg.dBFS < -44.0:
                            print(f"[_stream_remote_url_in_chunks] Skipping quiet sub-chunk (dBFS={seg.dBFS:.1f}): {os.path.basename(chunk_path)}", file=sys.stderr)
                            try:
                                if chunk_path != f and os.path.exists(chunk_path):
                                    os.remove(chunk_path)
                            except Exception:
                                pass
                            continue
                    except Exception:
                        # If we can't read it, proceed to transcription which will handle errors
                        pass
                    try:
                        transcript, detected_language = transcribe_video(chunk_path, source_lang, model)
                        if not transcript or not transcript.strip():
                            print(f"[_stream_remote_url_in_chunks] Chunk {index} had no speech, skipping", file=sys.stderr)
                            continue
                    except Exception as e:
                        print(f"[_stream_remote_url_in_chunks] Transcription failed for chunk {index}: {e}", file=sys.stderr)
                        # Do not force a download fallback for a single failed chunk.
                        # Continue streaming so later chunks can still succeed.
                        yield {
                            "type": "error",
                            "message": "Transcription failed for chunk",
                            "error": str(e)
                        }
                        continue

                    try:
                        translated_text, _ = _translate_texts_with_model([transcript], target_lang, model)
                        translated_text = translated_text[0] if isinstance(translated_text, list) else translated_text
                    except Exception as e:
                        print(f"[_stream_remote_url_in_chunks] Translation failed for chunk {index}: {e}", file=sys.stderr)
                        translated_text = f"[translation unavailable: {e}]"

                    print(f"[_stream_remote_url_in_chunks] Yielding segment {output_index}: {transcript[:50]}... -> {translated_text[:50]}...", file=sys.stderr)

                    yield {
                        "type": "segment",
                        "index": output_index,
                        "start": float(chunk_start),
                        "end": float(chunk_end),
                        "original": transcript,
                        "translated": translated_text,
                        "detected_language": detected_language,
                        "detected_language_name": get_language_name(detected_language),
                        "target_language": target_lang,
                        "model": model
                    }
                    output_index += 1

                    try:
                        if chunk_path != f and os.path.exists(chunk_path):
                            os.remove(chunk_path)
                    except Exception:
                        pass

                processed.add(f)
                last_chunk_time = current_time  # Update last chunk time
                try:
                    os.remove(f)
                except Exception:
                    pass

                index += 1

            # Break if ffmpeg finished and no unprocessed files remain
            if poll_result is not None and all(f in processed for f in files):
                print(f"[_stream_remote_url_in_chunks] FFmpeg finished. Processed {index} chunks", file=sys.stderr)
                break

            # Break on timeout if no chunks produced
            if time_since_last_chunk > timeout_seconds and index == 0:
                print(f"[_stream_remote_url_in_chunks] Timeout: FFmpeg did not produce chunks after {timeout_seconds}s", file=sys.stderr)
                if "failed to open" in ffmpeg_error_msg.lower() or "404" in ffmpeg_error_msg.lower() or "403" in ffmpeg_error_msg.lower():
                    error_msg = "FFmpeg could not connect to or read from the stream URL. The URL may have expired, be blocked, or require additional headers."
                else:
                    error_msg = "FFmpeg did not produce any audio chunks within the timeout period. The stream may be temporarily slow or blocked."

                yield {
                    "type": "error",
                    "message": "Stream timeout",
                    "error": error_msg,
                    "fallback_needed": True
                }
                ffmpeg_failed = True
                break

            # Sleep briefly to avoid busy loop
            time.sleep(0.2)

    finally:
        try:
            if ffmpeg_proc and ffmpeg_proc.poll() is None:
                print(f"[_stream_remote_url_in_chunks] Terminating FFmpeg", file=sys.stderr)
                ffmpeg_proc.terminate()
                try:
                    ffmpeg_proc.wait(timeout=2)
                except Exception:
                    ffmpeg_proc.kill()
        except Exception:
            pass

        try:
            if temp_dir and os.path.exists(temp_dir):
                for root, _, files in os.walk(temp_dir):
                    for file_name in files:
                        try:
                            os.remove(os.path.join(root, file_name))
                        except Exception:
                            pass
                try:
                    os.rmdir(temp_dir)
                except Exception:
                    pass
        except Exception:
            pass


def stream_translated_video_segments(video_path, source_lang, target_lang, model=None):
    # Try to obtain a WhisperModel; if model loading fails due to memory
    # pressure we gracefully continue with SR-based fallback paths.
    try:
        whisper_model = _get_whisper_model()
    except Exception as e:
        print(f"[stream_translated_video_segments] _get_whisper_model raised: {e}", file=sys.stderr)
        whisper_model = None

    normalized_source = None
    if source_lang and str(source_lang).strip().lower() != "auto":
        normalized_source = normalize_whisper_language(source_lang)

    target_lang = normalize_language(target_lang, default=target_lang)
    # If given a remote stream URL, process it in short chunks via ffmpeg
    if isinstance(video_path, dict) and video_path.get("url"):
        # remote chunker uses transcribe_video() which already includes SR fallback
        yield from _stream_remote_url_in_chunks(video_path, source_lang, target_lang, model)
        return

    if isinstance(video_path, str) and video_path.startswith(('http://', 'https://')):
        # remote chunker uses transcribe_video() which already includes SR fallback
        yield from _stream_remote_url_in_chunks(video_path, source_lang, target_lang, model)
        return

    # Local files are streamed in short windows so subtitle output can begin early.
    if isinstance(video_path, str) and os.path.isfile(video_path):
        yield from _stream_local_video_in_chunks(video_path, source_lang, target_lang, model)
        return

    # If we couldn't load a Whisper model due to memory constraints, fall back
    # to the SR-based transcription for local files so we still return subtitles.
    if whisper_model is None:
        try:
            print("[stream_translated_video_segments] No Whisper model available; using SR fallback for local file.", file=sys.stderr)
            transcript, detected_language = transcribe_video(video_path, source_lang, model)
            try:
                translated_text = translate_text(transcript, target_lang)
            except Exception:
                translated_text = f"[translation unavailable]"

            yield {
                "type": "segment",
                "index": 0,
                "start": 0.0,
                "end": 0.0,
                "original": transcript,
                "translated": translated_text,
                "detected_language": detected_language,
                "detected_language_name": get_language_name(detected_language),
                "target_language": target_lang,
                "model": model
            }
            yield {"type": "complete"}
        except Exception as e:
            print(f"[stream_translated_video_segments] SR fallback failed: {e}", file=sys.stderr)
            traceback.print_exc()
            yield {"type": "error", "message": "Transcription failed", "error": str(e)}
        return
    
    segments = None
    info = None
    try:
        try:
            print(f"[stream_translated_video_segments] Transcribing: {video_path}", file=sys.stderr)
            segments_gen, info = whisper_model.transcribe(
                video_path,
                language=normalized_source,
                vad_filter=False,
                word_timestamps=False,
                chunk_length=5
            )
            # Convert generator to list to catch errors early
            segments = list(segments_gen)
            print(f"[stream_translated_video_segments] Transcription complete, got {len(segments)} segments", file=sys.stderr)
            
        except Exception as e:
            error_text = str(e).lower()
            print(f"[stream_translated_video_segments] initial transcribe() raised: {e}", file=sys.stderr)
            traceback.print_exc()
            # If error looks like memory pressure or allocation, try fallback sizes
            if "memory" in error_text or "alloc" in error_text or isinstance(e, MemoryError):
                # Try progressively smaller models
                fallback_sizes = ["tiny", "small"]
                device = os.getenv("WHISPER_DEVICE", "cpu")
                compute_type = os.getenv("WHISPER_COMPUTE_TYPE", "int8")
                for size in fallback_sizes:
                    try:
                        print(f"[stream_translated_video_segments] retrying transcribe with WhisperModel(size={size})", file=sys.stderr)
                        tmp_model = WhisperModel(size, device=device, compute_type=compute_type)
                        try:
                            segments_gen, info = tmp_model.transcribe(
                                video_path,
                                language=normalized_source,
                                vad_filter=False,
                                word_timestamps=False,
                                chunk_length=5
                            )
                            segments = list(segments_gen)
                            print(f"[stream_translated_video_segments] Fallback transcription succeeded with {size}, got {len(segments)} segments", file=sys.stderr)
                            # success
                            break
                        finally:
                            try:
                                del tmp_model
                                gc.collect()
                            except Exception:
                                pass
                    except Exception as e2:
                        print(f"[stream_translated_video_segments] fallback size {size} failed: {e2}", file=sys.stderr)
                        traceback.print_exc()

                if segments is None or len(segments) == 0:
                    try:
                        print("[stream_translated_video_segments] retrying without VAD using the current model", file=sys.stderr)
                        segments_gen, info = whisper_model.transcribe(
                            video_path,
                            language=normalized_source,
                            word_timestamps=False
                        )
                        segments = list(segments_gen)
                        print(f"[stream_translated_video_segments] No-VAD fallback succeeded, got {len(segments)} segments", file=sys.stderr)
                    except Exception as e3:
                        print(f"[stream_translated_video_segments] no-VAD fallback failed: {e3}", file=sys.stderr)
                        traceback.print_exc()

            # If still no segments, yield an error and stop
            if segments is None or len(segments) == 0:
                yield {
                    "type": "error",
                    "message": "Transcription failed",
                    "error": str(e)
                }
                return
    except Exception as e:
        print(f"[stream_translated_video_segments] unexpected error during transcription: {e}", file=sys.stderr)
        traceback.print_exc()
        yield {
            "type": "error",
            "message": "Transcription failed",
            "error": str(e)
        }
        return

    # Helper to robustly extract text/start/end from various segment shapes
    def _extract_segment_fields(seg):
        text = None
        start = None
        end = None

        # If it's an object with attributes
        if hasattr(seg, 'text'):
            try:
                text = (seg.text or '').strip()
            except Exception:
                text = str(getattr(seg, 'text', '')).strip()
            start = getattr(seg, 'start', None)
            end = getattr(seg, 'end', None)

        elif isinstance(seg, dict):
            text = str(seg.get('text') or seg.get('sentence') or '').strip()
            start = seg.get('start')
            end = seg.get('end')

        elif isinstance(seg, (list, tuple)):
            # search for any string-like element for text and numeric-like for start/end
            for item in seg:
                if isinstance(item, str) and not text:
                    text = item.strip()
                elif (isinstance(item, (int, float)) or (isinstance(item, str) and item.replace('.', '', 1).isdigit())) and start is None:
                    # assign first numeric-like as start then second as end
                    try:
                        val = float(item)
                    except Exception:
                        continue
                    if start is None:
                        start = val
                    elif end is None:
                        end = val

            if not text:
                # fallback: join stringified items
                text = ' '.join(str(x) for x in seg if not isinstance(x, (list, tuple)))[:10000].strip()

        else:
            text = str(seg).strip()

        return text, start, end


    # (moved chunked streaming helper to module level: _stream_remote_url_in_chunks)

    detected_language = normalize_language(
        getattr(info, "language", None) or normalized_source or source_lang,
        default=normalized_source or "en"
    )

    batch_segments = []
    batch_texts = []
    batch_chars = 0
    batch_duration = 0.0

    def flush_batch():
        nonlocal batch_segments, batch_texts, batch_chars, batch_duration
        if not batch_segments:
            return []

        try:
            batch_translations, model_used = _translate_texts_with_model(
                batch_texts,
                target_lang,
                model
            )
        except Exception as e:
            batch_translations = [f"[translation unavailable: {str(e)}]" for _ in batch_segments]
            model_used = model

        translations = []
        for idx, segment_obj in enumerate(batch_segments):
            translated_text = batch_translations[idx] if idx < len(batch_translations) else f"[translation unavailable]"
            # Use stored fields if available
            start = segment_obj.get("start")
            end = segment_obj.get("end")
            original = segment_obj.get("original")

            try:
                start_val = float(start or 0)
            except Exception:
                start_val = 0.0

            try:
                end_val = float(end or start or 0)
            except Exception:
                end_val = start_val

            translations.append({
                "type": "segment",
                "index": segment_obj["index"],
                "start": start_val,
                "end": end_val,
                "original": (original or "").strip(),
                "translated": translated_text,
                "detected_language": detected_language,
                "detected_language_name": get_language_name(detected_language),
                "target_language": target_lang,
                "model": model_used
            })

        batch_segments = []
        batch_texts = []
        batch_chars = 0
        batch_duration = 0.0
        return translations

    for index, segment in enumerate(segments):
        try:
            original_text, start, end = _extract_segment_fields(segment)

            if not original_text:
                continue

            batch_segments.append({"segment": segment, "index": index, "start": start, "end": end, "original": original_text})
            batch_texts.append(original_text)
            batch_chars += len(original_text)

            try:
                s = float(end or start or 0)
                st = float(start or 0)
                batch_duration += s - st
            except Exception:
                # if start/end parsing fails, ignore duration contribution
                pass

            if len(batch_segments) >= 10 or batch_chars >= 2500 or batch_duration >= 45.0:
                for yielded in flush_batch():
                    yield yielded

        except Exception as e:
            # Log segment that triggered the error and continue
            print(f"[stream_translated_video_segments] error processing segment index {index}: {e}", file=sys.stderr)
            traceback.print_exc()
            # Yield an error segment so the client receives context
            yield {
                "type": "error",
                "message": f"Error processing segment {index}: {e}",
                "segment_repr": repr(segment)
            }

    for yielded in flush_batch():
        yield yielded


def summarize_transcript_with_model(transcript, source_lang, model=None):
    language_name = get_language_name(source_lang)
    task_instruction = (
        f"Summarize the provided educational transcript in {language_name}. "
        f"Keep the important ideas, names, and steps, and return only the summary."
    )
    prompt = build_platform_prompt(task_instruction, transcript)

    response, model_used = _generate_content_with_fallback(prompt, model)

    return response.text.strip(), model_used


def summarize_video(video_path, source_lang, model=None):
    transcript, detected_language = transcribe_video(video_path, source_lang, model)
    summary, model_used = summarize_transcript_with_model(
        transcript,
        detected_language,
        model
    )

    return {
        "original_text": transcript,
        "summary_text": summary,
        "detected_language": detected_language,
        "detected_language_name": get_language_name(detected_language)
    }


def _convert_to_wav(input_path, output_path):
    if not input_path or not os.path.exists(input_path):
        raise Exception("Audio input file does not exist")

    if os.path.getsize(input_path) < 100:
        raise Exception("Audio input file is empty")

    try:
        audio = AudioSegment.from_file(input_path)
        if len(audio) <= 0:
            raise Exception("Audio input has zero duration")
        audio = audio.set_channels(1)
        audio = audio.set_frame_rate(16000)
        audio.export(output_path, format="wav")

        if not os.path.exists(output_path) or os.path.getsize(output_path) < 100:
            raise Exception("Converted WAV output is empty")
        return
    except Exception as first_error:
        print(f"pydub conversion failed for {input_path}: {first_error}", file=sys.stderr)

    try:
        ffmpeg_cmd = [
            "ffmpeg",
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            input_path,
            "-vn",
            "-ac",
            "1",
            "-ar",
            "16000",
            "-f",
            "wav",
            output_path,
        ]
        proc = subprocess.run(ffmpeg_cmd, capture_output=True, text=True, timeout=30)
        if proc.returncode != 0:
            raise Exception(proc.stderr.strip() or proc.stdout.strip() or "ffmpeg conversion failed")

        if not os.path.exists(output_path) or os.path.getsize(output_path) < 100:
            raise Exception("Converted WAV output is empty")
    except Exception as second_error:
        raise Exception(f"Could not convert audio chunk: {second_error}") from second_error


def _get_model_order(preferred_model=None):
    if preferred_model and preferred_model in GEMINI_MODELS:
        return [preferred_model] + [
            model for model in GEMINI_MODELS
            if model != preferred_model
        ]

    return GEMINI_MODELS


def _generate_content_with_fallback(prompt, preferred_model=None):
    last_error = None
    gemini_client = _get_genai_client()
    if gemini_client is None:
        raise RuntimeError("Gemini API key not configured")

    for model in _get_model_order(preferred_model):
        try:
            response = gemini_client.models.generate_content(
                model=model,
                contents=prompt
            )
            return response, model

        except Exception as e:
            last_error = e
            error_text = str(e).lower()
            if "503" not in error_text and "unavailable" not in error_text:
                raise

    raise last_error


def _translate_texts_with_model(texts, target_lang, model=None):
    if not texts:
        return [], None

    target_lang = normalize_language(target_lang, default=target_lang)
    language_name = get_language_name(target_lang)
    task_instruction = (
        f"Translate each sentence into {language_name}. "
        f"Return the translations in the same order, separated by |||, preserving meaning and names."
    )
    prompt = build_platform_prompt(task_instruction, "\n".join(texts))

    try:
        response, model_used = _generate_content_with_fallback(prompt, model)

        # Be defensive: response may not always be the expected object
        translated_text = getattr(response, 'text', None)
        if translated_text is None:
            # Fallback to stringifying the response for logging and parsing
            translated_text = str(response)

        translated_text = translated_text.strip()

        # Keep empty parts so we preserve ordering even when translations are empty
        parts = [part.strip() for part in translated_text.split('|||')]

        if len(parts) != len(texts):
            print(
                f"[translate_texts] split parts count mismatch: got {len(parts)}, expected {len(texts)}",
                file=sys.stderr
            )
            print("[translate_texts] translated_text repr:\n", repr(translated_text), file=sys.stderr)
            # Fallback: translate each sentence individually
            translated_segments = []
            last_used = model_used
            for text in texts:
                try:
                    translated, last_used = translate_speech_with_model(text, target_lang, model)
                except Exception as e:
                    print(f"[translate_texts] per-sentence translation failed: {e}", file=sys.stderr)
                    translated = f"[translation unavailable: {e}]"
                translated_segments.append(translated)
            return translated_segments, last_used

        return parts, model_used

    except Exception as e:
        print("[translate_texts] exception while calling model:", str(e), file=sys.stderr)
        traceback.print_exc()
        # Fall back to per-sentence translation when the batch call fails
        translated_segments = []
        last_used = model
        for text in texts:
            try:
                translated, last_used = translate_speech_with_model(text, target_lang, model)
            except Exception as e2:
                print(f"[translate_texts] per-sentence fallback failed: {e2}", file=sys.stderr)
                translated = f"[translation unavailable: {e2}]"
            translated_segments.append(translated)

        return translated_segments, last_used


def punctuate_transcript_with_model(transcript, source_lang, model=None):
    language_name = get_language_name(source_lang)
    task_instruction = (
        f"Restore punctuation and capitalization for a transcript in {language_name}. "
        f"Do not translate it, and return only the punctuated transcript."
    )
    prompt = build_platform_prompt(task_instruction, transcript)

    response, model_used = _generate_content_with_fallback(prompt, model)

    return response.text.strip(), model_used


def punctuate_transcript(transcript, source_lang):
    punctuated_text, _ = punctuate_transcript_with_model(
        transcript,
        source_lang
    )

    return punctuated_text


def translate_speech_with_model(transcript, target_lang, model=None):

    target_lang = normalize_language(target_lang, default=target_lang)
    language_name = get_language_name(target_lang)
    task_instruction = (
        f"Translate the spoken sentence into {language_name}. "
        f"Return only the translation, preserving meaning, tone, and names."
    )
    prompt = build_platform_prompt(task_instruction, transcript)

    response, model_used = _generate_content_with_fallback(prompt, model)

    return response.text.strip(), model_used


def translate_speech(transcript, target_lang):
    translated_text, _ = translate_speech_with_model(transcript, target_lang)

    return translated_text
