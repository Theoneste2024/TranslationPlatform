import os
import tempfile
import json
import base64

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

@https_fn.on_request()
def speech_translate(req):
    
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
    }

    if req.method == "OPTIONS":
        return https_fn.Response(
            "",
            status=204,
            headers=headers
        )

    try:
        content_type = req.headers.get("Content-Type", "")
        
        # Supported audio formats for OpenAI
        SUPPORTED_FORMATS = {'.mp3', '.mp4', '.mpeg', '.mpga', '.m4a', '.ogg', '.opus', '.flac', '.pcm', '.wav', '.webm'}

        # Handle multipart/form-data (file upload)
        if "multipart/form-data" in content_type:
            if "audio" not in req.files:
                return https_fn.Response(
                    json.dumps({"error": "Missing 'audio' file in request"}),
                    status=400,
                    mimetype="application/json",
                    headers=headers
                )
            
            audio_file = req.files["audio"]
            source_language = req.form.get("source_language")
            target_language = req.form.get("target_language")
            
            # Validate file format
            filename = audio_file.filename.lower()
            file_extension = None
            for ext in SUPPORTED_FORMATS:
                if filename.endswith(ext):
                    file_extension = ext
                    break
            
            if not file_extension:
                return https_fn.Response(
                    json.dumps({
                        "error": f"Unsupported audio format. Supported formats are: {', '.join(sorted(SUPPORTED_FORMATS))}"
                    }),
                    status=400,
                    mimetype="application/json",
                    headers=headers
                )

            # Save temporary audio with correct extension
            temp_audio = tempfile.NamedTemporaryFile(delete=False, suffix=file_extension)
            audio_file.save(temp_audio.name)
        
        # Handle application/json (base64 encoded audio)
        elif "application/json" in content_type:
            try:
                data = req.get_json()
            except Exception:
                return https_fn.Response(
                    json.dumps({"error": "Invalid JSON body. Request must be valid JSON."}),
                    status=400,
                    mimetype="application/json",
                    headers=headers
                )

            if not isinstance(data, dict):
                return https_fn.Response(
                    json.dumps({"error": "Request JSON must be an object."}),
                    status=400,
                    mimetype="application/json",
                    headers=headers
                )

            audio_base64 = data.get("audio")
            source_language = data.get("source_language")
            target_language = data.get("target_language")

            if not audio_base64:
                return https_fn.Response(
                    json.dumps({"error": "Missing 'audio' field"}),
                    status=400,
                    mimetype="application/json",
                    headers=headers
                )

            # Decode and save temporary audio
            try:
                audio_data = base64.b64decode(audio_base64)
            except Exception:
                return https_fn.Response(
                    json.dumps({"error": "Unable to decode base64 audio data."}),
                    status=400,
                    mimetype="application/json",
                    headers=headers
                )

            temp_audio = tempfile.NamedTemporaryFile(delete=False)
            temp_audio.write(audio_data)
            temp_audio.close()
        
        else:
            return https_fn.Response(
                json.dumps({"error": "Content-Type must be 'multipart/form-data' or 'application/json'"}),
                status=415,
                mimetype="application/json",
                headers=headers
            )

        # Step 1 — Transcribe audio
        client = get_client()

        transcription = client.audio.transcriptions.create(
            model="gpt-4o-mini-transcribe",
            file=open(temp_audio.name, "rb")
        )

        original_text = transcription.text

        # Step 2 — Translate text
        translation = client.chat.completions.create(
            model="gpt-4.1",
            messages=[
                {
                    "role": "system",
                    "content": "You are a professional translator."
                },
                {
                    "role": "user",
                    "content":f"""
                    Translate the following text from {source_language} to {target_language}.

                    - Preserve original meaning
                    - Use natural native expressions
                    - Do NOT explain translation
                    - Return ONLY translated text
                    - For Kinyarwanda, use proper fluent Kinyarwanda
                    - Do not add quotes. 
                    -Do not say 'translation is'.

                    Text:
                    {original_text}
                    """
                }
            ]
        )

        translated_text = translation.choices[0].message.content.strip()

        return https_fn.Response(
            json.dumps({
                "original_text": original_text,
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
