"""
Text-to-Speech service for generating audio from translated text.
Supports multiple TTS engines and voice options.
"""

from typing import Optional, Tuple
import os
import tempfile
from utils.logger import get_logger

logger = get_logger("tts_service")

try:
    import edge_tts
except ImportError:
    edge_tts = None


class TTSError(Exception):
    """Raised when TTS generation fails."""
    pass


class TTSService:
    """Text-to-Speech service using Edge TTS or other providers."""
    
    def __init__(self, engine: str = "edge"):
        """
        Initialize TTS service.
        
        Args:
            engine: TTS engine to use ('edge', 'gtts', 'pyttsx3')
        """
        self.engine = engine
        logger.info(f"TTS service initialized with engine: {engine}")
    
    def synthesize(
        self,
        text: str,
        language: str,
        voice: Optional[str] = None,
        rate: float = 1.0
    ) -> Tuple[str, bytes]:
        """
        Synthesize text to audio.
        
        Args:
            text: Text to synthesize
            language: Language code (e.g., 'fr', 'rw')
            voice: Voice ID (optional, uses default if not specified)
            rate: Speech rate (0.5-2.0, where 1.0 is normal)
            
        Returns:
            Tuple of (audio_format, audio_bytes)
            
        Raises:
            TTSError: If synthesis fails
        """
        if not text or not text.strip():
            raise TTSError("Cannot synthesize empty text")
        
        logger.info(f"Synthesizing text to speech: language={language}, engine={self.engine}")
        
        if self.engine == "edge":
            return self._synthesize_edge_tts(text, language, voice, rate)
        else:
            raise TTSError(f"Unsupported TTS engine: {self.engine}")
    
    def _synthesize_edge_tts(
        self,
        text: str,
        language: str,
        voice: Optional[str] = None,
        rate: float = 1.0
    ) -> Tuple[str, bytes]:
        """Synthesize using Edge TTS (Bing TTS)."""
        if edge_tts is None:
            raise TTSError(
                "edge-tts is not installed. "
                "Install it with: pip install edge-tts"
            )
        
        try:
            import asyncio
            
            # Map language codes to Edge TTS voices
            voice = voice or self._get_default_voice(language)
            
            # Convert rate to Edge TTS format (-50 to +50)
            rate_value = int((rate - 1.0) * 50)
            rate_value = max(-50, min(50, rate_value))  # Clamp
            rate_str = f"+{rate_value}%" if rate_value >= 0 else f"{rate_value}%"
            
            logger.debug(f"Edge TTS: voice={voice}, rate={rate_str}")
            
            # Run async synthesis
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            try:
                audio_data = loop.run_until_complete(
                    self._edge_tts_async(text, voice, rate_str)
                )
                logger.info(f"Edge TTS synthesis successful: {len(audio_data)} bytes")
                return "audio/mp3", audio_data
            finally:
                loop.close()
                
        except Exception as e:
            logger.error(f"Edge TTS synthesis failed: {str(e)}")
            raise TTSError(f"TTS synthesis failed: {str(e)}") from e
    
    async def _edge_tts_async(self, text: str, voice: str, rate: str) -> bytes:
        """Async wrapper for Edge TTS synthesis."""
        import edge_tts
        
        communicate = edge_tts.Communicate(
            text=text,
            voice=voice,
            rate=rate
        )
        
        audio_data = b""
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_data += chunk["data"]
        
        return audio_data
    
    def _get_default_voice(self, language: str) -> str:
        """
        Get default voice for a language.
        
        Mapping of language codes to Edge TTS voice IDs.
        
        Args:
            language: Language code
            
        Returns:
            Voice ID
        """
        voice_map = {
            "en": "en-US-AriaNeural",
            "fr": "fr-FR-DeniseNeural",
            "rw": "en-RW-default",  # Fallback to English for Kinyarwanda
            "sw": "sw-KE-default",
            "ar": "ar-SA-ZariyahNeural",
            "es": "es-ES-AlvaroNeural",
            "de": "de-DE-ConradNeural",
            "pt": "pt-BR-BrendaNeural",
            "it": "it-IT-DiegoNeural",
            "zh": "zh-CN-XiaoxiaoNeural",
            "ja": "ja-JP-NanamiNeural",
            "ko": "ko-KR-SunHiNeural",
            "hi": "hi-IN-MadhurNeural",
        }
        
        return voice_map.get(language.lower(), "en-US-AriaNeural")
    
    def save_to_file(
        self,
        text: str,
        language: str,
        output_path: str,
        voice: Optional[str] = None,
        rate: float = 1.0
    ) -> str:
        """
        Synthesize text and save to file.
        
        Args:
            text: Text to synthesize
            language: Language code
            output_path: Path to save audio file
            voice: Voice ID
            rate: Speech rate
            
        Returns:
            Path to saved audio file
        """
        audio_format, audio_data = self.synthesize(text, language, voice, rate)
        
        with open(output_path, 'wb') as f:
            f.write(audio_data)
        
        logger.info(f"Audio saved to: {output_path}")
        return output_path


# Global service instance
_service_instance: Optional[TTSService] = None


def get_tts_service(engine: str = "edge") -> TTSService:
    """
    Get or create a global TTS service instance.
    
    Args:
        engine: TTS engine (only used on first call)
        
    Returns:
        TTSService instance
    """
    global _service_instance
    
    if _service_instance is None:
        _service_instance = TTSService(engine)
    
    return _service_instance


def synthesize_text(
    text: str,
    language: str,
    voice: Optional[str] = None,
    rate: float = 1.0
) -> Tuple[str, bytes]:
    """
    Convenience function to synthesize text using default service.
    
    Args:
        text: Text to synthesize
        language: Language code
        voice: Voice ID
        rate: Speech rate
        
    Returns:
        Tuple of (format, audio_bytes)
    """
    service = get_tts_service()
    return service.synthesize(text, language, voice, rate)
