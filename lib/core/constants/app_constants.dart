class AppConstants {
  static const String baseUrl = "http://127.0.0.1:5000";

  // Text Translation
  static const String textTranslate = "$baseUrl/translate-text";

  // Speech Translation
  static const String speechTranslate = "$baseUrl/speech-translate";

  // Video Translation (handles video/audio uploads)
  static const String videoTranslate = "$baseUrl/video-translate";

  static const String videoTranslateStream = "$baseUrl/video-translate-stream";

  // Video Summary (independent from translation)
  static const String videoSummarize = "$baseUrl/video-summarize";
}
