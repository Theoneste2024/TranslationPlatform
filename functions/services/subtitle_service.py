"""
Subtitle service for formatting and managing subtitle timing and delivery.
Handles subtitle formatting, timing synchronization, and event generation.
"""

from typing import Dict, Any, List, Optional
from dataclasses import dataclass, asdict
from utils.logger import get_logger

logger = get_logger("subtitle_service")


@dataclass
class SubtitleEvent:
    """Represents a single subtitle event with timing information."""
    type: str  # "subtitle", "complete", "error"
    timestamp: float  # Seconds since start
    original_text: Optional[str] = None  # Original language text
    translated_text: Optional[str] = None  # Translated text
    language: Optional[str] = None  # Language code
    duration: Optional[float] = None  # Duration in seconds
    segment_index: Optional[int] = None  # Index of the segment
    model_used: Optional[str] = None  # Model used for translation
    error: Optional[str] = None  # Error message if type is "error"
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary, excluding None values."""
        result = {}
        for key, value in asdict(self).items():
            if value is not None:
                result[key] = value
        return result


class SubtitleService:
    """Service for managing subtitle formatting and delivery."""
    
    def __init__(self):
        """Initialize subtitle service."""
        logger.info("Subtitle service initialized")
    
    def create_subtitle_event(
        self,
        original_text: str,
        translated_text: str,
        timestamp: float,
        duration: Optional[float] = None,
        language: Optional[str] = None,
        segment_index: Optional[int] = None,
        model_used: Optional[str] = None
    ) -> SubtitleEvent:
        """
        Create a subtitle event for a translated segment.
        
        Args:
            original_text: Original language text
            translated_text: Translated text
            timestamp: Timestamp in seconds
            duration: Duration in seconds
            language: Target language code
            segment_index: Index of the segment
            model_used: Name of model used
            
        Returns:
            SubtitleEvent object
        """
        return SubtitleEvent(
            type="subtitle",
            timestamp=timestamp,
            original_text=original_text,
            translated_text=translated_text,
            language=language,
            duration=duration,
            segment_index=segment_index,
            model_used=model_used
        )
    
    def create_error_event(
        self,
        error_message: str,
        timestamp: Optional[float] = None
    ) -> SubtitleEvent:
        """
        Create an error event.
        
        Args:
            error_message: Error description
            timestamp: Optional timestamp
            
        Returns:
            SubtitleEvent with type "error"
        """
        return SubtitleEvent(
            type="error",
            timestamp=timestamp or 0.0,
            error=error_message
        )
    
    def create_complete_event(self, timestamp: Optional[float] = None) -> SubtitleEvent:
        """
        Create a completion event.
        
        Args:
            timestamp: Optional final timestamp
            
        Returns:
            SubtitleEvent with type "complete"
        """
        return SubtitleEvent(
            type="complete",
            timestamp=timestamp or 0.0
        )
    
    def format_subtitle_for_display(
        self,
        translated_text: str,
        original_text: Optional[str] = None,
        max_chars_per_line: int = 42
    ) -> str:
        """
        Format subtitle text for display on screen.
        
        Breaks long text into multiple lines for better readability.
        
        Args:
            translated_text: Text to format
            original_text: Original text (for reference)
            max_chars_per_line: Maximum characters per line
            
        Returns:
            Formatted subtitle text
        """
        lines = []
        words = translated_text.split()
        current_line = []
        current_length = 0
        
        for word in words:
            word_length = len(word) + 1  # +1 for space
            
            if current_length + word_length > max_chars_per_line and current_line:
                lines.append(" ".join(current_line))
                current_line = [word]
                current_length = word_length
            else:
                current_line.append(word)
                current_length += word_length
        
        if current_line:
            lines.append(" ".join(current_line))
        
        formatted = "\n".join(lines)
        logger.debug(f"Formatted subtitle into {len(lines)} lines")
        return formatted
    
    def create_srt_entry(
        self,
        index: int,
        start_time: float,
        end_time: float,
        text: str
    ) -> str:
        """
        Create a SubRip (SRT) subtitle entry.
        
        Args:
            index: Subtitle index
            start_time: Start time in seconds
            end_time: End time in seconds
            text: Subtitle text
            
        Returns:
            Formatted SRT entry
        """
        def seconds_to_srt_time(seconds: float) -> str:
            """Convert seconds to SRT time format (HH:MM:SS,mmm)."""
            hours = int(seconds // 3600)
            minutes = int((seconds % 3600) // 60)
            secs = int(seconds % 60)
            millis = int((seconds % 1) * 1000)
            return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"
        
        start = seconds_to_srt_time(start_time)
        end = seconds_to_srt_time(end_time)
        
        return f"{index}\n{start} --> {end}\n{text}\n"
    
    def merge_consecutive_subtitles(
        self,
        subtitles: List[Dict[str, Any]],
        time_threshold: float = 0.5
    ) -> List[Dict[str, Any]]:
        """
        Merge consecutive subtitles that are close together in time.
        
        This reduces screen flicker by combining closely-timed subtitles.
        
        Args:
            subtitles: List of subtitle dictionaries
            time_threshold: Maximum gap between subtitles to merge (seconds)
            
        Returns:
            Merged subtitle list
        """
        if not subtitles:
            return []
        
        merged = [subtitles[0].copy()]
        
        for subtitle in subtitles[1:]:
            last = merged[-1]
            
            # Check if we should merge
            if (subtitle.get("timestamp", 0) - last.get("end_time", 0) <= time_threshold):
                # Merge by appending text
                if "translated_text" in last and "translated_text" in subtitle:
                    last["translated_text"] += " " + subtitle["translated_text"]
                
                # Update end time
                last["end_time"] = subtitle.get("end_time", last.get("end_time"))
            else:
                # Don't merge, add as new entry
                merged.append(subtitle.copy())
        
        logger.debug(f"Merged {len(subtitles)} subtitles to {len(merged)}")
        return merged
    
    def estimate_display_time(self, text: str, wpm: int = 150) -> float:
        """
        Estimate how long a subtitle should be displayed.
        
        Uses reading speed in words per minute to estimate duration.
        
        Args:
            text: Subtitle text
            wpm: Words per minute (typical reading speed)
            
        Returns:
            Estimated display time in seconds
        """
        word_count = len(text.split())
        seconds = max(1.0, (word_count / wpm) * 60)  # At least 1 second
        return seconds


# Global service instance
_service_instance: Optional[SubtitleService] = None


def get_subtitle_service() -> SubtitleService:
    """Get or create a global subtitle service instance."""
    global _service_instance
    
    if _service_instance is None:
        _service_instance = SubtitleService()
    
    return _service_instance


def create_subtitle_event(
    original_text: str,
    translated_text: str,
    timestamp: float,
    **kwargs
) -> Dict[str, Any]:
    """
    Convenience function to create a subtitle event.
    
    Returns:
        Dictionary representation of subtitle event
    """
    service = get_subtitle_service()
    event = service.create_subtitle_event(original_text, translated_text, timestamp, **kwargs)
    return event.to_dict()
