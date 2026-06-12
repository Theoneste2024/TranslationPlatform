from google import genai
from config import GEMINI_API_KEY
from pydub import AudioSegment
import speech_recognition as sr
import tempfile
import os

client = genai.Client(api_key=GEMINI_API_KEY)

GEMINI_MODELS = [
    # "gemini-2.5-flash",
    "gemini-2.5-flash-lite"
]

LANGUAGE_MAP = {
    "en": "English",
    "fr": "French",
    "rw": "Kinyarwanda",
    "sw": "Swahili",
    "ar": "Arabic",
    "es": "Spanish",
    "de": "German",
    "pt": "Portuguese",
    "it": "Italian",
    "zh": "Chinese",
    "ja": "Japanese",
    "ko": "Korean",
    "hi": "Hindi",
    "yo": "Yoruba",
    "ig": "Igbo",
    "ha": "Hausa",
    "am": "Amharic"
}

LANGUAGE_CODES = {
    "en": "en-US",
    "fr": "fr-FR",
    "rw": "rw-RW",
    "sw": "sw-KE",
    "ar": "ar-SA",
    "es": "es-ES",
    "de": "de-DE",
    "pt": "pt-PT",
    "it": "it-IT",
    "zh": "zh-CN",
    "ja": "ja-JP",
    "ko": "ko-KR",
    "hi": "hi-IN",
    "yo": "yo-NG",
    "ig": "ig-NG",
    "ha": "ha-NG",
    "am": "am-ET"
}

LANGUAGE_ALIASES = {
    "english": "en",
    "french": "fr",
    "francais": "fr",
    "kinyarwanda": "rw",
    "rwanda": "rw",
    "swahili": "sw",
    "kiswahili": "sw",
    "arabic": "ar",
    "spanish": "es",
    "german": "de",
    "portuguese": "pt",
    "italian": "it",
    "chinese": "zh",
    "japanese": "ja",
    "korean": "ko",
    "hindi": "hi",
    "yoruba": "yo",
    "igbo": "ig",
    "hausa": "ha",
    "amharic": "am"
}


def normalize_language(language, default="en"):
    if not language:
        return default

    language = language.strip()
    language_key = language.lower().replace("_", "-")

    if language_key == "auto":
        return default

    if language_key in LANGUAGE_CODES:
        return language_key

    short_code = language_key.split("-")[0]
    if short_code in LANGUAGE_CODES:
        return short_code

    return LANGUAGE_ALIASES.get(language_key, language)


def get_language_name(language):
    normalized_language = normalize_language(language, default=language)

    return LANGUAGE_MAP.get(
        normalized_language,
        str(language).strip()
    )


def get_speech_language_code(language):
    normalized_language = normalize_language(language)

    if "-" in normalized_language:
        return normalized_language

    return LANGUAGE_CODES.get(normalized_language, "en-US")

def translate_text(text, target_lang):

    language_name = get_language_name(target_lang)

    prompt = f"""
You are a professional translator.

Translate the following text into {language_name}.

Rules:
- Use authentic and standard {language_name}
- Do not mix languages
- Preserve names exactly
- Return ONLY the translated text

Text:
{text}
"""

    response = client.models.generate_content(
        model="gemini-2.5-flash-lite",
        contents=prompt
    )

    return response.text.strip()


def translate_video(video_path, source_lang, target_lang, model=None):
    source_lang = normalize_language(source_lang)
    target_lang = normalize_language(target_lang, default=target_lang)

    wav_file = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    wav_file.close()

    try:
        _convert_to_wav(video_path, wav_file.name)

        recognizer = sr.Recognizer()
        with sr.AudioFile(wav_file.name) as source:
            recognizer.adjust_for_ambient_noise(source, duration=0.5)
            audio = recognizer.record(source)

        language_code = get_speech_language_code(source_lang)
        raw_transcript = recognizer.recognize_google(audio, language=language_code)
        transcript, punctuation_model_used = punctuate_transcript_with_model(
            raw_transcript,
            source_lang,
            model
        )

        translated_text, model_used = translate_speech_with_model(
            transcript,
            target_lang,
            model
        )

        return {
            "original_text": transcript,
            "translated_text": translated_text
        }

    except sr.UnknownValueError:
        raise Exception("Could not understand audio from video")

    except sr.RequestError as e:
        raise Exception(f"Speech recognition service error: {str(e)}")

    finally:
        try:
            if os.path.exists(wav_file.name):
                os.remove(wav_file.name)
        except Exception:
            pass

def _convert_to_wav(input_path, output_path):
    audio = AudioSegment.from_file(input_path)
    audio = audio.set_channels(1)
    audio = audio.set_frame_rate(16000)
    audio.export(output_path, format="wav")


def _get_model_order(preferred_model=None):
    if preferred_model and preferred_model in GEMINI_MODELS:
        return [preferred_model] + [
            model for model in GEMINI_MODELS
            if model != preferred_model
        ]

    return GEMINI_MODELS


def _generate_content_with_fallback(prompt, preferred_model=None):
    last_error = None

    for model in _get_model_order(preferred_model):
        try:
            response = client.models.generate_content(
                model=model,
                contents=prompt
            )
            return response, model

        except Exception as e:
            last_error = e
            error_text = str(e).lower()
            if "503" not in error_text and "unavailable" not in error_text:
                raise

    raise last_error


def punctuate_transcript_with_model(transcript, source_lang, model=None):
    language_name = get_language_name(source_lang)

    prompt = f"""
You restore punctuation and capitalization for speech transcripts.

Language: {language_name}

Rules:
- Add punctuation marks where they naturally belong.
- Add capitalization where appropriate.
- Do not translate.
- Do not add new facts or extra words.
- Keep the original wording as much as possible.
- Return ONLY the punctuated transcript.

Transcript:
{transcript}
"""

    response, model_used = _generate_content_with_fallback(prompt, model)

    return response.text.strip(), model_used


def punctuate_transcript(transcript, source_lang):
    punctuated_text, _ = punctuate_transcript_with_model(
        transcript,
        source_lang
    )

    return punctuated_text


def translate_speech_with_model(transcript, target_lang, model=None):

    target_lang = normalize_language(target_lang, default=target_lang)
    language_name = get_language_name(target_lang)

    prompt = f"""
You are a professional translator.

Translate the following spoken sentence into {language_name}.

Rules:
- Preserve meaning
- Use natural and fluent {language_name}
- Preserve names exactly
- Use proper fluent {language_name}
- Return ONLY the translation

Sentence:
{transcript}
"""

    response, model_used = _generate_content_with_fallback(prompt, model)

    return response.text.strip(), model_used


def translate_speech(transcript, target_lang):
    translated_text, _ = translate_speech_with_model(transcript, target_lang)

    return translated_text
