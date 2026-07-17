"""
Speech recognition service using Faster Whisper with memory management.
Provides transcription with automatic fallback to smaller models under memory pressure.
"""

import os
import gc
import sys
from typing import Optional, Dict, Any
from utils.logger import get_logger

# Reduce BLAS/MKL threads to minimize memory usage
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("KMP_INIT_AT_FORK", "FALSE")

try:
    from faster_whisper import WhisperModel
except ImportError:
    WhisperModel = None

logger = get_logger("speech_service")

# Available Whisper models (ordered by size and memory usage)
WHISPER_MODELS = ["tiny", "base", "small", "medium", "large"]
DEFAULT_MODEL_SIZE = "small"
DEFAULT_DEVICE = "cpu"
DEFAULT_COMPUTE_TYPE = "int8"  # Quantized for memory efficiency


class SpeechRecognitionError(Exception):
    """Raised when speech recognition fails."""
    pass


class WhisperService:
    """Wrapper around Faster Whisper with memory management and retries."""
    
    def __init__(
        self,
        model_size: Optional[str] = None,
        device: Optional[str] = None,
        compute_type: Optional[str] = None
    ):
        """
        Initialize Whisper service.
        
        Args:
            model_size: Model size (tiny, base, small, medium, large)
            device: Device to use (cpu, cuda)
            compute_type: Compute type (float32, float16, int8, int8_float16)
        """
        self.model_size = model_size or os.environ.get("WHISPER_MODEL_SIZE", DEFAULT_MODEL_SIZE)
        self.device = device or os.environ.get("WHISPER_DEVICE", DEFAULT_DEVICE)
        self.compute_type = compute_type or os.environ.get("WHISPER_COMPUTE_TYPE", DEFAULT_COMPUTE_TYPE)
        self.model = None
        
        logger.info(
            f"Initializing Whisper service: "
            f"model={self.model_size}, device={self.device}, compute={self.compute_type}"
        )
        
        self._load_model(self.model_size)
    
    def _load_model(self, model_size: str) -> None:
        """
        Load Whisper model of specified size.
        
        Args:
            model_size: Model size to load
            
        Raises:
            SpeechRecognitionError: If model loading fails
        """
        if WhisperModel is None:
            raise SpeechRecognitionError(
                "faster_whisper is not installed. "
                "Install it with: pip install faster-whisper"
            )
        
        try:
            logger.debug(f"Loading Whisper model: {model_size}")
            self.model = WhisperModel(
                model_size,
                device=self.device,
                compute_type=self.compute_type,
                cpu_threads=1
            )
            self.model_size = model_size
            logger.info(f"Whisper model loaded successfully: {model_size}")
        except Exception as e:
            logger.error(f"Failed to load Whisper model {model_size}: {str(e)}")
            raise SpeechRecognitionError(f"Failed to load model: {str(e)}") from e
    
    def transcribe(
        self,
        audio_path: str,
        language: Optional[str] = None,
        task: str = "transcribe"
    ) -> Dict[str, Any]:
        """
        Transcribe audio file to text with automatic retry on memory errors.
        
        On MemoryError, automatically falls back to smaller models.
        
        Args:
            audio_path: Path to audio file
            language: ISO-639-1 language code (auto-detect if None)
            task: Task type ('transcribe' or 'translate')
            
        Returns:
            Dictionary with transcription results:
            {
                "text": "Full transcribed text",
                "language": "Detected language code",
                "segments": [
                    {"id": 0, "start": 0.0, "end": 2.5, "text": "..."},
                    ...
                ]
            }
            
        Raises:
            SpeechRecognitionError: If transcription fails after all retries
        """
        if not os.path.exists(audio_path):
            raise SpeechRecognitionError(f"Audio file not found: {audio_path}")
        
        logger.info(f"Transcribing audio: {audio_path} (language={language}, task={task})")
        
        # List of model sizes to try, starting with current and progressively smaller
        fallback_models = self._get_fallback_models()
        
        last_error = None
        
        for attempt, model_size in enumerate(fallback_models):
            try:
                logger.debug(f"Transcription attempt {attempt + 1} with model: {model_size}")
                
                # Reload model if different from current
                if model_size != self.model_size:
                    gc.collect()  # Clean up memory before loading new model
                    self._load_model(model_size)
                
                # Perform transcription
                segments, info = self.model.transcribe(
                    audio_path,
                    language=language,
                    task=task,
                    beam_size=5,
                    best_of=5,
                    temperature=0.0,
                    patience=1.0
                )
                
                # Convert generator to list and build result
                segments_list = []
                for segment in segments:
                    segments_list.append({
                        "id": segment.id,
                        "start": segment.start,
                        "end": segment.end,
                        "text": segment.text.strip()
                    })
                
                full_text = " ".join([seg["text"] for seg in segments_list])
                
                logger.info(
                    f"Transcription successful with {model_size}: "
                    f"language={info.language}, text_length={len(full_text)}"
                )
                
                return {
                    "text": full_text,
                    "language": info.language,
                    "segments": segments_list,
                    "model_used": model_size
                }
                
            except MemoryError as e:
                logger.warning(f"Memory error with model {model_size}, trying smaller model")
                last_error = e
                gc.collect()  # Clean up memory
                
                # Continue to next (smaller) model
                continue
                
            except Exception as e:
                logger.error(f"Transcription failed with model {model_size}: {str(e)}")
                last_error = e
                
                # Some errors might not be retryable
                if "out of memory" not in str(e).lower() and "memory" not in str(e).lower():
                    raise SpeechRecognitionError(f"Transcription failed: {str(e)}") from e
                
                continue
        
        # All models failed
        raise SpeechRecognitionError(
            f"Transcription failed with all model sizes. Last error: {str(last_error)}"
        ) from last_error
    
    def _get_fallback_models(self) -> list:
        """
        Get list of model sizes to try, ordered by preference.
        
        Starts with current model, then falls back to smaller sizes.
        
        Returns:
            List of model sizes ordered by priority
        """
        if self.model_size not in WHISPER_MODELS:
            logger.warning(f"Unknown model size {self.model_size}, using default")
            return WHISPER_MODELS[WHISPER_MODELS.index(DEFAULT_MODEL_SIZE):]
        
        current_index = WHISPER_MODELS.index(self.model_size)
        # Start with current model, then use progressively smaller models
        return WHISPER_MODELS[:current_index + 1]
    
    def get_model_size(self) -> str:
        """Get current model size."""
        return self.model_size
    
    def get_device(self) -> str:
        """Get device being used."""
        return self.device


# Global service instance
_service_instance: Optional[WhisperService] = None


def get_speech_service(
    model_size: Optional[str] = None,
    device: Optional[str] = None,
    compute_type: Optional[str] = None
) -> WhisperService:
    """
    Get or create a global Whisper service instance.
    
    Args:
        model_size: Model size (only used on first call)
        device: Device (only used on first call)
        compute_type: Compute type (only used on first call)
        
    Returns:
        WhisperService instance
    """
    global _service_instance
    
    if _service_instance is None:
        _service_instance = WhisperService(model_size, device, compute_type)
    
    return _service_instance


def transcribe_audio(
    audio_path: str,
    language: Optional[str] = None,
    task: str = "transcribe",
    model_size: Optional[str] = None
) -> Dict[str, Any]:
    """
    Convenience function to transcribe audio using default service.
    
    Args:
        audio_path: Path to audio file
        language: ISO-639-1 language code
        task: Task type ('transcribe' or 'translate')
        model_size: Model size (only used on first call to service)
        
    Returns:
        Transcription result dictionary
    """
    service = get_speech_service(model_size=model_size)
    return service.transcribe(audio_path, language=language, task=task)
