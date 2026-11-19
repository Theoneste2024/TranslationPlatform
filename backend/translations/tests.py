import base64
import os
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.contrib.auth import get_user_model
from django.test import TestCase
from openai import OpenAIError
from rest_framework.test import APIClient

from . import video_service
from . import speech_service
from .models import Advert, Translation
from users.permissions import issue_access_token


User = get_user_model()


def fake_completion(text):
    return SimpleNamespace(
        choices=[SimpleNamespace(message=SimpleNamespace(content=text))]
    )


class TranslationApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        user = User.objects.create_user(
            email="translator@example.com",
            username="translator",
            phone_number="+12025550143",
            country="Rwanda",
            gender="other",
            password="Secure-Translation-Password-2030!",
            is_active=True,
        )
        access_token = issue_access_token(user)
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {access_token}",
        )

    def test_advert_create_and_public_list(self):
        response = self.client.post(
            "/api/v1/adverts/",
            {
                "title": "Prime Advert",
                "description": "A test advert",
                "link_url": "https://example.com",
                "is_active": True,
                "image": SimpleUploadedFile(
                    "advert.txt",
                    b"advert-image-placeholder",
                    content_type="text/plain",
                ),
            },
            format="multipart",
        )
        self.assertEqual(response.status_code, 201)

        public_client = APIClient()
        response = public_client.get("/api/v1/adverts/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 1)
        self.assertEqual(response.json()[0]["title"], "Prime Advert")

    def test_translation_endpoints_reject_anonymous_requests(self):
        client = APIClient()
        requests = (
            (
                "/api/v1/translate_text/",
                {
                    "text": "Hello",
                    "source_language": "English",
                    "target_language": "French",
                },
            ),
            (
                "/api/v1/speech_translate/",
                {
                    "audio": "not-used-without-auth",
                    "source_language": "English",
                    "target_language": "French",
                },
            ),
            (
                "/api/v1/translate_text/speech/",
                {"text": "Bonjour", "target_language": "French"},
            ),
        )
        for path, data in requests:
            with self.subTest(path=path):
                response = client.post(path, data, format="json")
                self.assertEqual(response.status_code, 401)

    @patch("translations.views.OpenAI")
    def test_text_translation_preserves_response_contract(self, openai):
        openai.return_value.chat.completions.create.return_value = fake_completion(
            "Bonjour"
        )

        response = self.client.post(
            "/api/v1/translate_text/",
            {
                "text": "Hello",
                "source_language": "English",
                "target_language": "French",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"translated_text": "Bonjour"})
        self.assertEqual(
            openai.return_value.chat.completions.create.call_args.kwargs["model"],
            "gpt-6.2-sol",
        )
        translation = Translation.objects.get()
        self.assertEqual(translation.kind, Translation.Kind.TEXT)
        self.assertEqual(translation.status, Translation.Status.COMPLETED)
        self.assertEqual(translation.source_text, "Hello")
        self.assertEqual(translation.translated_text, "Bonjour")
        self.assertEqual(translation.source_language, "English")
        self.assertEqual(translation.target_language, "French")

    @patch("translations.views.generate_translation_audio", return_value=b"mp3-bytes")
    def test_text_speech_returns_mp3_audio(self, generate_audio):
        response = self.client.post(
            "/api/v1/translate_text/speech/",
            {"text": "Bonjour", "target_language": "French"},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {
                "audio_base64": base64.b64encode(b"mp3-bytes").decode("ascii"),
                "audio_mime_type": "audio/mpeg",
            },
        )
        generate_audio.assert_called_once_with("Bonjour", "French", "")

    def test_text_speech_rejects_text_over_tts_limit(self):
        response = self.client.post(
            "/api/v1/translate_text/speech/",
            {"text": "a" * 4097, "target_language": "French"},
            format="json",
        )

        self.assertEqual(response.status_code, 400)

    @patch("translations.views.generate_translation_audio", return_value=b"wav-bytes")
    def test_text_speech_passes_kinyarwanda_guidance(self, generate_audio):
        response = self.client.post(
            "/api/v1/translate_text/speech/",
            {"text": "Muraho", "target_language": "Kinyarwanda"},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn(
            "Always use natural, fluent, and grammatically correct Rwandan Kinyarwanda.",
            generate_audio.call_args.args[2],
        )
        self.assertIn(
            "pronounce the letter 'c' like 'ch'",
            generate_audio.call_args.args[2],
        )
        self.assertIn(
            "Follow punctuation when speaking",
            generate_audio.call_args.args[2],
        )

    @patch(
        "translations.views.generate_translation_audio",
        side_effect=speech_service.SpeechGenerationError("provider unavailable"),
    )
    def test_text_speech_reports_provider_errors(self, _generate_audio):
        with self.assertLogs("translations.views", level="ERROR"):
            response = self.client.post(
                "/api/v1/translate_text/speech/",
                {"text": "Bonjour", "target_language": "French"},
                format="json",
            )

        self.assertEqual(response.status_code, 502)
        self.assertEqual(response.json(), {"error": "Speech generation failed."})

    @patch("translations.speech_service.OpenAI")
    def test_speech_service_reads_exact_text_as_mp3(self, openai):
        openai.return_value.audio.speech.create.return_value = SimpleNamespace(
            content=b"mp3-test-audio"
        )
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}):
            audio = speech_service.generate_translation_audio(
                "Muraho",
                "Kinyarwanda",
                "Use natural Rwandan Kinyarwanda.",
            )

        self.assertEqual(audio, b"mp3-test-audio")
        openai.assert_called_once_with(
            api_key="test-key",
            timeout=speech_service.TTS_TIMEOUT_SECONDS,
        )
        request = openai.return_value.audio.speech.create.call_args.kwargs
        self.assertEqual(
            request,
            {
                "model": "gpt-4o-mini-tts",
                "voice": "marin",
                "input": "Muraho",
                "instructions": (
                    "Read the input text exactly as written in Kinyarwanda. Do "
                    "not translate, rewrite, paraphrase, add, or omit any words. "
                    "Speak clearly and naturally.\n\n"
                    "Use natural Rwandan Kinyarwanda.\n\n"
                    "The input is already translated. Use this guidance only "
                    "for pronunciation and natural spoken delivery; do not "
                    "change its wording."
                ),
                "response_format": "mp3",
            },
        )

    @patch("translations.speech_service.OpenAI")
    def test_speech_service_surfaces_provider_errors(self, openai):
        openai.return_value.audio.speech.create.side_effect = OpenAIError(
            "provider unavailable"
        )
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-key"}):
            with self.assertRaises(speech_service.SpeechGenerationError):
                speech_service.generate_translation_audio("Bonjour", "French")

    def test_speech_service_requires_api_key(self):
        with patch.dict(os.environ, {"OPENAI_API_KEY": ""}):
            with self.assertRaises(speech_service.SpeechGenerationError):
                speech_service.generate_translation_audio("Bonjour", "French")

    @patch("translations.views.OpenAI")
    def test_text_translation_uses_kinyarwanda_guidance_for_kinyarwanda(
        self, openai
    ):
        openai.return_value.chat.completions.create.return_value = fake_completion(
            "Ibitaro biri hehe?"
        )

        response = self.client.post(
            "/api/v1/translate_text/",
            {
                "text": "Where is the hospital?",
                "source_language": "English",
                "target_language": "Kinyarwanda",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        prompt = (
            openai.return_value.chat.completions.create.call_args.kwargs["messages"][
                1
            ]["content"]
        )
        self.assertIn(
            "Always use natural, fluent, and grammatically correct Rwandan Kinyarwanda.",
            prompt,
        )
        self.assertIn(
            "Never translate word for word from English, French, or any other language.",
            prompt,
        )

    @patch("translations.views.OpenAI")
    def test_speech_upload_preserves_multipart_contract(self, openai):
        audio_upload = {}

        def transcribe(*, model, file):
            audio_upload["name"] = file.name
            audio_upload["content"] = file.getvalue()
            return SimpleNamespace(text="Hello")

        openai.return_value.audio.transcriptions.create.side_effect = transcribe
        openai.return_value.chat.completions.create.return_value = fake_completion(
            "Bonjour"
        )

        response = self.client.post(
            "/api/v1/speech_translate/",
            {
                "audio": SimpleUploadedFile("voice.wav", b"audio-bytes"),
                "source_language": "English",
                "target_language": "French",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            {"original_text": "Hello", "translated_text": "Bonjour"},
        )
        self.assertEqual(audio_upload["name"], "voice.wav")
        self.assertEqual(audio_upload["content"], b"audio-bytes")
        translation = Translation.objects.get()
        self.assertEqual(translation.kind, Translation.Kind.SPEECH)
        self.assertEqual(translation.status, Translation.Status.COMPLETED)
        self.assertEqual(translation.source_text, "Hello")
        self.assertEqual(translation.translated_text, "Bonjour")
        self.assertEqual(translation.source_file_name, "voice.wav")
        self.assertEqual(translation.source_file_size, len(b"audio-bytes"))

        translate_video.assert_called_once_with(
            b"video-bytes",
            "clip.mp4",
            "English",
            "French",
        )
        translation = Translation.objects.get()
        self.assertEqual(translation.kind, Translation.Kind.VIDEO)
        self.assertEqual(translation.status, Translation.Status.COMPLETED)
        self.assertEqual(translation.source_file_name, "clip.mp4")
        self.assertEqual(translation.source_file_size, len(b"video-bytes"))


class VideoServiceTests(TestCase):
    def test_build_transcript_segments_splits_long_text(self):
        transcript = " ".join(f"word{index}" for index in range(60))

        segments = video_service._build_transcript_segments(transcript)

        self.assertGreaterEqual(len(segments), 2)
        self.assertTrue(all(segment["text"] for segment in segments))

    def test_build_transcript_segments_handles_transcript_objects(self):
        class TranscriptSnippet:
            text = "hello world"
            start = 1.0
            duration = 2.0

        segments = video_service._build_transcript_segments(
            [
                TranscriptSnippet(),
                {"text": "second line", "start": 3.0, "duration": 1.0},
            ]
        )

        self.assertEqual(segments[0], {"text": "hello world", "start": 1.0, "end": 3.0})
        self.assertEqual(segments[1], {"text": "second line", "start": 3.0, "end": 4.0})

    def test_prepare_audio_for_transcription_uses_ffmpeg_for_video_files(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            input_path = os.path.join(temp_dir, "clip.mov")
            with open(input_path, "wb") as file:
                file.write(b"video-bytes")

            def fake_run(command, check, stdout, stderr, **kwargs):
                with open(command[-1], "wb") as file:
                    file.write(b"audio-bytes")
                return SimpleNamespace(returncode=0)

            with patch("translations.video_service.shutil.which", return_value="ffmpeg"), patch(
                "translations.video_service.subprocess.run",
                side_effect=fake_run,
            ):
                audio, filename = video_service._prepare_audio_for_transcription(
                    b"video-bytes",
                    "clip.mov",
                )

        self.assertEqual(audio, b"audio-bytes")
        self.assertEqual(filename, "clip.wav")
