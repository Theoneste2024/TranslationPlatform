from typing import Any

try:
    from firebase_functions import https_fn
except Exception:  # pragma: no cover - local test fallback
    class _HttpsFnStub:
        class Request:
            pass

        class Response:
            def __init__(self, body='', status=200, mimetype='application/json', headers=None):
                self.body = body
                self.status = status
                self.mimetype = mimetype
                self.headers = headers or {}

        @staticmethod
        def on_request():
            def decorator(func):
                return func
            return decorator

    https_fn = _HttpsFnStub()


@https_fn.on_request()
def translate_text(req: Any) -> Any:
    from text_translation import translate_text as translate_text_impl
    return translate_text_impl(req)


@https_fn.on_request()
def speech_translate(req: Any) -> Any:
    from speech_translation import speech_translate as speech_translate_impl
    return speech_translate_impl(req)


@https_fn.on_request()
def analyze_video(req: Any) -> Any:
    from video_analysis import analyze_video as analyze_video_impl
    return analyze_video_impl(req)


@https_fn.on_request()
def health(req: Any) -> Any:
    return https_fn.Response('Firebase Functions are running', status=200)
