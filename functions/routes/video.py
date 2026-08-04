from flask import Blueprint, Response, request, jsonify, stream_with_context
from services.gemini_service import (
    stream_translated_video_segments,
    summarize_video,
    translate_video
)
from services.youtube_service import (
    normalize_youtube_url,
    download_youtube_with_yt_dlp,
    get_youtube_stream_source
)
from services.audio_stream_service import remove_temp_dir
from services.speech_service import transcribe_audio
from services.translation_service import translate_text
from services.subtitle_service import get_subtitle_service
from utils.logger import get_logger
import tempfile
import os
import json
import io
from pydub import AudioSegment

# Initialize logger
logger = get_logger("video_routes")

video_bp = Blueprint("video_bp", __name__)

SUPPORTED_VIDEO_FORMATS = {
    '.mp4', '.m4v', '.mov', '.avi', '.mkv', '.webm', '.3gp', '.flv', '.mpeg', '.wav'
}

DEFAULT_RECORDED_VIDEO_EXTENSION = '.mp4'


def _get_form_value(form_data, *names, default=""):
    """Get normalized form value with multiple name aliases."""
    normalized_form = {
        key.strip(): value.strip()
        for key, value in form_data.items()
        if isinstance(value, str)
    }

    for name in names:
        value = normalized_form.get(name)
        if value:
            return value

    return default



def _get_upload_extension(filename: str) -> str:
    """Validate and return file extension."""
    file_extension = os.path.splitext((filename or "").lower())[1]
    if not file_extension:
        return DEFAULT_RECORDED_VIDEO_EXTENSION

    if file_extension not in SUPPORTED_VIDEO_FORMATS:
        raise ValueError(f"Unsupported video format. Supported: {', '.join(SUPPORTED_VIDEO_FORMATS)}")

    return file_extension


def _process_youtube_video(youtube_url, processor, source_language, model, operation_name):
    """Process YouTube video with processor function."""
    try:
        youtube_url = normalize_youtube_url(youtube_url)
        logger.info(f"Processing YouTube video: {operation_name}")
    except ValueError as e:
        logger.error(f"Invalid YouTube URL: {str(e)}")
        return jsonify({"error": str(e)}), 400

    download_errors = []
    temp_dir = None

    try:
        temp_dir = tempfile.mkdtemp()
        try:
            temp_file_path = download_youtube_with_yt_dlp(youtube_url, temp_dir)
            if not temp_file_path or not os.path.exists(temp_file_path):
                raise RuntimeError('yt_dlp download did not produce a file')
            
            logger.info(f"Downloaded YouTube video, processing with {operation_name}")
            result = processor(temp_file_path, source_language, model)
            return jsonify(result), 200
        except Exception as e:
            download_errors.append(f"yt_dlp: {e}")
            logger.warning(f"yt_dlp download failed: {e}")
    finally:
        remove_temp_dir(temp_dir)

    # If yt_dlp fails, try pytube as fallback
    if not download_errors:
        logger.info(f"{operation_name} completed successfully")
        return jsonify({"error": "No downloader available"}), 500
    
    error_message = "; ".join(download_errors) if download_errors else 'No downloader available'
    logger.error(f"Failed to download YouTube video: {error_message}")
    return jsonify({"error": f"Failed to download YouTube video: {error_message}"}), 500



@video_bp.route("/video-translate", methods=["POST"])
def video_translate():
    """Translate a video from a file upload or YouTube URL."""
    try:
        source_language = _get_form_value(
            request.form,
            "source_language",
            "source_lanuage",
            default="auto"
        )
        target_language = _get_form_value(
            request.form,
            "target_language",
            "target_lanuage"
        )
        model = _get_form_value(
            request.form,
            "model",
            default=""
        )

        if not target_language:
            return jsonify({"error": "Missing target_language"}), 400

        # If a file was uploaded, handle it
        if "video" in request.files:
            video_file = request.files["video"]
            if not video_file or video_file.filename == "":
                return jsonify({"error": "No video file selected"}), 400

            try:
                file_extension = _get_upload_extension(video_file.filename or "")
            except ValueError as e:
                return jsonify({"error": str(e)}), 400

            temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_extension)
            temp_file.close()

            try:
                video_file.save(temp_file.name)
                logger.info(f"Processing uploaded video file: {video_file.filename}")
                result = translate_video(
                    temp_file.name,
                    source_language,
                    target_language,
                    model
                )

                return jsonify(result), 200

            except Exception as e:
                logger.error(f"Translation error: {str(e)}")
                return jsonify({"error": str(e)}), 500

            finally:
                try:
                    if os.path.exists(temp_file.name):
                        os.remove(temp_file.name)
                except Exception:
                    pass

        # If youtube_url is provided, attempt to download and process
        youtube_url = _get_form_value(request.form, 'youtube_url')
        if youtube_url:
            return _process_youtube_video(
                youtube_url,
                translate_video,
                source_language,
                model,
                "Translation"
            )

        return jsonify({"error": "Missing video file or youtube_url"}), 400

    except Exception as e:
        logger.error(f"Unexpected error in video_translate: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


@video_bp.route("/video-summarize", methods=["POST"])
def video_summarize():
    """Summarize a video from a file upload or YouTube URL."""
    try:
        source_language = _get_form_value(
            request.form,
            "source_language",
            "source_lanuage",
            default="auto"
        )
        model = _get_form_value(
            request.form,
            "model",
            default=""
        )

        if "video" in request.files:
            video_file = request.files["video"]
            if not video_file or video_file.filename == "":
                return jsonify({"error": "No video file selected"}), 400

            try:
                file_extension = _get_upload_extension(video_file.filename or "")
            except ValueError as e:
                return jsonify({"error": str(e)}), 400

            temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_extension)
            temp_file.close()

            try:
                video_file.save(temp_file.name)
                logger.info(f"Summarizing uploaded video: {video_file.filename}")
                result = summarize_video(temp_file.name, source_language, model)
                return jsonify(result), 200

            except Exception as e:
                logger.error(f"Summarization error: {str(e)}")
                return jsonify({"error": str(e)}), 500

            finally:
                try:
                    if os.path.exists(temp_file.name):
                        os.remove(temp_file.name)
                except Exception:
                    pass

        youtube_url = _get_form_value(request.form, 'youtube_url')
        if youtube_url:
            return _process_youtube_video(
                youtube_url,
                summarize_video,
                source_language,
                model,
                "Summarization"
            )

        return jsonify({"error": "Missing video file or youtube_url"}), 400

    except Exception as e:
        logger.error(f"Unexpected error in video_summarize: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


def _json_stream_event(payload):
    """Format a payload as NDJSON event."""
    return json.dumps(payload, ensure_ascii=False) + "\n"


def _should_fallback_to_download(segment):
    if not isinstance(segment, dict):
        return False
    if segment.get("fallback_needed") is True:
        return True
    if segment.get("type") != "error":
        return False

    message = str(segment.get("message") or "").lower()
    if "stream" in message or "connection" in message or "ffmpeg" in message:
        return True
    return False


def _normalize_stream_segments(stream_segments):
    """Clamp stream segments into a monotonic, non-overlapping timeline."""
    last_end = None
    for segment in stream_segments:
        if not isinstance(segment, dict) or segment.get("type") != "segment":
            yield segment
            continue

        try:
            start = float(segment.get("start") or 0)
            end = float(segment.get("end") or start or 0)
        except (TypeError, ValueError):
            yield segment
            continue

        if end <= start:
            end = start + 0.25

        if last_end is not None and start < last_end:
            start = last_end
            if end <= start:
                end = start + 0.25

        normalized_segment = dict(segment)
        normalized_segment["start"] = start
        normalized_segment["end"] = end
        last_end = end
        yield normalized_segment


@video_bp.route("/youtube/live-translate", methods=["POST"])
@video_bp.route("/video-translate-stream", methods=["POST"])
def video_translate_stream():
    """Stream-based video translation endpoint for real-time subtitle delivery."""
    source_language = _get_form_value(
        request.form,
        "source_language",
        "source_lanuage",
        default="auto"
    )
    target_language = _get_form_value(
        request.form,
        "target_language",
        "target_lanuage"
    )
    model = _get_form_value(request.form, "model", default="")
    youtube_url = _get_form_value(request.form, "youtube_url")
    force_download = _get_form_value(request.form, "force_download")

    if not target_language:
        return jsonify({"error": "Missing target_language"}), 400

    if not youtube_url:
        return jsonify({"error": "Missing youtube_url"}), 400

    try:
        youtube_url = normalize_youtube_url(youtube_url)
        logger.info(f"Starting stream translation: {youtube_url}")
    except ValueError as e:
        return jsonify({"error": str(e)}), 400

    def generate():
        try:
            yield _json_stream_event({
                "type": "status",
                "message": "Preparing YouTube audio (stream mode)"
            })

            force_download_flag = str(force_download).strip().lower() in ("1", "true", "yes")
            need_download_fallback = False
            segment_count = 0

            if force_download_flag:
                logger.info("Force download mode enabled")
                yield _json_stream_event({"type": "status", "message": "Downloading YouTube video (forced)"})
                temp_dir = None
                try:
                    temp_dir = tempfile.mkdtemp()
                    temp_file_path = download_youtube_with_yt_dlp(youtube_url, temp_dir)
                    if not temp_file_path or not os.path.exists(temp_file_path):
                        raise RuntimeError('Download did not produce a file')

                    for segment in _normalize_stream_segments(stream_translated_video_segments(
                        temp_file_path,
                        source_language,
                        target_language,
                        model
                    )):
                        if isinstance(segment, dict) and segment.get("type") == "segment":
                            segment_count += 1
                        yield _json_stream_event(segment)

                except Exception as e:
                    logger.error(f"Forced download processing failed: {e}")
                    yield _json_stream_event({"type": "error", "message": "Forced download processing failed", "error": str(e)})
                finally:
                    remove_temp_dir(temp_dir)

            else:
                logger.info("Streaming mode: attempting direct URL stream")
                try:
                    stream_source = get_youtube_stream_source(youtube_url)
                except Exception as e:
                    logger.warning(f"Stream URL extraction failed, falling back to download: {e}")
                    need_download_fallback = True
                    yield _json_stream_event({
                        "type": "status",
                        "message": "Stream unavailable, downloading for translation"
                    })
                else:
                    yield _json_stream_event({
                        "type": "status",
                        "message": "Listening for spoken phrases"
                    })

                    stream_start_count = segment_count
                    retry_stream = False
                    for segment in _normalize_stream_segments(stream_translated_video_segments(
                        stream_source,
                        source_language,
                        target_language,
                        model
                    )):
                        if _should_fallback_to_download(segment):
                            retry_stream = True
                            break

                        if isinstance(segment, dict) and segment.get("type") == "segment":
                            segment_count += 1
                        yield _json_stream_event(segment)

                    if retry_stream and segment_count == stream_start_count:
                        logger.info("Retrying stream with a fresh YouTube media URL")
                        yield _json_stream_event({
                            "type": "status",
                            "message": "Refreshing YouTube audio stream"
                        })

                        try:
                            stream_source = get_youtube_stream_source(youtube_url)
                        except Exception as e:
                            logger.warning(f"Fresh stream URL extraction failed: {e}")
                            need_download_fallback = True
                        else:
                            for segment in _normalize_stream_segments(stream_translated_video_segments(
                                stream_source,
                                source_language,
                                target_language,
                                model
                            )):
                                if _should_fallback_to_download(segment):
                                    logger.warning("Fresh stream retry requested download fallback")
                                    need_download_fallback = True
                                    break

                                if isinstance(segment, dict) and segment.get("type") == "segment":
                                    segment_count += 1
                                yield _json_stream_event(segment)
                    elif retry_stream:
                        logger.info("Stream ended after producing translated segments")

                    if segment_count == stream_start_count and not need_download_fallback:
                        logger.info("Stream produced no translated speech segments; falling back to download")
                        need_download_fallback = True
                        yield _json_stream_event({
                            "type": "status",
                            "message": "No translated speech received from stream, trying download fallback"
                        })

                if need_download_fallback:
                    logger.info("Executing fallback download strategy")
                    temp_dir = None
                    temp_file_path = None
                    try:
                        temp_dir = tempfile.mkdtemp()
                        try:
                            temp_file_path = download_youtube_with_yt_dlp(youtube_url, temp_dir)
                        except Exception as e:
                            logger.error(f"Fallback download failed: {e}")
                            yield _json_stream_event({
                                "type": "error",
                                "message": "Failed to download YouTube fallback",
                                "error": str(e)
                            })
                            return

                        for segment in _normalize_stream_segments(stream_translated_video_segments(
                            temp_file_path,
                            source_language,
                            target_language,
                            model
                        )):
                            if isinstance(segment, dict) and segment.get("type") == "segment":
                                segment_count += 1
                            yield _json_stream_event(segment)

                    finally:
                        remove_temp_dir(temp_dir)

            if segment_count == 0 and not force_download_flag and not need_download_fallback:
                logger.info("No stream segments were produced, ending translation stream")
            yield _json_stream_event({"type": "complete"})

        except Exception as e:
            logger.error(f"Streaming translation error: {str(e)}")
            yield _json_stream_event({
                "type": "error",
                "error": str(e)
            })

    return Response(
        stream_with_context(generate()),
        mimetype="application/x-ndjson",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no"
        }
    )


# WebSocket endpoint for real-time translation of live audio streams
# This will be registered via flask_sock in main.py
def register_websocket_routes(sock_instance):
    """
    Register WebSocket routes.
    Called from main.py to register WebSocket endpoints.
    
    Usage:
        from flask_sock import Sock
        sock = Sock(app)
        from routes.video import register_websocket_routes
        register_websocket_routes(sock)
    """
    
    @sock_instance.route("/ws/live-translation")
    def websocket_live_translation(ws):
        """
        WebSocket endpoint for real-time audio translation.
        
        Protocol:
        1. Client sends JSON config: {"source_language": "en", "target_language": "rw"}
        2. Client sends binary audio chunks (1-3 second MP3/WAV segments)
        3. Server responds with JSON events:
           {"type": "transcription", "text": "...", "language": "en"}
           {"type": "translation", "original": "...", "translated": "..."}
           {"type": "error", "error": "..."}
           {"type": "close"}
        """
        logger.info("WebSocket client connected for live translation")
        
        try:
            # Wait for configuration message
            config_msg = ws.receive()
            if isinstance(config_msg, str):
                config = json.loads(config_msg)
            else:
                logger.error("Expected string config message, got binary")
                ws.send(json.dumps({
                    "type": "error",
                    "error": "First message must be configuration JSON"
                }))
                return
            
            source_language = config.get("source_language", "auto")
            target_language = config.get("target_language", "")
            
            if not target_language:
                logger.error("Missing target_language in config")
                ws.send(json.dumps({
                    "type": "error",
                    "error": "Missing target_language"
                }))
                return
            
            logger.info(f"WebSocket configured: {source_language} -> {target_language}")
            
            ws.send(json.dumps({
                "type": "ready",
                "message": f"Ready for audio chunks ({source_language} -> {target_language})"
            }))
            
            subtitle_service = get_subtitle_service()
            segment_count = 0
            
            # Process incoming audio chunks
            while True:
                try:
                    # Receive binary audio chunk
                    audio_chunk = ws.receive()
                    
                    if audio_chunk is None:
                        logger.info("WebSocket client closed connection")
                        break
                    
                    if isinstance(audio_chunk, str):
                        # String message - might be a close command
                        try:
                            msg = json.loads(audio_chunk)
                            if msg.get("type") == "close":
                                logger.info("Client requested close")
                                ws.send(json.dumps({"type": "close"}))
                                break
                        except:
                            pass
                        continue
                    
                    # Process binary audio chunk
                    segment_count += 1
                    logger.debug(f"Received audio chunk #{segment_count} ({len(audio_chunk)} bytes)")
                    
                    try:
                        # Save audio chunk to temporary file
                        with tempfile.NamedTemporaryFile(
                            suffix=".wav",
                            delete=False
                        ) as temp_audio:
                            
                            # Convert binary data to audio if needed
                            try:
                                # Try to interpret as audio directly
                                audio = AudioSegment.from_file(
                                    io.BytesIO(audio_chunk),
                                    format="wav"
                                )
                            except:
                                try:
                                    # Try MP3 format
                                    audio = AudioSegment.from_file(
                                        io.BytesIO(audio_chunk),
                                        format="mp3"
                                    )
                                except:
                                    # If neither works, assume it's raw PCM data
                                    audio = AudioSegment(
                                        audio_chunk,
                                        frame_rate=16000,
                                        sample_width=2,
                                        channels=1
                                    )
                            
                            # Export to WAV
                            audio.export(temp_audio.name, format="wav")
                            temp_audio_path = temp_audio.name
                        
                        # Transcribe audio chunk
                        transcription = transcribe_audio(
                            temp_audio_path,
                            language=source_language if source_language != "auto" else None
                        )
                        
                        original_text = transcription.get("text", "").strip()
                        detected_language = transcription.get("language", source_language)
                        
                        if original_text:
                            logger.debug(f"Transcribed: {original_text}")
                            
                            ws.send(json.dumps({
                                "type": "transcription",
                                "text": original_text,
                                "language": detected_language,
                                "segment_index": segment_count
                            }, ensure_ascii=False))
                            
                            # Translate text
                            try:
                                translated_text = translate_text(
                                    original_text,
                                    detected_language,
                                    target_language
                                )
                                
                                logger.debug(f"Translated: {translated_text}")
                                
                                ws.send(json.dumps({
                                    "type": "translation",
                                    "original": original_text,
                                    "translated": translated_text,
                                    "source_language": detected_language,
                                    "target_language": target_language,
                                    "segment_index": segment_count
                                }, ensure_ascii=False))
                                
                            except Exception as translate_error:
                                logger.error(f"Translation error: {str(translate_error)}")
                                ws.send(json.dumps({
                                    "type": "error",
                                    "error": f"Translation failed: {str(translate_error)}",
                                    "segment_index": segment_count
                                }))
                        else:
                            logger.debug(f"No speech detected in chunk #{segment_count}")
                            ws.send(json.dumps({
                                "type": "silence",
                                "segment_index": segment_count
                            }))
                        
                        # Cleanup
                        try:
                            os.remove(temp_audio_path)
                        except:
                            pass
                        
                    except Exception as chunk_error:
                        logger.error(f"Error processing chunk #{segment_count}: {str(chunk_error)}")
                        ws.send(json.dumps({
                            "type": "error",
                            "error": f"Processing failed: {str(chunk_error)}",
                            "segment_index": segment_count
                        }))
                
                except Exception as receive_error:
                    logger.warning(f"Error receiving message: {str(receive_error)}")
                    break
        
        except Exception as e:
            logger.error(f"WebSocket error: {str(e)}")
            try:
                ws.send(json.dumps({
                    "type": "error",
                    "error": str(e)
                }))
            except:
                pass
        
        finally:
            logger.info("WebSocket connection closed")
    
    return sock_instance


@video_bp.route("/youtube/live-translate", methods=["OPTIONS"])
def video_translate_options():
    return "", 204


@video_bp.route("/video-summarize", methods=["OPTIONS"])
def video_summarize_options():
    return "", 204


@video_bp.route("/video-translate-stream", methods=["OPTIONS"])
def video_translate_stream_options():
    return "", 204
