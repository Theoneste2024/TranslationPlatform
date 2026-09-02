import os
import json

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

_client = None


def get_client():
    global _client
    if _client is None:
        from openai import OpenAI

        api_key = os.environ.get('OPENAI_API_KEY')
        if not api_key:
            raise RuntimeError('OPENAI_API_KEY environment variable is not set')

        _client = OpenAI(api_key=api_key)
    return _client


def _build_response(body, status=200, mimetype='application/json', headers=None):
    return https_fn.Response(
        json.dumps(body) if isinstance(body, (dict, list)) else body,
        status=status,
        mimetype=mimetype,
        headers=headers or {}
    )


@https_fn.on_request()
def translate_text(req):

    # ✅ CORS HEADERS
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
    }

    # ✅ Handle preflight request
    if req.method == "OPTIONS":
        return _build_response(
            "",
            status=204,
            headers=headers
        )

    try:
        try:
            data = req.get_json()
        except Exception:
            return _build_response(
                {"error": "Invalid JSON body. Request must be valid JSON."},
                status=400,
                headers=headers
            )

        if not isinstance(data, dict):
            return _build_response(
                {"error": "Request JSON must be an object."},
                status=400,
                headers=headers
            )

        text = data.get("text")
        source_language = data.get("source_language")
        target_language = data.get("target_language")

        if not text:
            return _build_response(
                {"error": "No text provided"},
                status=400,
                headers=headers
            )
        prompt = f"""
        Translate the following text from {source_language} to {target_language}.

        - Preserve original meaning
        - Use natural native expressions
        - Do NOT explain translation
        - Return ONLY translated text
        - For Kinyarwanda, use proper fluent Kinyarwanda
        - Do not add quotes. 
        -Do not say 'translation is'.

        Text:
        {text}
        """

        response = get_client().chat.completions.create(
            model="gpt-5.4-mini",
            messages=[
                {
                    "role": "system",
                    "content": "You are a professional translator."
                },
                {
                    "role": "user",
                    "content":prompt
                }
            ]
        )

        translated_text = response.choices[0].message.content.strip()

        return https_fn.Response(
            json.dumps({
                "translated_text": translated_text
            }),
            status=200,
            mimetype="application/json",
            headers=headers
        )

    except Exception as e:
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
            mimetype="application/json",
            headers=headers
        )
