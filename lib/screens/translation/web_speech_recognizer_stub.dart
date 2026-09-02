class WebSpeechRecognizer {
  bool get supported => false;

  bool initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
    required void Function(String words, double confidence, bool isFinal)
        onResult,
  }) {
    return false;
  }

  Future<void> listen({required String localeId}) async {}

  Future<void> stop() async {}
}
