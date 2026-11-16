import os
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from . import video_service
from .models import Translation
from users.views import _issue_tokens


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
            password="Secure-Translation-Password-2030!",
            email_verified=True,
            is_active=True,
        )
        tokens = _issue_tokens(user)
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {tokens['access']}",
        )

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
                "/api/v1/analyze_video/",
                {
                    "youtube_url": "https://youtu.be/abcdefghijk",
                    "source_language": "English",
                    "target_language": "French",
                },
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
            "gpt-5.4-mini",
        )
        translation = Translation.objects.get()
        self.assertEqual(translation.kind, Translation.Kind.TEXT)
        self.assertEqual(translation.status, Translation.Status.COMPLETED)
        self.assertEqual(translation.source_text, "Hello")
        self.assertEqual(translation.translated_text, "Bonjour")
        self.assertEqual(translation.source_language, "English")
        self.assertEqual(translation.target_language, "French")

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

    @patch("translations.video_service._translate_batch", return_value=["Bonjour"])
    @patch(
        "translations.video_service._get_transcript_segments",
        return_value=[{"text": "Hello", "start": 0.0, "end": 1.0}],
    )
    @patch("translations.video_service.get_client")
    def test_youtube_translation_keeps_ndjson_stream(
        self, _get_client, _get_segments, _translate_batch
    ):
        response = self.client.post(
            "/api/v1/analyze_video/",
            {
                "mode": "translate",
                "youtube_url": "https://youtu.be/abcdefghijk",
                "source_language": "English",
                "target_language": "French",
            },
        )

        self.assertTrue(response.streaming)
        self.assertEqual(response["Content-Type"], "application/x-ndjson")
        body = b"".join(response.streaming_content).decode()
        self.assertIn('"type": "segment"', body)
        self.assertIn('"translated": "Bonjour"', body)
        self.assertTrue(body.rstrip().endswith('{"type": "complete"}'))
        translation = Translation.objects.get()
        self.assertEqual(translation.kind, Translation.Kind.VIDEO)
        self.assertEqual(translation.status, Translation.Status.COMPLETED)
        self.assertEqual(translation.source_url, "https://youtu.be/abcdefghijk")
        self.assertEqual(translation.source_text, "Hello")
        self.assertEqual(translation.translated_text, "Bonjour")
        self.assertEqual(len(translation.segments), 1)

    @patch(
        "translations.views.video_service.translate_uploaded_file",
        return_value={"segments": []},
    )
    def test_video_upload_preserves_multipart_contract(self, translate_video):
        response = self.client.post(
            "/api/v1/analyze_video/",
            {
                "video": SimpleUploadedFile("clip.mp4", b"video-bytes"),
                "source_language": "English",
                "target_language": "French",
            },
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"segments": []})
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
