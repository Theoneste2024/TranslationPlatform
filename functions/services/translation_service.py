"""
Translation service using Google Generative AI (Gemini API).
Provides text translation with batch processing and fallback mechanisms.
"""

from typing import List, Optional, Dict, Any
from google import genai
from config import GEMINI_API_KEY
from utils.logger import get_logger

logger = get_logger("translation_service")

# Gemini models available
GEMINI_MODELS = ["gemini-2.5-flash"]

# Language code to full name mapping
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
    "am": "Amharic",
    "ha": "Hausa",
    "ny": "Chichewa",
    "zu": "Zulu",
    "xh": "Xhosa",
    "sn": "Shona",
    "tl": "Tagalog",
    "vi": "Vietnamese",
    "th": "Thai",
    "ms": "Malay",
    "id": "Indonesian",
    "fil": "Filipino",
}


class TranslationError(Exception):
    """Raised when translation fails."""
    pass


class TranslationService:
    """Wrapper around Gemini API for text translation."""
    
    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize translation service.
        
        Args:
            api_key: Google Generative AI API key
        """
        self.api_key = api_key or GEMINI_API_KEY
        if not self.api_key:
            raise TranslationError("GEMINI_API_KEY not configured")
        
        self.client = genai.Client(api_key=self.api_key)
        logger.info("Translation service initialized")
    
    def translate(
        self,
        text: str,
        source_language: str,
        target_language: str,
        model: Optional[str] = None
    ) -> str:
        """
        Translate text from source to target language.
        
        Args:
            text: Text to translate
            source_language: Source language code or name
            target_language: Target language code or name
            model: Gemini model to use (default: gemini-2.5-flash)
            
        Returns:
            Translated text
            
        Raises:
            TranslationError: If translation fails
        """
        if not text or not text.strip():
            logger.debug("Empty text provided, returning empty string")
            return ""
        
        model = model or GEMINI_MODELS[0]
        source_lang_name = self._get_language_name(source_language)
        target_lang_name = self._get_language_name(target_language)
        
        logger.debug(
            f"Translating text: {source_lang_name} -> {target_lang_name} "
            f"(text_length={len(text)}, model={model})"
        )
        
        prompt = (
            f"Translate the following text from {source_lang_name} to {target_lang_name}. "
            f"Return only the translated text, nothing else.\n\n"
            f"Text: {text}"
        )
        
        try:
            response = self.client.models.generate_content(
                model=model,
                contents=prompt,
                generation_config={
                    "temperature": 0.3,
                    "top_p": 0.95,
                    "max_output_tokens": 2048,
                }
            )
            
            translated_text = response.text.strip()
            logger.debug(f"Translation successful (output_length={len(translated_text)})")
            return translated_text
            
        except Exception as e:
            logger.error(f"Translation failed: {str(e)}")
            raise TranslationError(f"Translation failed: {str(e)}") from e
    
    def translate_batch(
        self,
        texts: List[str],
        source_language: str,
        target_language: str,
        model: Optional[str] = None,
        separator: str = "|||"
    ) -> List[str]:
        """
        Translate multiple texts in a batch for efficiency.
        
        Sends all texts together separated by the separator to reduce API calls.
        Falls back to individual translation if batch fails.
        
        Args:
            texts: List of texts to translate
            source_language: Source language code or name
            target_language: Target language code or name
            model: Gemini model to use
            separator: Separator between texts in batch
            
        Returns:
            List of translated texts (same order as input)
            
        Raises:
            TranslationError: If all translation attempts fail
        """
        if not texts:
            return []
        
        if len(texts) == 1:
            return [self.translate(texts[0], source_language, target_language, model)]
        
        model = model or GEMINI_MODELS[0]
        source_lang_name = self._get_language_name(source_language)
        target_lang_name = self._get_language_name(target_language)
        
        logger.info(
            f"Batch translating {len(texts)} texts: "
            f"{source_lang_name} -> {target_lang_name}, model={model}"
        )
        
        # Try batch translation first
        try:
            batch_text = separator.join(texts)
            prompt = (
                f"Translate the following texts from {source_lang_name} to {target_lang_name}. "
                f"The texts are separated by '{separator}'. "
                f"Return the translations in the same format, separated by the same separator.\n\n"
                f"Texts: {batch_text}"
            )
            
            response = self.client.models.generate_content(
                model=model,
                contents=prompt,
                generation_config={
                    "temperature": 0.3,
                    "top_p": 0.95,
                    "max_output_tokens": 4096,
                }
            )
            
            result_text = response.text.strip()
            translations = result_text.split(separator)
            
            # Validate result count matches input count
            if len(translations) == len(texts):
                logger.info(f"Batch translation successful")
                return [t.strip() for t in translations]
            else:
                logger.warning(
                    f"Batch split count mismatch: "
                    f"expected {len(texts)}, got {len(translations)}. "
                    f"Falling back to individual translation."
                )
                
        except Exception as e:
            logger.warning(f"Batch translation failed: {str(e)}, falling back to individual")
        
        # Fallback: translate individually
        translations = []
        for i, text in enumerate(texts):
            try:
                translated = self.translate(text, source_language, target_language, model)
                translations.append(translated)
            except Exception as e:
                logger.error(f"Failed to translate text {i + 1}/{len(texts)}: {str(e)}")
                translations.append(text)  # Return original on error
        
        return translations
    
    def _get_language_name(self, language_code: str) -> str:
        """
        Convert language code to full name.
        
        Args:
            language_code: ISO 639-1 language code or language name
            
        Returns:
            Full language name
        """
        code_lower = language_code.lower().strip()
        
        # If it's already a language name, return it
        if code_lower in LANGUAGE_MAP.values():
            return code_lower.capitalize()
        
        # If it's a language code, return the name
        if code_lower in LANGUAGE_MAP:
            return LANGUAGE_MAP[code_lower]
        
        # Default: return the input with first letter capitalized
        logger.warning(f"Unknown language code: {language_code}")
        return code_lower.capitalize()


# Global service instance
_service_instance: Optional[TranslationService] = None


def get_translation_service(api_key: Optional[str] = None) -> TranslationService:
    """
    Get or create a global translation service instance.
    
    Args:
        api_key: API key (only used on first call)
        
    Returns:
        TranslationService instance
    """
    global _service_instance
    
    if _service_instance is None:
        _service_instance = TranslationService(api_key)
    
    return _service_instance


def translate_text(
    text: str,
    source_language: str,
    target_language: str,
    model: Optional[str] = None
) -> str:
    """
    Convenience function to translate text using default service.
    
    Args:
        text: Text to translate
        source_language: Source language code
        target_language: Target language code
        model: Gemini model to use
        
    Returns:
        Translated text
    """
    service = get_translation_service()
    return service.translate(text, source_language, target_language, model)


def translate_texts_batch(
    texts: List[str],
    source_language: str,
    target_language: str,
    model: Optional[str] = None
) -> List[str]:
    """
    Convenience function to translate multiple texts using default service.
    
    Args:
        texts: Texts to translate
        source_language: Source language code
        target_language: Target language code
        model: Gemini model to use
        
    Returns:
        List of translated texts
    """
    service = get_translation_service()
    return service.translate_batch(texts, source_language, target_language, model)
