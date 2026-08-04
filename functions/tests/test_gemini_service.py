import os
import sys
from types import SimpleNamespace

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import services.gemini_service as gemini_service


def test_generate_content_uses_initialized_client(monkeypatch):
    captured = {}

    class FakeClient:
        def __init__(self, api_key):
            self.api_key = api_key

        @property
        def models(self):
            return self

        def generate_content(self, **kwargs):
            captured["kwargs"] = kwargs
            return SimpleNamespace(text="translated")

    monkeypatch.setattr(gemini_service, "client", None)
    monkeypatch.setattr(gemini_service, "GEMINI_API_KEY", "dummy-key")
    monkeypatch.setattr(gemini_service.genai, "Client", lambda api_key: FakeClient(api_key))

    response, model_used = gemini_service._generate_content_with_fallback("hello", "gemini-2.5-flash-lite")

    assert response.text == "translated"
    assert model_used == "gemini-2.5-flash-lite"
    assert captured["kwargs"]["model"] == "gemini-2.5-flash-lite"
