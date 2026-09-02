import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS()
@staticInterop
class _SpeechRecognitionErrorEvent {}

extension _SpeechRecognitionErrorEventExtension
    on _SpeechRecognitionErrorEvent {
  external String? get error;
}

class WebSpeechRecognizer {
  static const int _maxNoSpeechRetries = 4;
  static const Duration _retryDelay = Duration(milliseconds: 350);

  html.SpeechRecognition? _recognition;
  final List<StreamSubscription<html.Event>> _subscriptions = [];
  void Function(String status)? _onStatus;
  void Function(String error)? _onError;
  void Function(String words, double confidence, bool isFinal)? _onResult;
  String _lastWords = '';
  double _lastConfidence = 0;
  bool _sentFinalResult = false;
  bool _stopping = false;
  String? _lastErrorCode;
  String? _currentLocaleId;
  int _noSpeechRetries = 0;

  bool get supported => html.SpeechRecognition.supported;

  bool initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
    required void Function(String words, double confidence, bool isFinal)
        onResult,
  }) {
    if (!supported) return false;

    _clearSubscriptions();
    _recognition = html.SpeechRecognition();
    _onStatus = onStatus;
    _onError = onError;
    _onResult = onResult;

    _subscriptions.add(_recognition!.onStart.listen((event) {
      html.window.console.log('Web Speech: onStart fired');
      _onStatus?.call('listening');
    }));
    _subscriptions.add(_recognition!.onSpeechStart.listen((event) {
      html.window.console.log('Web Speech: onSpeechStart fired');
      _onStatus?.call('listening');
    }));
    _subscriptions.add(_recognition!.onResult.listen(_handleResult));
    _subscriptions.add(_recognition!.onError.listen(_handleError));
    _subscriptions.add(_recognition!.onNoMatch.listen((event) {
      html.window.console.log('Web Speech: onNoMatch fired');
      _lastErrorCode = 'no-speech';
    }));
    _subscriptions.add(_recognition!.onEnd.listen((event) {
      html.window.console.log('Web Speech: onEnd fired, lastErrorCode=$_lastErrorCode');
      if (_lastWords.isNotEmpty && !_sentFinalResult) {
        _onResult?.call(_lastWords, _lastConfidence, true);
        _sentFinalResult = true;
      }

      if (_stopping) {
        _onStatus?.call('notListening');
        _onStatus?.call('done');
        return;
      }

      if (_shouldRetryAfterNoSpeech()) {
        _restartAfterNoSpeech();
        return;
      }

      if (_lastErrorCode == 'no-speech') {
        _onError?.call(
          'No speech detected. Check your microphone input, then speak clearly after tapping the mic.',
        );
        _restartAfterNoSpeech();
        return;
      }

      if (_lastErrorCode == null) {
        html.window.console.log('Web Speech: recognition ended naturally, restarting');
        _restartRecognition();
        return;
      }

      _onStatus?.call('notListening');
      _onStatus?.call('done');
    }));

    return true;
  }

  Future<void> listen({required String localeId}) async {
    final recognition = _recognition;
    if (recognition == null) return;

    html.window.console.log('Web Speech: listen() called');

    _lastWords = '';
    _lastConfidence = 0;
    _sentFinalResult = false;
    _stopping = false;
    _lastErrorCode = null;
    _noSpeechRetries = 0;
    _currentLocaleId = localeId;
    recognition.lang = localeId.replaceAll('_', '-');
    recognition.interimResults = true;
    recognition.continuous = true;
    recognition.maxAlternatives = 1;

    html.window.console.log('Web Speech: Calling recognition.start()');
    try {
      recognition.start();
      html.window.console.log('Web Speech: recognition.start() called successfully');
    } catch (e) {
      html.window.console.log('Web Speech: Error calling start(): $e');
      _onError?.call('Failed to start speech recognition: $e');
      _onStatus?.call('notListening');
      _onStatus?.call('done');
    }
  }

  Future<void> stop() async {
    _stopping = true;
    _recognition?.stop();
  }

  void _handleResult(html.SpeechRecognitionEvent event) {
    final dynamic results = event.results;
    if (results == null) {
      return;
    }

    final int resultsLength = _getJsLength(results);
    if (resultsLength == 0) {
      return;
    }

    final int resultIndex = event.resultIndex ?? (resultsLength - 1);
    final dynamic recognitionResult = _getJsItem(results, resultIndex);
    if (recognitionResult == null) {
      return;
    }

    final int recognitionResultLength = _getJsLength(recognitionResult);
    if (recognitionResultLength == 0) {
      return;
    }

    final dynamic alternative = _getJsItem(recognitionResult, 0);
    if (alternative == null) {
      return;
    }

    final String? transcript = alternative.transcript;
    if (transcript == null || transcript.trim().isEmpty) return;

    final confidence = alternative.confidence?.toDouble() ?? 0;
    final isFinal = recognitionResult.isFinal ?? false;

    html.window.console
        .log('Web Speech Result: "$transcript" (confidence: $confidence, isFinal: $isFinal)');

    _lastWords = transcript.trim();
    _lastConfidence = confidence;
    _sentFinalResult = isFinal;
    _onResult?.call(_lastWords, _lastConfidence, isFinal);
  }

  void _handleError(html.Event event) {
    final error = _getErrorCode(event);
    _lastErrorCode = error;
    html.window.console.log('Web Speech Error: $error');

    if (error == null || error.isEmpty) {
      _onError?.call('Speech recognition stopped. Please try again.');
      return;
    }

    switch (error) {
      case 'not-allowed':
      case 'service-not-allowed':
        _onError?.call('Microphone permission denied. Click lock icon and allow microphone.');
        break;
      case 'no-speech':
        html.window.console.log('No speech detected during recognition');
        break;
      case 'audio-capture':
        _onError?.call(
            'No microphone was found. Please connect or enable a microphone.');
        break;
      case 'network':
        _onError?.call('Speech recognition network error');
        break;
      case 'aborted':
        _onError?.call('Speech recognition was stopped. Please try again.');
        break;
      case 'language-not-supported':
        _onError?.call('Speech recognition does not support this language.');
        break;
      default:
        _onError?.call('Speech recognition error: $error');
    }
  }

  String? _getErrorCode(html.Event event) {
    if (event is html.SpeechRecognitionError) {
      return event.error;
    }

    final jsEvent = JSObject.fromInteropObject(event);
    if (jsEvent.has('error')) {
      return (jsEvent as _SpeechRecognitionErrorEvent).error;
    }

    return event.type == 'error' ? null : event.type;
  }

  int _getJsLength(dynamic jsObject) {
    try {
      return jsObject.length as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  dynamic _getJsItem(dynamic jsObject, int index) {
    try {
      return jsObject[index];
    } catch (_) {}
    try {
      return jsObject.item(index);
    } catch (_) {}
    return null;
  }

  bool _shouldRetryAfterNoSpeech() {
    return !_stopping &&
        _lastWords.isEmpty &&
        _lastErrorCode == 'no-speech' &&
        _noSpeechRetries < _maxNoSpeechRetries;
  }

  void _restartAfterNoSpeech() {
    _noSpeechRetries += 1;
    final localeId = _currentLocaleId;
    final recognition = _recognition;
    if (localeId == null || recognition == null) return;

    Future.delayed(_retryDelay, () {
      if (_stopping || _recognition != recognition) return;

      _lastErrorCode = null;
      recognition.lang = localeId.replaceAll('_', '-');
      recognition.interimResults = true;
      recognition.continuous = true;
      recognition.maxAlternatives = 1;

      try {
        recognition.start();
        _onStatus?.call('listening');
      } catch (_) {
        _onStatus?.call('notListening');
        _onStatus?.call('done');
      }
    });
  }

  void _restartRecognition() {
    final localeId = _currentLocaleId;
    final recognition = _recognition;
    if (localeId == null || recognition == null || _stopping) return;

    _lastErrorCode = null;
    recognition.lang = localeId.replaceAll('_', '-');
    recognition.interimResults = true;
    recognition.continuous = true;
    recognition.maxAlternatives = 1;

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_stopping || _recognition != recognition) return;
      try {
        recognition.start();
        _onStatus?.call('listening');
      } catch (e) {
        html.window.console.log('Web Speech: restartRecognition error: $e');
        _onStatus?.call('notListening');
        _onStatus?.call('done');
      }
    });
  }

  void _clearSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _stopping = true;
  }
}
