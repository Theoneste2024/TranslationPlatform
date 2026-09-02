import os
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from video_analysis import _build_transcript_segments, _get_transcript_segments, _prepare_audio_for_transcription


class FakeTranscriptSnippet:
    def __init__(self, text: str, start: float, duration: float) -> None:
        self.text = text
        self.start = start
        self.duration = duration


class VideoAnalysisTests(unittest.TestCase):
    def test_build_transcript_segments_splits_long_text(self) -> None:
        text = ' '.join([f'word{i}' for i in range(60)])

        segments = _build_transcript_segments(text)

        self.assertTrue(segments)
        self.assertGreaterEqual(len(segments), 2)
        self.assertTrue(all(segment['text'] for segment in segments))

    def test_build_transcript_segments_handles_transcript_objects(self) -> None:
        transcript = [
            FakeTranscriptSnippet('hello world', 0.0, 2.0),
            {'text': 'second line', 'start': 2.0, 'duration': 2.0},
        ]

        segments = _build_transcript_segments(transcript)

        self.assertEqual(segments[0]['text'], 'hello world')
        self.assertEqual(segments[1]['text'], 'second line')

    def test_get_transcript_segments_requires_openai_transcription(self) -> None:
        with patch('video_analysis._download_youtube_audio', return_value=None), \
             patch('video_analysis._get_transcript', side_effect=AssertionError('transcript fallback should not be used')):
            with self.assertRaises(RuntimeError):
                _get_transcript_segments('abc123', 'auto', object())

    def test_prepare_audio_for_transcription_uses_ffmpeg_for_video_files(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            input_path = os.path.join(temp_dir, 'clip.mov')
            output_path = os.path.join(temp_dir, 'clip.wav')
            with open(input_path, 'wb') as handle:
                handle.write(b'video-bytes')

            def fake_run(cmd, check, stdout, stderr, **kwargs):
                output_file = cmd[-1]
                with open(output_file, 'wb') as handle:
                    handle.write(b'audio-bytes')
                return type('CompletedProcess', (), {'returncode': 0})()

            with patch('video_analysis.shutil.which', return_value='/usr/bin/ffmpeg'), \
                 patch('video_analysis.subprocess.run', side_effect=fake_run):
                audio_bytes, audio_filename = _prepare_audio_for_transcription(b'video-bytes', 'clip.mov')

            self.assertEqual(audio_bytes, b'audio-bytes')
            self.assertEqual(audio_filename, 'clip.wav')


if __name__ == '__main__':
    unittest.main()
