import io
import os
import sys

from flask import Flask

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import routes.video as video_routes


def test_video_translate_stream_accepts_uploaded_video(monkeypatch):
    app = Flask(__name__)
    app.register_blueprint(video_routes.video_bp)

    captured = {}

    def fake_stream_segments(video_path, source_lang, target_lang, model=None):
        captured["path"] = video_path
        yield {
            "type": "segment",
            "index": 0,
            "start": 0.0,
            "end": 1.0,
            "original": "hello",
            "translated": "hola",
            "detected_language": "en",
            "detected_language_name": "English",
            "target_language": target_lang,
            "model": model,
        }
        yield {"type": "complete"}

    monkeypatch.setattr(video_routes, "stream_translated_video_segments", fake_stream_segments)

    client = app.test_client()
    response = client.post(
        "/video-translate-stream",
        data={
            "target_language": "en",
            "video": (io.BytesIO(b"video-data"), "sample.mp4"),
        },
        content_type="multipart/form-data",
    )

    assert response.status_code == 200
    assert "hola" in response.get_data(as_text=True)
    assert captured["path"]
