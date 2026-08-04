"""
YouTube service for handling video downloads and stream extraction.
Provides centralized YouTube operations with proper error handling and logging.
"""

import os
import re
from urllib.parse import parse_qs, urlparse
from utils.logger import get_logger

try:
    from yt_dlp import YoutubeDL
except ImportError:
    YoutubeDL = None

logger = get_logger("youtube_service")

YOUTUBE_ID_PATTERN = re.compile(r'^[A-Za-z0-9_-]{11}$')


def normalize_youtube_url(raw_url: str) -> str:
    """
    Normalize various YouTube URL formats into a standard URL.
    
    Accepts:
    - Full URLs: https://www.youtube.com/watch?v=dQw4w9WgXcQ
    - Shortened: https://youtu.be/dQw4w9WgXcQ
    - Video ID only: dQw4w9WgXcQ
    
    Args:
        raw_url: YouTube URL or video ID
        
    Returns:
        Normalized YouTube URL
        
    Raises:
        ValueError: If URL format is invalid
    """
    youtube_url = raw_url.strip()

    if YOUTUBE_ID_PATTERN.match(youtube_url):
        logger.debug(f"Detected YouTube ID format: {youtube_url}")
        return f'https://www.youtube.com/watch?v={youtube_url}'

    parsed = urlparse(youtube_url)
    if parsed.scheme == '':
        if '.' not in youtube_url.split('/', 1)[0]:
            raise ValueError("Please enter a full YouTube URL or an 11-character video id")

        parsed_without_scheme = urlparse(f'https://{youtube_url}')
        if parsed_without_scheme.netloc:
            youtube_url = f'https://{youtube_url}'
            parsed = parsed_without_scheme

    if parsed.scheme not in ('http', 'https'):
        raise ValueError("Invalid YouTube URL scheme")

    host = parsed.netloc.lower()
    if host.startswith('www.'):
        host = host[4:]

    video_id = None
    if host in ('youtu.be', 'youtube.com', 'm.youtube.com', 'music.youtube.com'):
        if host == 'youtu.be':
            video_id = parsed.path.strip('/').split('/')[0]
        elif parsed.path == '/watch':
            video_id = parse_qs(parsed.query).get('v', [''])[0]
        elif parsed.path.startswith('/embed/'):
            video_id = parsed.path.split('/embed/', 1)[1].split('/')[0]
        elif parsed.path.startswith('/shorts/'):
            video_id = parsed.path.split('/shorts/', 1)[1].split('/')[0]
        elif parsed.path.startswith('/live/'):
            video_id = parsed.path.split('/live/', 1)[1].split('/')[0]
    else:
        raise ValueError("Invalid YouTube URL host")

    if not video_id or not YOUTUBE_ID_PATTERN.match(video_id):
        raise ValueError("Could not extract video id from YouTube URL")

    logger.debug(f"Normalized YouTube URL with video ID: {video_id}")
    return f'https://www.youtube.com/watch?v={video_id}'


def download_youtube_with_yt_dlp(youtube_url: str, download_dir: str) -> str:
    """
    Download YouTube video audio using yt-dlp.
    
    Args:
        youtube_url: Normalized YouTube URL
        download_dir: Directory to save the downloaded file
        
    Returns:
        Path to the downloaded file
        
    Raises:
        RuntimeError: If yt-dlp is not installed or download fails
    """
    youtube_downloader = YoutubeDL
    if youtube_downloader is None:
        try:
            from yt_dlp import YoutubeDL as ImportedYoutubeDL
            youtube_downloader = ImportedYoutubeDL
        except ImportError as e:
            raise RuntimeError(
                "yt_dlp is not installed in the Python environment running the backend"
            ) from e

    output_template = os.path.join(download_dir, '%(id)s.%(ext)s')
    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': output_template,
        'quiet': True,
        'no_warnings': True,
        'noplaylist': True,
        'nocheckcertificate': True,
        'geo_bypass': True,
        'socket_timeout': 30,
        'cachedir': False,
        'http_headers': {
            'User-Agent': (
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/125.0.0.0 Safari/537.36'
            ),
            'Accept-Language': 'en-US,en;q=0.9',
            'Referer': 'https://www.youtube.com/',
        },
    }

    logger.info(f"Downloading YouTube video: {youtube_url}")
    
    try:
        with youtube_downloader(ydl_opts) as ydl:
            info = ydl.extract_info(youtube_url, download=True)
    except Exception as e:
        logger.error(f"yt-dlp download failed: {str(e)}")
        raise RuntimeError(f"YouTube download failed: {str(e)}") from e

    if not info:
        raise RuntimeError('yt_dlp failed to extract video info')

    if isinstance(info, dict):
        downloads = info.get('requested_downloads') or []
        if downloads and downloads[0].get('filepath'):
            file_path = downloads[0]['filepath']
            logger.info(f"Download successful: {file_path}")
            return file_path
        if info.get('filepath'):
            logger.info(f"Download successful: {info['filepath']}")
            return info['filepath']
        if info.get('_filename'):
            logger.info(f"Download successful: {info['_filename']}")
            return info['_filename']

    # Fallback: search the download directory for the file
    logger.debug(f"Using fallback file search in {download_dir}")
    file_candidates = [os.path.join(download_dir, f) for f in os.listdir(download_dir)]
    file_candidates = [f for f in file_candidates if os.path.isfile(f)]
    if file_candidates:
        newest_file = max(file_candidates, key=os.path.getmtime)
        logger.info(f"Found downloaded file: {newest_file}")
        return newest_file

    raise RuntimeError('yt_dlp did not return a download path')


DEFAULT_YOUTUBE_HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/125.0.0.0 Safari/537.36'
    ),
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://www.youtube.com/',
}


def _get_youtube_downloader():
    youtube_downloader = YoutubeDL
    if youtube_downloader is None:
        try:
            from yt_dlp import YoutubeDL as ImportedYoutubeDL
            youtube_downloader = ImportedYoutubeDL
        except ImportError as e:
            raise RuntimeError("yt_dlp is not installed in the Python environment") from e
    return youtube_downloader


def _is_audio_format(format_info: dict) -> bool:
    acodec = (format_info.get('acodec') or '').lower()
    return bool(format_info.get('url')) and acodec not in ('', 'none')


def _audio_format_score(format_info: dict) -> tuple:
    protocol = str(format_info.get('protocol') or '')
    ext = str(format_info.get('ext') or '')
    try:
        abr = float(format_info.get('abr') or format_info.get('tbr') or 0)
    except (TypeError, ValueError):
        abr = 0.0

    # Prefer simple HTTP audio streams; FFmpeg can read these immediately.
    protocol_score = 2 if protocol in ('https', 'http') else 1
    ext_score = 1 if ext in ('m4a', 'webm', 'mp4') else 0
    return protocol_score, ext_score, abr


def get_youtube_stream_source(youtube_url: str) -> dict:
    """
    Extract direct audio stream details from YouTube without downloading.
    
    This is used for real-time streaming and live translation.
    
    Args:
        youtube_url: Normalized YouTube URL
        
    Returns:
        Dict with a direct stream URL plus headers FFmpeg should send
        
    Raises:
        RuntimeError: If yt-dlp fails or no stream is available
    """
    youtube_downloader = _get_youtube_downloader()

    ydl_opts = {
        'format': 'bestaudio[acodec!=none]/bestaudio/best',
        'quiet': True,
        'no_warnings': True,
        'noplaylist': True,
        'nocheckcertificate': True,
        'geo_bypass': True,
        'socket_timeout': 30,
        'cachedir': False,
        'http_chunk_size': 1048576,
        'http_headers': DEFAULT_YOUTUBE_HEADERS,
    }

    logger.info(f"Extracting stream URL from: {youtube_url}")
    
    try:
        with youtube_downloader(ydl_opts) as ydl:
            info = ydl.extract_info(youtube_url, download=False)
    except Exception as e:
        logger.error(f"Stream extraction failed: {str(e)}")
        raise RuntimeError(f"Failed to extract stream: {str(e)}") from e

    if not info:
        raise RuntimeError('yt_dlp failed to extract video info')

    if isinstance(info, dict):
        formats = info.get('formats') or []
        audio_candidates = [f for f in formats if _is_audio_format(f)]
        if not audio_candidates:
            audio_candidates = [info] if _is_audio_format(info) else []

        if audio_candidates:
            best = max(audio_candidates, key=_audio_format_score)
            url = best.get('url')
            if url:
                headers = dict(DEFAULT_YOUTUBE_HEADERS)
                headers.update(info.get('http_headers') or {})
                headers.update(best.get('http_headers') or {})
                logger.info("Stream URL extracted successfully")
                return {
                    "url": url,
                    "headers": headers,
                    "format_id": best.get('format_id'),
                    "protocol": best.get('protocol'),
                    "ext": best.get('ext'),
                    "is_live": bool(info.get('is_live')),
                    "source": youtube_url,
                }

    raise RuntimeError('Could not obtain a stream URL from yt_dlp')


def get_youtube_stream_url(youtube_url: str) -> str:
    """Backward-compatible helper that returns only the direct stream URL."""
    return get_youtube_stream_source(youtube_url)["url"]


def is_youtube_url(url: str) -> bool:
    """
    Check if a URL is a YouTube URL.
    
    Args:
        url: URL to check
        
    Returns:
        True if URL is a YouTube URL, False otherwise
    """
    if not url or not isinstance(url, str):
        return False
    
    url_lower = url.lower().strip()
    return (
        'youtube.com' in url_lower or 
        'youtu.be' in url_lower or 
        'm.youtube.com' in url_lower or
        'music.youtube.com' in url_lower
    )
