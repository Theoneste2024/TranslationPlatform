"""
Audio streaming service for handling FFmpeg-based audio extraction and chunking.
Supports both file-based and URL-based (live) audio streaming with memory efficiency.
"""

import subprocess
import glob
import time
import os
import shutil
from pathlib import Path
from typing import Generator, Optional, Tuple
from utils.logger import get_logger

logger = get_logger("audio_stream_service")


class AudioStreamError(Exception):
    """Raised when audio streaming operations fail."""
    pass


def remove_temp_dir(temp_dir: str) -> None:
    """
    Safely remove a temporary directory and all its contents.
    
    Args:
        temp_dir: Path to directory to remove
    """
    if not temp_dir or not os.path.exists(temp_dir):
        return

    try:
        for root, _, files in os.walk(temp_dir):
            for file_name in files:
                try:
                    os.remove(os.path.join(root, file_name))
                except Exception as e:
                    logger.warning(f"Failed to remove file: {e}")

        os.rmdir(temp_dir)
        logger.debug(f"Removed temporary directory: {temp_dir}")
    except Exception as e:
        logger.warning(f"Failed to fully clean temp directory {temp_dir}: {e}")


def stream_audio_in_chunks(
    source: str,
    output_dir: str,
    chunk_seconds: int = 12,
    timeout: int = 300
) -> Generator[str, None, None]:
    """
    Stream audio from a source (file or URL) and split into chunks using FFmpeg.
    
    This function spawns an FFmpeg subprocess to continuously segment audio into
    small chunks. This is memory-efficient for long videos/streams.
    
    Args:
        source: Path to audio file or direct URL (http/https)
        output_dir: Directory where chunk files will be written
        chunk_seconds: Duration of each chunk in seconds (default: 12)
        timeout: Maximum time to wait for ffmpeg setup (seconds)
        
    Yields:
        Path to each newly created audio chunk file
        
    Raises:
        AudioStreamError: If FFmpeg fails to start or produces no chunks
    """
    logger.info(f"Starting audio stream chunking: source={source}, chunk_size={chunk_seconds}s")
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # FFmpeg command to split audio into chunks
    # -f segment: Use the segment demuxer to split output into multiple files
    # -segment_time: Duration of each segment
    # -reset_timestamps: Reset timestamps for each segment (important for processing)
    cmd = [
        'ffmpeg',
        '-i', source,
        '-q:a', '5',  # Quality (lower is better, -5 to 9)
        '-acodec', 'libmp3lame',  # Use MP3 codec
        '-ar', '16000',  # Resample to 16kHz (standard for Whisper)
        '-ac', '1',  # Convert to mono
        '-f', 'segment',
        '-segment_time', str(chunk_seconds),
        '-reset_timestamps', '1',
        os.path.join(output_dir, 'chunk_%05d.mp3')
    ]
    
    try:
        logger.debug(f"Starting FFmpeg process: {' '.join(cmd)}")
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
    except FileNotFoundError:
        raise AudioStreamError("FFmpeg not found. Please install FFmpeg and ensure it's on PATH")
    except Exception as e:
        raise AudioStreamError(f"Failed to start FFmpeg: {str(e)}") from e
    
    seen_files = set()
    chunk_wait_timeout = timeout
    start_time = time.time()
    stable_wait_time = 2  # Wait 2 seconds to ensure file is stable
    
    try:
        while True:
            # Check if process has died
            poll_result = process.poll()
            if poll_result is not None and poll_result != 0:
                stderr = process.stderr.read() if process.stderr else ""
                logger.error(f"FFmpeg process died with code {poll_result}: {stderr}")
                raise AudioStreamError(f"FFmpeg process failed with code {poll_result}")
            
            # Look for new chunk files
            chunk_files = sorted(glob.glob(os.path.join(output_dir, 'chunk_*.mp3')))
            
            for chunk_file in chunk_files:
                if chunk_file not in seen_files:
                    # Wait for file to stabilize (file not being written to)
                    last_mtime = os.path.getmtime(chunk_file)
                    time.sleep(stable_wait_time)
                    
                    current_mtime = os.path.getmtime(chunk_file)
                    if current_mtime == last_mtime:  # File hasn't changed, it's stable
                        seen_files.add(chunk_file)
                        logger.debug(f"Yielding chunk: {chunk_file}")
                        yield chunk_file
            
            # Check for timeout
            if time.time() - start_time > chunk_wait_timeout:
                if not seen_files:
                    raise AudioStreamError(f"No chunks produced within {chunk_wait_timeout} seconds")
                logger.info("Audio streaming timeout reached")
                break
            
            # Sleep before checking again
            time.sleep(1)
            
    finally:
        # Terminate FFmpeg process
        logger.debug("Terminating FFmpeg process")
        try:
            process.terminate()
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            logger.warning("FFmpeg did not terminate gracefully, killing it")
            process.kill()
            process.wait()
        except Exception as e:
            logger.warning(f"Error terminating FFmpeg: {e}")


def extract_audio_from_file(
    video_file_path: str,
    output_dir: str
) -> str:
    """
    Extract audio from a video file using FFmpeg.
    
    Args:
        video_file_path: Path to video file
        output_dir: Directory to save extracted audio
        
    Returns:
        Path to the extracted audio file
        
    Raises:
        AudioStreamError: If extraction fails
    """
    logger.info(f"Extracting audio from video: {video_file_path}")
    
    output_audio = os.path.join(output_dir, 'audio.wav')
    
    cmd = [
        'ffmpeg',
        '-i', video_file_path,
        '-q:a', '0',
        '-acodec', 'pcm_s16le',
        '-ar', '16000',
        '-ac', '1',
        '-y',  # Overwrite output file
        output_audio
    ]
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600  # 10 minute timeout
        )
        
        if result.returncode != 0:
            logger.error(f"Audio extraction failed: {result.stderr}")
            raise AudioStreamError(f"FFmpeg extraction failed: {result.stderr}")
        
        logger.info(f"Audio extraction successful: {output_audio}")
        return output_audio
        
    except subprocess.TimeoutExpired:
        raise AudioStreamError("Audio extraction timed out")
    except Exception as e:
        raise AudioStreamError(f"Failed to extract audio: {str(e)}") from e


def get_audio_duration(audio_file_path: str) -> Optional[float]:
    """
    Get the duration of an audio file in seconds.
    
    Args:
        audio_file_path: Path to audio file
        
    Returns:
        Duration in seconds, or None if unable to determine
    """
    cmd = [
        'ffprobe',
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1:nokey=1',
        audio_file_path
    ]
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            duration = float(result.stdout.strip())
            logger.debug(f"Audio duration: {duration}s")
            return duration
    except Exception as e:
        logger.warning(f"Failed to get audio duration: {e}")
    
    return None


def validate_audio_file(audio_file_path: str) -> bool:
    """
    Validate that a file is a valid audio file.
    
    Args:
        audio_file_path: Path to audio file
        
    Returns:
        True if file is valid, False otherwise
    """
    if not os.path.exists(audio_file_path):
        logger.warning(f"Audio file not found: {audio_file_path}")
        return False
    
    if os.path.getsize(audio_file_path) == 0:
        logger.warning(f"Audio file is empty: {audio_file_path}")
        return False
    
    # Try to get duration as a validation
    duration = get_audio_duration(audio_file_path)
    if duration is None or duration <= 0:
        logger.warning(f"Invalid audio duration: {duration}")
        return False
    
    logger.debug(f"Audio file validated: {audio_file_path}")
    return True
