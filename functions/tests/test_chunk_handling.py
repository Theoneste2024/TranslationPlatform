import os
import tempfile
import time
import unittest

from services.gemini_service import _is_chunk_file_ready


class ChunkHandlingTests(unittest.TestCase):
    def test_empty_file_is_not_ready(self):
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as handle:
            path = handle.name

        try:
            self.assertFalse(_is_chunk_file_ready(path, min_size_bytes=32, stability_window_seconds=0.05))
        finally:
            os.remove(path)

    def test_stable_non_empty_file_is_ready(self):
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as handle:
            handle.write(b"RIFF\x00\x00\x00\x00WAVEfmt ")
            path = handle.name

        try:
            time.sleep(0.1)
            self.assertTrue(_is_chunk_file_ready(path, min_size_bytes=16, stability_window_seconds=0.05))
        finally:
            os.remove(path)


if __name__ == "__main__":
    unittest.main()
