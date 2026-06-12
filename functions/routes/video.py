from flask import Blueprint, request, jsonify
from services.gemini_service import translate_video
import tempfile
import os

video_bp = Blueprint("video_bp", __name__)

SUPPORTED_VIDEO_FORMATS = {
    '.mp4', '.m4v', '.mov', '.avi', '.mkv', '.webm', '.3gp', '.flv', '.mpeg', '.wav'
}


def _get_form_value(form_data, *names, default=""):
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


@video_bp.route("/video-translate", methods=["POST"])
def video_translate():
    try:
        if "video" not in request.files:
            return jsonify({"error": "Missing video file"}), 400

        video_file = request.files["video"]
        if not video_file or video_file.filename == "":
            return jsonify({"error": "No video file selected"}), 400

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

        filename = video_file.filename or ""
        file_extension = os.path.splitext(filename.lower())[1]

        if not file_extension or file_extension not in SUPPORTED_VIDEO_FORMATS:
            return jsonify({"error": f"Unsupported video format. Supported: {', '.join(SUPPORTED_VIDEO_FORMATS)}"}), 400

        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_extension)
        temp_file.close()

        try:
            video_file.save(temp_file.name)
            result = translate_video(
                temp_file.name,
                source_language,
                target_language,
                model
            )

            return jsonify(result), 200

        except Exception as e:
            print(f"Translation error: {str(e)}")
            return jsonify({"error": str(e)}), 500

        finally:
            try:
                if os.path.exists(temp_file.name):
                    os.remove(temp_file.name)
            except Exception:
                pass

    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        return jsonify({"error": "Internal server error"}), 500


@video_bp.route("/video-translate", methods=["OPTIONS"])
def video_translate_options():
    return "", 204
