from flask import Blueprint, request, jsonify
from services.gemini_service import (
    get_speech_language_code,
    punctuate_transcript,
    translate_speech
)
from pydub import AudioSegment
import speech_recognition as sr
import tempfile
import base64
import os

speech_bp = Blueprint("speech_bp", __name__)

# ==========================================
# SUPPORTED AUDIO FORMATS
# ==========================================
SUPPORTED_FORMATS = {
    '.mp3', '.mp4', '.mpeg', '.mpga', '.m4a',
    '.ogg', '.opus', '.flac', '.pcm', '.wav',
    '.webm', '.aac', '.amr'
}

# ==========================================
# LANGUAGE MAP
# ==========================================
LANGUAGE_CODES = {
    "en": "en-US",
    "fr": "fr-FR",
    "rw": "rw-RW",
    "sw": "sw-KE",
    "ar": "ar-SA",
    "es": "es-ES",
    "de": "de-DE"
}

# ==========================================
# CONVERT AUDIO TO WAV
# ==========================================
def convert_to_wav(input_path, output_path):
    audio = AudioSegment.from_file(input_path)

    audio = audio.set_channels(1)
    audio = audio.set_frame_rate(16000)

    audio.export(output_path, format="wav")


# ==========================================
# SPEECH TRANSLATION
# ==========================================
@speech_bp.route("/speech-translate", methods=["POST"])
def speech_translate():

    temp_input = None
    wav_path = None

    try:

        content_type = request.headers.get("Content-Type", "")

        # ======================================
        # MULTIPART FORM DATA
        # ======================================
        if "multipart/form-data" in content_type:

            if "audio" not in request.files:
                return jsonify({
                    "error": "Missing audio file"
                }), 400

            audio_file = request.files["audio"]

            source_language = request.form.get(
                "source_language"
            )

            target_language = request.form.get(
                "target_language"
            )

            print("Source Language:", source_language)
            print("Target Language:", target_language)

            if not source_language:
                return jsonify({
                    "error": "Missing source_language"
                }), 400

            if not target_language:
                return jsonify({
                    "error": "Missing target_language"
                }), 400

            filename = audio_file.filename.lower()

            file_extension = next(
                (
                    ext for ext in SUPPORTED_FORMATS
                    if filename.endswith(ext)
                ),
                None
            )

            if not file_extension:
                return jsonify({
                    "error": "Unsupported audio format"
                }), 400

            temp_file = tempfile.NamedTemporaryFile(
                delete=False,
                suffix=file_extension
            )

            temp_input = temp_file.name
            temp_file.close()

            audio_file.save(temp_input)

        # ======================================
        # JSON BASE64
        # ======================================
        elif "application/json" in content_type:

            data = request.get_json(silent=True) or {}

            audio_base64 = data.get("audio")
            source_language = data.get("source_language")
            target_language = data.get("target_language")
            original_text = data.get("text")
            audio_format = data.get("audio_format", ".wav")

            if not target_language:
                return jsonify({
                    "error": "Missing target_language"
                }), 400

            if original_text and not audio_base64:
                translated_text = translate_speech(
                    original_text,
                    target_language
                )

                return jsonify({
                    "original_text": original_text,
                    "translated_text": translated_text
                })

            if not audio_base64:
                return jsonify({
                    "error": "Missing audio or text"
                }), 400

            if not source_language:
                return jsonify({
                    "error": "Missing source_language"
                }), 400

            audio_data = base64.b64decode(audio_base64)

            suffix = (
                audio_format
                if audio_format.startswith(".")
                else f".{audio_format}"
            )

            temp_file = tempfile.NamedTemporaryFile(
                delete=False,
                suffix=suffix
            )

            temp_input = temp_file.name

            temp_file.write(audio_data)
            temp_file.close()

        else:
            return jsonify({
                "error": "Unsupported Content-Type"
            }), 415

        # ======================================
        # CONVERT TO WAV
        # ======================================
        wav_file = tempfile.NamedTemporaryFile(
            delete=False,
            suffix=".wav"
        )

        wav_path = wav_file.name
        wav_file.close()

        convert_to_wav(
            temp_input,
            wav_path
        )

        # ======================================
        # TRANSCRIBE AUDIO
        # ======================================
        recognizer = sr.Recognizer()

        with sr.AudioFile(wav_path) as source:

            recognizer.adjust_for_ambient_noise(
                source,
                duration=0.5
            )

            audio = recognizer.record(source)

        language_code = get_speech_language_code(source_language)

        print("Language Code:", language_code)

        raw_original_text = recognizer.recognize_google(
            audio,
            language=language_code
        )
        original_text = punctuate_transcript(
            raw_original_text,
            source_language
        )

        print("Recognized Text:", original_text)

        # ======================================
        # GEMINI TRANSLATION
        # ======================================
        translated_text = translate_speech(
            original_text,
            target_language
        )

        # ======================================
        # RESPONSE
        # ======================================
        return jsonify({
            "raw_original_text": raw_original_text,
            "original_text": original_text,
            "translated_text": translated_text
        })

    except sr.UnknownValueError:
        return jsonify({
            "error": "Could not understand audio"
        }), 400

    except sr.RequestError as e:
        return jsonify({
            "error": f"Speech recognition service error: {str(e)}"
        }), 500

    except Exception as e:
        print("ERROR:", str(e))

        return jsonify({
            "error": str(e)
        }), 500

    finally:

        for path in (temp_input, wav_path):

            if path and os.path.exists(path):

                try:
                    os.remove(path)

                except Exception:
                    pass
