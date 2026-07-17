from flask import Flask
from flask_cors import CORS
from flask_sock import Sock

from routes.text import text_bp
from routes.speech import speech_bp
from routes.video import video_bp, register_websocket_routes

app = Flask(__name__)
CORS(app)

# Initialize WebSocket support
sock = Sock(app)

# Register WebSocket routes
register_websocket_routes(sock)

# register routes
app.register_blueprint(text_bp)
app.register_blueprint(speech_bp)
app.register_blueprint(video_bp)


@app.route("/")
def home():
    return {"message": "Translation API running 🚀"}


if __name__ == "__main__":
    app.run(debug=True, port=5000)