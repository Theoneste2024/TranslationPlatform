import base64
import binascii
import json
import logging
from io import BytesIO

from django.http import StreamingHttpResponse
from openai import OpenAI, OpenAIError
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from users.permissions import BearerTokenAuthentication

from . import video_service
from .speech_service import SpeechGenerationError, generate_translation_audio
from .models import Advert, Translation
from .serializers import (
    AdvertSerializer ,
    Base64AudioSerializer,
    SpeechTranslationSerializer,
    TranslationSpeechSerializer,
    TextTranslationSerializer,
    VideoAnalysisSerializer,
)


logger = logging.getLogger(__name__)
KINYARWANDA_TRANSLATION_GUIDANCE = """You are an expert in natural, fluent, and authentic Rwandan Kinyarwanda.

Your task is to communicate and translate information into Kinyarwanda exactly as a native Rwandan speaker would naturally speak in everyday conversations.

Follow these instructions strictly:
1. Always use natural, fluent, and grammatically correct Rwandan Kinyarwanda.
2. Use everyday words, expressions, phrases, and sentence structures commonly used by people in Rwanda.
3. Never translate word for word from English, French, or any other language. Translate the meaning, context, and intention instead.
4. Avoid robotic, artificial, complicated, or textbook-style Kinyarwanda.
5. Make your translations sound like a real Rwandan person speaking naturally to another Rwandan.
6. Understand the context before translating. Pay attention to greetings, emotions, jokes, questions, cultural expressions, and informal conversations.
7. Use correct Kinyarwanda grammar, vocabulary, spelling, pronunciation-friendly wording, and natural sentence flow.
8. When translating spoken conversations, prioritize the way Rwandans actually talk rather than formal written language.
9. Do not invent words or expressions. If you are uncertain about the meaning, ask for clarification.
10. Preserve the original message without adding, removing, or changing its meaning.
11. Respond only in the requested target language unless another language is explicitly requested.
12. Before providing any translation, check whether a native Rwandan speaker would naturally say the sentence that way. If not, rewrite it.
13. When speaking Kinyarwanda, pronounce the letter C/c as /tʃ/, never as /k/. Follow these pronunciation rules:
       ca → /tʃa/
       ci → /tʃi/
       cu → /tʃu/
       ce → /tʃe/
       co → /tʃo/

14. keep the /w/ sound clear in words like Cyangwa, do not change it to an 'l' sound.
IMPORTANT:
Your goal is not simply to translate English into Kinyarwanda. Your goal is to produce authentic, natural, fluent Rwandan Kinyarwanda that sounds like it comes from a native speaker in Rwanda."""
SUPPORTED_AUDIO_FORMATS = {
    ".mp3",
    ".mp4",
    ".mpeg",
    ".mpga",
    ".m4a",
    ".ogg",
    ".opus",
    ".flac",
    ".pcm",
    ".wav",
    ".webm",
}


def _record_translation(
    *,
    kind,
    data,
    status=Translation.Status.COMPLETED,
    source_text="",
    translated_text="",
    summary_text="",
    source_url="",
    source_file=None,
    segments=None,
    audio_base64="",
    error_message="",
):
    return Translation.objects.create(
        kind=kind,
        status=status,
        source_language=data.get("source_language", ""),
        target_language=data.get("target_language", ""),
        source_text=source_text,
        translated_text=translated_text,
        summary_text=summary_text,
        source_url=source_url,
        source_file_name=getattr(source_file, "name", "") if source_file else "",
        source_file_content_type=(
            getattr(source_file, "content_type", "") or "" if source_file else ""
        ),
        source_file_size=getattr(source_file, "size", None) if source_file else None,
        segments=segments or [],
        audio_base64=audio_base64,
        request_metadata={
            key: data[key] for key in ("mode", "audio") if key in data
        },
        error_message=error_message,
    )


def _video_result_fields(result):
    segments = result.get("segments") or []
    return {
        "source_text": result.get("original_text")
        or " ".join(
            str(segment.get("original", "")).strip()
            for segment in segments
            if segment.get("original")
        ),
        "translated_text": result.get("translated_text")
        or " ".join(
            str(segment.get("translated", "")).strip()
            for segment in segments
            if segment.get("translated")
        ),
        "summary_text": result.get("summary_text", ""),
        "segments": segments,
        "audio_base64": result.get("audio_base64", ""),
    }


def _save_streamed_video_result(record, segments, status, error_message=""):
    record.status = status
    record.error_message = error_message
    record.segments = segments
    record.source_text = " ".join(
        segment["original"] for segment in segments if segment["original"]
    )
    record.translated_text = " ".join(
        segment["translated"] for segment in segments if segment["translated"]
    )
    record.save(
        update_fields=(
            "status",
            "error_message",
            "segments",
            "source_text",
            "translated_text",
            "updated_at",
        )
    )


class AdvertListView(APIView):
    authentication_classes = [BearerTokenAuthentication]
    permission_classes = [AllowAny]

    def get(self, request):
        adverts = Advert.objects.filter(is_active=True)
        serializer = AdvertSerializer(adverts, many=True, context={'request': request})
        return Response(serializer.data)

    def post(self, request):
        if not request.user or not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        serializer = AdvertSerializer(
            data=request.data,
            context={'request': request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        advert = serializer.save(created_by=request.user)
        return Response(
            AdvertSerializer(advert, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )


class AdvertDetailView(APIView):
    authentication_classes = [BearerTokenAuthentication]
    permission_classes = [AllowAny]

    def get_object(self, request, advert_id):
        try:
            return Advert.objects.get(pk=advert_id)
        except Advert.DoesNotExist:
            return None

    def get(self, request, advert_id):
        advert = self.get_object(request, advert_id)
        if advert is None or not advert.is_active:
            return Response(
                {'error': 'Advert not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        serializer = AdvertSerializer(advert, context={'request': request})
        return Response(serializer.data)

    def patch(self, request, advert_id):
        advert = self.get_object(request, advert_id)
        if advert is None:
            return Response(
                {'error': 'Advert not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        if not request.user.is_authenticated or (
            advert.created_by_id != request.user.id
            and not request.user.is_superuser
        ):
            return Response(
                {'error': 'Permission denied.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = AdvertSerializer(
            advert,
            data=request.data,
            partial=True,
            context={'request': request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        advert = serializer.save()
        return Response(AdvertSerializer(advert, context={'request': request}).data)

    def delete(self, request, advert_id):
        advert = self.get_object(request, advert_id)
        if advert is None:
            return Response(
                {'error': 'Advert not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        if not request.user.is_authenticated or (
            advert.created_by_id != request.user.id
            and not request.user.is_superuser
        ):
            return Response(
                {'error': 'Permission denied.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        advert.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class HealthView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        return Response({'status': 'ok'})


class TranslateTextView(APIView):
    authentication_classes = [BearerTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = TextTranslationSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        kinyarwanda_guidance = (
            f"\n\n{KINYARWANDA_TRANSLATION_GUIDANCE}\n"
            if data["target_language"].strip().casefold() == "kinyarwanda"
            else ""
        )
        prompt = f"""
Translate the following text from {data['source_language']} to {data['target_language']}.

- Preserve original meaning
- Use natural native expressions
- Do NOT explain translation
- Return ONLY translated text
- For Kinyarwanda, use proper fluent Kinyarwanda
- Do not add quotes.
- Do not say 'translation is'.
{kinyarwanda_guidance}

Text:
{data['text']}
"""

        try:
            client = OpenAI()
            completion = client.chat.completions.create(
                model="gpt-6.2-sol",
                messages=[
                    {"role": "system", "content": "You are a professional translator."},
                    {"role": "user", "content": prompt},
                ],
            )
        except (OpenAIError, RuntimeError) as exc:
            logger.exception("Text translation failed")
            return Response({"error": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        translated_text = completion.choices[0].message.content.strip()
        _record_translation(
            kind=Translation.Kind.TEXT,
            data=data,
            source_text=data["text"],
            translated_text=translated_text,
        )
        return Response({"translated_text": translated_text})


class TranslateTextSpeechView(APIView):
    authentication_classes = [BearerTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = TranslationSpeechSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        target_language = data["target_language"].strip()
        kinyarwanda_guidance = (
            KINYARWANDA_TRANSLATION_GUIDANCE
            if target_language.casefold() == "kinyarwanda"
            else ""
        )

        try:
            audio = generate_translation_audio(
                data["text"],
                target_language,
                kinyarwanda_guidance,
            )
        except SpeechGenerationError:
            logger.exception("Text translation speech generation failed")
            return Response(
                {"error": "Speech generation failed."},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        return Response(
            {
                "audio_base64": base64.b64encode(audio).decode("ascii"),
                "audio_mime_type": "audio/mpeg",
            }
        )


class SpeechTranslateView(APIView):
    authentication_classes = [BearerTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        audio_file = None
        if request.content_type.startswith("multipart/form-data"):
            serializer = SpeechTranslationSerializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

            audio_file = request.FILES.get("audio")
            if audio_file is None:
                return Response(
                    {"error": "Missing 'audio' file in request"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            filename = audio_file.name.lower()
            extension = next(
                (ext for ext in SUPPORTED_AUDIO_FORMATS if filename.endswith(ext)),
                None,
            )
            if extension is None:
                return Response(
                    {
                        "error": (
                            "Unsupported audio format. Supported formats are: "
                            + ", ".join(sorted(SUPPORTED_AUDIO_FORMATS))
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )
            audio_bytes = audio_file.read()
            filename = audio_file.name
        elif request.content_type == "application/json":
            serializer = Base64AudioSerializer(data=request.data)
            if not serializer.is_valid():
                return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            data = serializer.validated_data
            try:
                audio_bytes = base64.b64decode(data["audio"], validate=True)
            except (binascii.Error, ValueError):
                return Response(
                    {"error": "Unable to decode base64 audio data."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            filename = "audio.wav"
        else:
            return Response(
                {
                    "error": (
                        "Content-Type must be 'multipart/form-data' "
                        "or 'application/json'"
                    )
                },
                status=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            )

        languages = serializer.validated_data
        try:
            client = OpenAI()
            with BytesIO(audio_bytes) as audio:
                audio.name = filename
                transcription = client.audio.transcriptions.create(
                    model="gpt-4o-mini-transcribe",
                    file=audio,
                )
            original_text = transcription.text
            completion = client.chat.completions.create(
                model="gpt-6.2-sol",
                messages=[
                    {"role": "system", "content": "You are a professional translator."},
                    {
                        "role": "user",
                        "content": f"""
Translate the following text from {languages['source_language']} to {languages['target_language']}.

- Preserve original meaning
- Use natural native expressions
- Do NOT explain translation
- Return ONLY translated text
- For Kinyarwanda, use proper fluent Kinyarwanda
- Do not add quotes.
- Do not say 'translation is'.
- try to speak Kinyarwanda in a way that is natural, and fluent, avoiding overly formal or literal translations.

Text:
{original_text}
""",
                    },
                ],
            )
        except (OpenAIError, RuntimeError) as exc:
            logger.exception("Speech translation failed")
            return Response({"error": str(exc)}, status=status.HTTP_502_BAD_GATEWAY)

        translated_text = completion.choices[0].message.content.strip()
        _record_translation(
            kind=Translation.Kind.SPEECH,
            data=languages,
            source_text=original_text,
            translated_text=translated_text,
            source_file=audio_file,
        )
        return Response(
            {
                "original_text": original_text,
                "translated_text": translated_text,
            }
        )


class AnalyzeVideoView(APIView):
    authentication_classes = [BearerTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = VideoAnalysisSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        youtube_url = data.get("youtube_url", "").strip()
        video_file = data.get("video")
        if not youtube_url and video_file is None:
            return Response(
                {
                    "error": (
                        "Invalid request. Provide youtube_url or upload a video file."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            if youtube_url:
                video_id = video_service._parse_video_id(youtube_url)
                if not video_id:
                    return Response(
                        {"error": "Invalid YouTube URL."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

                if data["mode"] == "summarize":
                    result = video_service.summarize_youtube(
                        video_id,
                        data["target_language"],
                    )
                    _record_translation(
                        kind=Translation.Kind.VIDEO,
                        data=data,
                        source_url=youtube_url,
                        **_video_result_fields(result),
                    )
                    return Response(result)
                if data["audio"]:
                    result = video_service.translate_youtube_with_audio(
                        video_id,
                        data["source_language"],
                        data["target_language"],
                    )
                    _record_translation(
                        kind=Translation.Kind.VIDEO,
                        data=data,
                        source_url=youtube_url,
                        **_video_result_fields(result),
                    )
                    return Response(result)
                stream = video_service.stream_youtube_translation(
                    video_id,
                    data["source_language"],
                    data["target_language"],
                )

                translation = _record_translation(
                    kind=Translation.Kind.VIDEO,
                    data=data,
                    status=Translation.Status.PROCESSING,
                    source_url=youtube_url,
                )

                def persist_stream():
                    segments = []
                    try:
                        for line in stream:
                            event = json.loads(line)
                            if event.get("type") == "segment":
                                segments.append(
                                    {
                                        "original": event.get("original", ""),
                                        "translated": event.get("translated", ""),
                                        "start": event.get("start", 0),
                                        "end": event.get("end", 0),
                                    }
                                )
                            elif event.get("type") == "complete":
                                _save_streamed_video_result(
                                    translation,
                                    segments,
                                    Translation.Status.COMPLETED,
                                )
                            elif event.get("type") == "error":
                                _save_streamed_video_result(
                                    translation,
                                    segments,
                                    Translation.Status.FAILED,
                                    event.get("error", "Video translation failed."),
                                )
                            yield line
                        if translation.status == Translation.Status.PROCESSING:
                            _save_streamed_video_result(
                                translation,
                                segments,
                                Translation.Status.FAILED,
                                "Translation stream ended before completion.",
                            )
                    except Exception as exc:
                        if translation.status == Translation.Status.PROCESSING:
                            _save_streamed_video_result(
                                translation,
                                segments,
                                Translation.Status.FAILED,
                                str(exc),
                            )
                        raise

                return StreamingHttpResponse(
                    persist_stream(),
                    content_type="application/x-ndjson",
                )

            file_bytes = video_file.read()
            filename = video_file.name or "video.mp4"
            if data["mode"] == "summarize":
                result = video_service.summarize_uploaded_file(
                    file_bytes,
                    filename,
                    data["target_language"],
                )
            elif data["audio"]:
                result = video_service.translate_uploaded_file_with_audio(
                    file_bytes,
                    filename,
                    data["source_language"],
                    data["target_language"],
                )
            else:
                result = video_service.translate_uploaded_file(
                    file_bytes,
                    filename,
                    data["source_language"],
                    data["target_language"],
                )
        except (OpenAIError, OSError, RuntimeError, ValueError) as exc:
            logger.exception("Video analysis failed")
            return Response({"error": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        _record_translation(
            kind=Translation.Kind.VIDEO,
            data=data,
            source_file=video_file,
            **_video_result_fields(result),
        )
        return Response(result)
