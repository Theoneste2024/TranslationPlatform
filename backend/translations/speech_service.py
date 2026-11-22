import os

from openai import OpenAI, OpenAIError


TTS_MODEL = "gpt-4o-mini-tts"
TTS_VOICE = "marin"
TTS_TIMEOUT_SECONDS = 45


class SpeechGenerationError(Exception):
    pass


def _speech_instructions(target_language, kinyarwanda_guidance):
    instructions = (
        f"Read the input text exactly as written in {target_language}. Do not "
        "translate, rewrite, paraphrase, add, or omit any words. Speak clearly "
        "and naturally."
    )
    if kinyarwanda_guidance:
        instructions += (
            "\n\n"
            + kinyarwanda_guidance
            + "\n\nThe input is already translated. Use this guidance only for "
            "pronunciation and natural spoken delivery; do not change its wording."
        )
    return instructions


def generate_translation_audio(text, target_language, kinyarwanda_guidance=""):
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise SpeechGenerationError(
            "OPENAI_API_KEY environment variable is not set."
        )

    try:
        response = OpenAI(
            api_key=api_key,
            timeout=TTS_TIMEOUT_SECONDS,
        ).audio.speech.create(
            model=TTS_MODEL,
            voice=TTS_VOICE,
            input=text,
            instructions=_speech_instructions(
                target_language,
                kinyarwanda_guidance,
            ),
            response_format="mp3",
        )
    except OpenAIError as exc:
        raise SpeechGenerationError(
            "OpenAI text-to-speech generation failed."
        ) from exc

    if not response.content:
        raise SpeechGenerationError("OpenAI returned empty speech audio.")
    return response.content
