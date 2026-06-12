from flask import Blueprint, request, jsonify
from services.gemini_service import translate_text

text_bp = Blueprint("text_bp", __name__)

@text_bp.route("/translate-text", methods=["POST"])
def translate():

    data = request.get_json()

    text = data.get("text")
    source_language = data.get("source_language")
    target_language = data.get("target_language")

    if not text or not target_language:
        return jsonify({"error": "Missing fields"}), 400

    result = translate_text(
        text,
        target_language
    )

    return jsonify({
        "translated_text": result
    })