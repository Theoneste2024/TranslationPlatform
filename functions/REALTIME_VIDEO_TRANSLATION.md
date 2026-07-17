# Real-Time Video Translation Platform

## Overview

This document describes the real-time video translation system that has been integrated into the Translation Platform backend. The system supports:

- **Live video translation** without downloading files
- **WebSocket-based audio streaming** for real-time translation
- **YouTube Live stream support** for instantaneous subtitle generation
- **Memory-efficient chunked processing** for long videos
- **Fallback mechanisms** for reliability
- **100% backward compatibility** with existing endpoints

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                   Flask Application                          │
│                     (main.py)                                │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  HTTP REST API Routes                                │  │
│  │  ├─ POST /video-translate (backward compatible)     │  │
│  │  ├─ POST /video-summarize (backward compatible)     │  │
│  │  ├─ POST /video-translate-stream (streaming)        │  │
│  │  └─ POST /youtube/live-translate (NEW)              │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  WebSocket Routes                                    │  │
│  │  └─ GET /ws/live-translation (NEW)                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Service Layer                                       │  │
│  │  ├─ youtube_service.py        → YouTube operations  │  │
│  │  ├─ audio_stream_service.py   → FFmpeg streaming   │  │
│  │  ├─ speech_service.py         → Whisper + memory   │  │
│  │  ├─ translation_service.py    → Gemini API         │  │
│  │  ├─ subtitle_service.py       → Subtitle mgmt      │  │
│  │  ├─ tts_service.py            → Text-to-speech     │  │
│  │  └─ gemini_service.py         → Core logic (existing) │  │
│  └──────────────────────────────────────────────────────┘  │
│                          │                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Utilities                                           │  │
│  │  └─ utils/logger.py          → Structured logging   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                      │                       │
         ↓                      ↓                       ↓
    yt-dlp         FFmpeg          Faster Whisper    Gemini API
   (YouTube)      (Audio)         (Transcription)   (Translation)
```

### Data Flow

#### 1. HTTP Streaming Mode (POST /video-translate-stream)

```
Client                              Server
  │                                   │
  ├─ POST /video-translate-stream     │
  │  (YouTube URL)                    │
  │                                   │
  ├───────────────────────────────→   │
  │                                   ├─ Normalize URL
  │                                   │
  │                  ← ──── NDJSON stream ────
  │                                   │
  │  (status messages)                ├─ Extract stream URL
  │  (segments)                       ├─ FFmpeg: chunk audio
  │  (complete)                       ├─ Whisper: transcribe
  │                                   ├─ Gemini: translate
  │  ← ──────────── NDJSON ─────────  │
  │                                   │
```

#### 2. WebSocket Real-Time Mode (GET /ws/live-translation)

```
Client                              Server
  │                                   │
  ├─ WebSocket upgrade                │
  │  to /ws/live-translation          │
  │                                   │
  ├───────────────────────────────→   │
  │                                   │
  │  ← ─── JSON config ───────────    │
  │  (ready for audio chunks)         │
  │                                   │
  │  Send binary audio chunk          │
  │  (1-3 seconds, MP3/WAV)          │
  │  ─────────────────────────────→  │
  │                                   ├─ Transcribe
  │                                   ├─ Translate
  │  ← ─── JSON events ───────────    │
  │  {type: transcription, ...}       │
  │  {type: translation, ...}         │
  │                                   │
  │  (repeat for each chunk)          │
  │                                   │
```

#### 3. YouTube Live Mode (POST /youtube/live-translate)

```
YouTube Live Stream
       │
       ↓
   yt-dlp (extract stream URL)
       │
       ├─ Direct streaming URL
       │
       ↓
   FFmpeg (segment audio)
       │
       ├─ 12-second chunks
       │
       ↓
   Faster Whisper (transcribe each chunk)
       │
       ├─ Memory-aware retry
       │
       ↓
   Gemini API (translate)
       │
       └─→ NDJSON stream to client
```

---

## API Endpoints

### 1. Real-Time YouTube Translation (NEW)

**Endpoint:** `POST /youtube/live-translate`

**Content-Type:** `application/json`

**Request Body:**
```json
{
  "youtube_url": "https://www.youtube.com/watch?v=...",
  "source_language": "en",
  "target_language": "rw",
  "model": "gemini-2.5-flash"
}
```

**Response:** `application/x-ndjson` (streaming)

**Response Events:**

```json
{"type": "status", "message": "Preparing YouTube stream"}
{"type": "status", "message": "Connected to stream, listening for audio"}
{"type": "segment", "index": 0, "start": 0.0, "end": 2.5, "original_text": "Hello", "translated_text": "Mwaramutse", "language": "rw"}
{"type": "complete"}
```

**Example:**
```bash
curl -X POST http://localhost:5000/youtube/live-translate \
  -H "Content-Type: application/json" \
  -d '{
    "youtube_url": "https://youtu.be/SyPDTAPfcos",
    "source_language": "en",
    "target_language": "rw"
  }'
```

---

### 2. WebSocket Live Audio Translation (NEW)

**Endpoint:** `GET /ws/live-translation`

**Upgrade:** WebSocket

**Protocol:**

1. **Connect**
   ```
   GET /ws/live-translation HTTP/1.1
   Upgrade: websocket
   Connection: Upgrade
   ```

2. **Send Configuration (JSON)**
   ```json
   {
     "source_language": "en",
     "target_language": "rw"
   }
   ```

3. **Server Response**
   ```json
   {
     "type": "ready",
     "message": "Ready for audio chunks (en -> rw)"
   }
   ```

4. **Send Audio Chunks (Binary)**
   - Format: MP3, WAV, or raw PCM
   - Duration: 1-3 seconds per chunk
   - Sample rate: 16kHz recommended

5. **Server Responses**
   ```json
   {
     "type": "transcription",
     "text": "Good morning",
     "language": "en",
     "segment_index": 1
   }
   ```
   ```json
   {
     "type": "translation",
     "original": "Good morning",
     "translated": "Mwaramutse",
     "source_language": "en",
     "target_language": "rw",
     "segment_index": 1
   }
   ```

6. **Close Connection**
   - Client: `{"type": "close"}`
   - Server: `{"type": "close"}`

**JavaScript Example:**
```javascript
const ws = new WebSocket('ws://localhost:5000/ws/live-translation');

ws.onopen = () => {
  // Send configuration
  ws.send(JSON.stringify({
    source_language: "en",
    target_language: "rw"
  }));
};

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  console.log('Translation:', msg);
};

// Send audio chunk
const audioChunk = ... // binary audio data
ws.send(audioChunk);
```

---

### 3. Backward Compatible Endpoints

All existing endpoints remain unchanged and fully functional:

#### `/video-translate` (POST)
Upload a video or provide YouTube URL for translation.

#### `/video-summarize` (POST)
Get a summary of video content.

#### `/video-translate-stream` (POST)
Stream-based translation with NDJSON response format.

---

## Services Architecture

### youtube_service.py

Handles YouTube operations:
- URL normalization (supports various formats)
- Stream extraction (without downloading)
- Video downloading with fallbacks
- Language detection from URL

**Key Functions:**
```python
normalize_youtube_url(raw_url: str) -> str
get_youtube_stream_url(youtube_url: str) -> str
download_youtube_with_yt_dlp(youtube_url: str, download_dir: str) -> str
```

---

### audio_stream_service.py

Handles audio streaming and chunking:
- FFmpeg-based audio extraction
- Memory-efficient chunking (12-second segments)
- Audio validation
- Duration calculation

**Key Functions:**
```python
stream_audio_in_chunks(source, output_dir, chunk_seconds=12) -> Generator[str]
extract_audio_from_file(video_file_path, output_dir) -> str
get_audio_duration(audio_file_path) -> float
validate_audio_file(audio_file_path) -> bool
remove_temp_dir(temp_dir: str) -> None
```

---

### speech_service.py

Wraps Faster Whisper with memory management:
- Automatic retry with smaller models on memory errors
- Multi-model fallback (large → medium → small → base → tiny)
- BLAS/MKL thread limiting for CPU efficiency
- Segment boundary detection

**Key Class:**
```python
class WhisperService:
    def transcribe(audio_path, language=None, task="transcribe") -> Dict
    def get_model_size() -> str
```

---

### translation_service.py

Wraps Gemini API:
- Batch translation for efficiency
- Per-sentence fallback on batch failures
- Language code to name conversion
- Retry logic

**Key Class:**
```python
class TranslationService:
    def translate(text, source_language, target_language) -> str
    def translate_batch(texts, source_language, target_language) -> List[str]
```

---

### subtitle_service.py

Manages subtitle formatting and delivery:
- Subtitle timing calculations
- SRT format generation
- Display time estimation
- Subtitle merging for UI performance

**Key Class:**
```python
class SubtitleService:
    def create_subtitle_event(...) -> SubtitleEvent
    def format_subtitle_for_display(text) -> str
    def estimate_display_time(text) -> float
```

---

### tts_service.py

Text-to-speech support (optional):
- Edge TTS (Bing) integration
- Multiple voices per language
- Configurable speech rate

**Key Class:**
```python
class TTSService:
    def synthesize(text, language, voice=None) -> Tuple[str, bytes]
    def save_to_file(text, language, output_path) -> str
```

---

### logger.py

Centralized logging:
- Structured log formatting
- Level control via environment
- Per-module logger instances

**Key Functions:**
```python
get_logger(name: str) -> Logger
log_info(message, **kwargs)
log_error(message, **kwargs)
log_exception(message, exc, **kwargs)
```

---

## Installation & Setup

### Prerequisites

- Python 3.8+
- FFmpeg (system-level binary, not just ffmpeg-python package)
- 2GB+ RAM (for Whisper models)

### Install FFmpeg

**Windows:**
```bash
# Using Chocolatey
choco install ffmpeg

# Or download from: https://ffmpeg.org/download.html
# Add to PATH
```

**macOS:**
```bash
brew install ffmpeg
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install ffmpeg
```

### Install Python Packages

All 13 required packages are already installed:
```bash
pip list | grep -E "flask|faster|yt-dlp|pydub|numpy|websockets"
```

**Core packages installed:**
- `flask`: Web framework
- `flask-sock`: WebSocket support
- `flask-cors`: Cross-origin resource sharing
- `python-dotenv`: Environment configuration
- `google-generativeai`: Gemini API client
- `faster-whisper`: Speech recognition
- `ffmpeg-python`: Audio processing
- `yt-dlp`: YouTube extraction
- `pydub`: Audio format conversion
- `soundfile`: Audio file I/O
- `numpy`: Numerical computing
- `websockets`: WebSocket protocol
- `edge-tts`: Text-to-speech

### Environment Variables

**Optional Configuration:**
```bash
# Whisper model size (tiny, base, small, medium, large)
export WHISPER_MODEL_SIZE=small

# Whisper device (cpu, cuda)
export WHISPER_DEVICE=cpu

# Whisper compute type (float32, float16, int8)
export WHISPER_COMPUTE_TYPE=int8

# Google API key (required)
export GEMINI_API_KEY=your_api_key_here

# BLAS thread limits (memory optimization)
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
```

### Start the Server

```bash
cd functions/
python main.py
```

Server starts at `http://localhost:5000`

---

## Real-World Usage Scenarios

### Scenario 1: Live Event Broadcasting

**Use Case:** Translating a live YouTube broadcast into multiple languages

**Implementation:**
```bash
# Start translation to French
curl -X POST http://localhost:5000/youtube/live-translate \
  -H "Content-Type: application/json" \
  -d '{
    "youtube_url": "https://www.youtube.com/watch?v=live_id",
    "source_language": "en",
    "target_language": "fr"
  }' \
  | jq '.translated_text'

# Start translation to Kinyarwanda simultaneously
curl -X POST http://localhost:5000/youtube/live-translate \
  -H "Content-Type: application/json" \
  -d '{
    "youtube_url": "https://www.youtube.com/watch?v=live_id",
    "source_language": "en",
    "target_language": "rw"
  }' \
  | jq '.translated_text'
```

### Scenario 2: Mobile App with WebSocket

**Use Case:** Real-time subtitles on Flutter mobile app during a call or recording

**Flutter Code Example:**
```dart
import 'package:web_socket_channel/web_socket_channel.dart';

final channel = WebSocketChannel.connect(
  Uri.parse('ws://192.168.1.100:5000/ws/live-translation'),
);

// Send configuration
channel.sink.add(jsonEncode({
  'source_language': 'en',
  'target_language': 'rw',
}));

// Listen for translations
channel.stream.listen((msg) {
  final event = jsonDecode(msg);
  if (event['type'] == 'translation') {
    setState(() {
      subtitles = event['translated'];
    });
  }
});

// Send audio chunk
channel.sink.add(audioBytes);
```

### Scenario 3: Server-to-Server Broadcasting

**Use Case:** Translation service embedded in media server

**Implementation:**
```python
import requests
import json

# Start real-time translation stream
response = requests.post(
    'http://api.translation-server.local:5000/youtube/live-translate',
    json={
        'youtube_url': 'https://youtu.be/live_video_id',
        'source_language': 'en',
        'target_language': 'rw'
    },
    stream=True
)

# Process NDJSON events
for line in response.iter_lines():
    event = json.loads(line)
    
    if event['type'] == 'segment':
        print(f"[{event['start']}-{event['end']}] {event['translated_text']}")
    
    elif event['type'] == 'error':
        print(f"Error: {event['error']}")
    
    elif event['type'] == 'complete':
        print("Translation complete")
        break
```

---

## Performance Characteristics

### Memory Usage

| Component | RAM | Notes |
|-----------|-----|-------|
| Whisper (tiny) | ~1GB | Minimum memory footprint |
| Whisper (small) | ~2GB | Recommended for 32-minute videos |
| Whisper (medium) | ~5GB | Requires >8GB system RAM |
| Whisper (large) | ~10GB | Not recommended for CPU |
| FFmpeg chunking | <100MB | Memory-efficient streaming |
| Gemini API client | ~50MB | Lightweight |
| Flask application | ~100MB | Base overhead |

### Latency

| Operation | Latency | Notes |
|-----------|---------|-------|
| URL extraction | 500ms | yt-dlp overhead |
| Audio chunking (per 12s) | 1-2s | FFmpeg processing |
| Transcription (per chunk) | 5-15s | Whisper inference on CPU |
| Translation (per segment) | 1-3s | Gemini API call |
| Total per 12s segment | 8-20s | End-to-end latency |

**Real-time Ratio:** 0.67-1.67× (for typical speech)

### Throughput

| Metric | Value |
|--------|-------|
| Max concurrent streams | 5-10 | (Depends on system) |
| Videos per hour | 3-5 | (At normal speed) |
| Languages supported | 100+ | (Gemini + Whisper) |
| Supported formats | 20+ | (FFmpeg coverage) |

---

## Error Handling & Resilience

### Automatic Fallback Strategies

1. **Stream URL Extraction Failure**
   - Fallback: Download video using yt-dlp
   - Delay: ~10-30 seconds

2. **Transcription Memory Error**
   - Fallback: Retry with smaller Whisper model
   - Progression: large → medium → small → base → tiny
   - Each retry triggers `gc.collect()`

3. **Transcription Network Error**
   - Fallback: Continue with next chunk
   - Error logged but translation continues

4. **Translation Batch Failure**
   - Fallback: Per-sentence translation
   - Reduces efficiency but ensures completion

### Error Events

Sent to client as NDJSON:
```json
{
  "type": "error",
  "message": "Description",
  "error": "Technical details",
  "segment_index": 0,
  "recoverable": true
}
```

---

## Monitoring & Debugging

### Logs

Enable detailed logging:
```bash
export LOGLEVEL=DEBUG
python main.py
```

**Log Output:**
```
[INFO] youtube_service: Normalized YouTube URL with video ID: dQw4w9WgXcQ
[DEBUG] audio_stream_service: Starting audio stream chunking: source=https://..., chunk_size=12s
[DEBUG] speech_service: Transcription attempt 1 with model: small
[INFO] translation_service: Batch translating 5 texts: English -> Kinyarwanda
[DEBUG] subtitle_service: Formatted subtitle into 2 lines
```

### Health Checks

```bash
# Check API status
curl http://localhost:5000/

# Check FFmpeg availability
which ffmpeg

# Check Python packages
pip list

# Test YouTube URL normalization
python -c "from services.youtube_service import normalize_youtube_url; \
  print(normalize_youtube_url('https://youtu.be/abc123xyz'))"

# Test Whisper model
python -c "from services.speech_service import get_speech_service; \
  svc = get_speech_service(); print(svc.get_model_size())"
```

---

## Best Practices

### For Developers

1. **Use service layer functions**
   ```python
   # ✅ Good
   from services.translation_service import translate_text
   result = translate_text("Hello", "en", "rw")
   
   # ❌ Bad - calling Gemini directly
   from google import genai
   # ...
   ```

2. **Clean up temporary files**
   ```python
   # ✅ Good
   from services.audio_stream_service import remove_temp_dir
   remove_temp_dir(temp_dir)
   
   # ❌ Bad - manual cleanup
   os.rmdir(temp_dir)
   ```

3. **Use logging consistently**
   ```python
   # ✅ Good
   from utils.logger import get_logger
   logger = get_logger("my_module")
   logger.info("Starting operation")
   
   # ❌ Bad
   print("Starting operation")
   ```

### For Operations

1. **Monitor system memory**
   - Watch for OOM errors
   - Set `WHISPER_MODEL_SIZE=tiny` if <4GB RAM

2. **Enable CORS if using cross-origin requests**
   - Already configured in Flask app
   - Adjust for production domains

3. **Use HTTPS in production**
   - Configure reverse proxy (nginx, Apache)
   - Install SSL certificate

4. **Rate limiting**
   - Recommend: 10 requests/minute per IP
   - Implement via reverse proxy

5. **Backup API keys**
   - Store `GEMINI_API_KEY` in `.env` file
   - Never commit to version control

---

## Troubleshooting

### FFmpeg Not Found
**Error:** `FileNotFoundError: ffmpeg not found`

**Solution:**
```bash
# Check if installed
which ffmpeg

# Install
# Windows: choco install ffmpeg
# macOS: brew install ffmpeg
# Linux: sudo apt-get install ffmpeg

# Verify
ffmpeg -version
```

### Out of Memory During Transcription
**Error:** `MemoryError: Unable to allocate X MiB`

**Solution:**
```bash
# Use smaller model
export WHISPER_MODEL_SIZE=tiny

# Or use quantization
export WHISPER_COMPUTE_TYPE=int8

# Restart server
python main.py
```

### YouTube URL Extraction Fails
**Error:** `RuntimeError: Could not obtain a stream URL from yt_dlp`

**Solution:**
```bash
# Check yt-dlp is updated
pip install --upgrade yt-dlp

# Try with force download
# POST /video-translate-stream with force_download=true

# Check internet connection
ping youtube.com
```

### Translation Takes Too Long
**Issue:** High latency between requests

**Causes:**
- Network latency to Gemini API
- Large audio segments
- Cold Whisper model start

**Solutions:**
- Use smaller audio chunks (1-2 seconds)
- Pre-load Whisper model on startup
- Optimize network (use CDN)

### WebSocket Connection Drops
**Issue:** Connection closes unexpectedly

**Causes:**
- Audio format not recognized
- Server-side exception
- Network interruption

**Solutions:**
```javascript
// Auto-reconnect
const reconnect = () => {
  ws = new WebSocket('ws://localhost:5000/ws/live-translation');
};

ws.onerror = (error) => {
  console.error('WebSocket error:', error);
  setTimeout(reconnect, 3000);
};

ws.onclose = () => {
  console.log('WebSocket closed');
  setTimeout(reconnect, 3000);
};
```

---

## Future Enhancements

Planned improvements:

1. **Multi-speaker support**
   - Speaker diarization
   - Individual subtitle tracks

2. **Emotion detection**
   - Sentiment analysis
   - Tone preservation in translation

3. **Real-time subtitling UI**
   - Web-based subtitle viewer
   - SRT export

4. **GPU support**
   - CUDA acceleration for Whisper
   - Reduced latency

5. **Multiple language simultaneous translation**
   - Translate to 5+ languages concurrently
   - Load balancing across workers

6. **Custom vocabulary**
   - Domain-specific terms
   - Proper noun recognition

---

## Support & Documentation

### Resources
- [Faster Whisper Documentation](https://github.com/SYSTRAN/faster-whisper)
- [Gemini API Documentation](https://ai.google.dev/docs)
- [yt-dlp Documentation](https://github.com/yt-dlp/yt-dlp)
- [Flask-Sock Documentation](https://github.com/miguelgrinberg/flask-sock)

### Reporting Issues

Include:
1. Full error message and stack trace
2. Reproduction steps
3. System information (OS, RAM, Python version)
4. Relevant log output
5. Video/URL that fails (if public)

---

## License

This translation platform is part of the Translation Platform project.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | 2026-07-10 | Added real-time streaming, WebSocket support, service layer refactoring |
| 1.0.0 | 2026-06-15 | Initial release with video upload and YouTube translation |

---

**Last Updated:** 2026-07-10  
**Maintained By:** Translation Platform Team
