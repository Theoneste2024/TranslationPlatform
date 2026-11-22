import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations_extensions.dart';
import '../../core/constants/languages.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/app_header.dart';
import 'web_speech_recognizer_stub.dart'
    if (dart.library.html) 'web_speech_recognizer_web.dart';

class RealTimeSpeechScreen extends StatefulWidget {
  const RealTimeSpeechScreen({super.key});

  @override
  State<RealTimeSpeechScreen> createState() => _RealTimeSpeechScreenState();
}

class _RealTimeSpeechScreenState extends State<RealTimeSpeechScreen>
    with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late WebSpeechRecognizer _webSpeechRecognizer;

  late final AnimationController _heartbeatController;
  late final AnimationController _waveController;
  Timer? _recordingTimer;
  DateTime? _recordingStartedAt;
  int _recordingElapsedSeconds = 0;
  bool _reduceMotion = false;

  // UI States
  bool _isListening = false;
  bool _isTranslating = false;
  bool _isUploading = false;

  // Text Content
  String _translatedText = '';
  String _sourceLanguage = 'en';
  String _targetLanguage = 'fr';
  String? _translationError;

  // Audio File Upload
  PlatformFile? _selectedAudioFile;

  // History
  final List<Map<String, dynamic>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _webSpeechRecognizer = WebSpeechRecognizer();
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion != _reduceMotion) {
      _reduceMotion = reduceMotion;
      _syncRecordingAnimations();
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _heartbeatController.dispose();
    _waveController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _setListening(bool listening) {
    if (!mounted) return;
    setState(() => _isListening = listening);
    if (listening) {
      _startRecordingVisuals();
    } else {
      _stopRecordingVisuals();
    }
  }

  void _startRecordingVisuals() {
    _recordingStartedAt = DateTime.now();
    _recordingElapsedSeconds = 0;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isListening) return;
      setState(() {
        _recordingElapsedSeconds =
            DateTime.now().difference(_recordingStartedAt!).inSeconds;
      });
    });
    _syncRecordingAnimations();
  }

  void _stopRecordingVisuals() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingStartedAt = null;
    _recordingElapsedSeconds = 0;
    _heartbeatController.stop();
    _waveController.stop();
    _heartbeatController.reset();
    _waveController.reset();
  }

  void _syncRecordingAnimations() {
    if (!_isListening || _reduceMotion) {
      _heartbeatController.stop();
      _waveController.stop();
      return;
    }
    if (!_heartbeatController.isAnimating) {
      _heartbeatController.repeat();
    }
    if (!_waveController.isAnimating) {
      _waveController.repeat();
    }
  }

  // ============ LIVE RECORDING ============
  Future<void> _startListening() async {
    if (_isListening || _isTranslating) return;

    if (kIsWeb) {
      await _startWebListening();
      return;
    }

    // Native platforms still need explicit microphone permission.
    PermissionStatus status = await Permission.microphone.request();

    if (!status.isGranted) {
      _showSnackBar(context.l10n.microphonePermissionRequired, Colors.red);
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');

        if (status == 'done' || status == 'notListening') {
          if (!mounted) return;
          _setListening(false);
        }
      },
      onError: (error) {
        debugPrint('Speech error: $error');
        if (!mounted) return;
        _setListening(false);
        String errorMsg = error.toString();
        // Handle both error objects and generic events (web compatibility)
        if (errorMsg.contains('network') || errorMsg.contains('no-speech')) {
          _showSnackBar(context.l10n.noSpeechDetected, Colors.orange);
        } else if (errorMsg.contains('not-allowed') ||
            errorMsg.contains('permission')) {
          _showSnackBar(context.l10n.microphonePermissionDenied, Colors.red);
        } else {
          _showSnackBar(context.l10n.speechRecognitionError, Colors.red);
        }
      },
    );

    if (!available) {
      _showSnackBar(
        context.l10n.speechRecognitionUnavailable,
        Colors.red,
      );
      return;
    }

    _setListening(true);

    try {
      await _speech.listen(
        onResult: (result) async {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            await _translateText(result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: _getLocaleFromLanguage(_sourceLanguage),
          partialResults: true,
          cancelOnError: true,
          localeId: _getLocaleFromLanguage(_sourceLanguage),
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
        onSoundLevelChange: (level) {
          debugPrint('Sound level: $level');
        },
      );
    } catch (e) {
      debugPrint('Error during speech listen: $e');
      _setListening(false);
      _showSnackBar(
          'Could not start listening. Please allow microphone access and try again.',
          Colors.red);
    }
  }

  Future<void> _startWebListening() async {
    final available = _webSpeechRecognizer.initialize(
      onStatus: (status) {
        debugPrint('Web speech status: $status');

        if (status == 'done' || status == 'notListening') {
          if (!mounted) return;
          _setListening(false);
        }
      },
      onError: (message) {
        debugPrint('Web speech error: $message');
        if (!mounted) return;
        _setListening(false);

        // Always show the error message to the user
        final errorMsg = message.toLowerCase();
        if (errorMsg.contains('permission')) {
          _showSnackBar(
            context.l10n.browserMicrophonePermissionRequired,
            Colors.red,
          );
        } else if (errorMsg.contains('no')) {
          _showSnackBar(
            context.l10n.noSpeechDetected,
            Colors.orange,
          );
        } else if (errorMsg.contains('microphone detected') ||
            errorMsg.contains('audio input')) {
          _showSnackBar(
            context.l10n.noMicrophoneDetected,
            Colors.red,
          );
        } else {
          _showSnackBar(message, Colors.red);
        }
      },
      onResult: (words, _, isFinal) async {
        if (!mounted) return;

        if (isFinal && words.isNotEmpty) {
          await _translateText(words);
        }
      },
    );

    if (!available) {
      _showSnackBar(
        context.l10n.speechRecognitionUnavailable,
        Colors.red,
      );
      return;
    }

    _setListening(true);

    _showSnackBar(
      context.l10n.microphoneReady,
      Colors.green,
    );

    try {
      await _webSpeechRecognizer.listen(
        localeId: _getLocaleFromLanguage(_sourceLanguage),
      );
    } catch (e) {
      debugPrint('Error during web speech listen: $e');
      if (!mounted) return;
      _setListening(false);
      _showSnackBar(
        context.l10n.couldNotStartListeningWithError(e.toString()),
        Colors.red,
      );
    }
  }

// ============ STOP LISTENING ============
  Future<void> _stopListening() async {
    if (kIsWeb) {
      await _webSpeechRecognizer.stop();
    } else {
      await _speech.stop();
    }
    _setListening(false);
  }

  String _formatRecordingTime() {
    final seconds = (_recordingElapsedSeconds % 60).toString().padLeft(2, '0');
    return '00:$seconds';
  }

  double _heartbeatScale(double progress) {
    if (progress <= 0.25) {
      return 1.0 + 0.14 * (progress / 0.25);
    }
    if (progress <= 0.50) {
      return 1.14 - 0.14 * ((progress - 0.25) / 0.25);
    }
    if (progress <= 0.72) {
      return 1.0 + 0.09 * ((progress - 0.50) / 0.22);
    }
    if (progress <= 1.0) {
      return 1.09 - 0.09 * ((progress - 0.72) / 0.28);
    }
    return 1.0;
  }

  Widget _buildIdleButton() {
    return Container(
      width: 190,
      height: 190,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFC6E6F8),
      ),
      child: Center(
        child: Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E96E8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E96E8).withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.mic,
            size: 40,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildListeningButton() {
    return SizedBox(
      width: 340,
      height: 340,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _heartbeatController,
          _waveController,
        ]),
        builder: (context, _) {
          final heartbeatScale =
              _reduceMotion ? 1.0 : _heartbeatScale(_heartbeatController.value);
          final haloProgress =
              (_heartbeatController.value + (100 / 1200)) % 1.0;
          final haloScale =
              _reduceMotion ? 1.0 : _heartbeatScale(haloProgress);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(340, 340),
                painter: _RecordingWavePainter(
                  progress: _reduceMotion ? 0.0 : _waveController.value,
                  reducedMotion: _reduceMotion,
                ),
              ),
              Transform.scale(
                scale: haloScale,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFC6E6F8),
                  ),
                ),
              ),
              Transform.scale(
                scale: heartbeatScale,
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E96E8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E96E8)
                            .withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============ UPLOAD AUDIO FILE ============
  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        withData: true,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
      );

      if (result != null) {
        setState(() {
          _selectedAudioFile = result.files.single;
          _isUploading = true;
          _translationError = null;
        });

        _showSnackBar(
          '✅ Audio selected: ${result.files.single.name}',
          Colors.green,
        );

        await _uploadAudioAndTranslate();
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _translationError = 'Error picking audio: $e';
      });
      _showSnackBar('Error picking audio: $e', Colors.red);
    }
  }

  Future<void> _uploadAudioAndTranslate() async {
    if (_selectedAudioFile == null) return;

    try {
      final audioBytes = _selectedAudioFile!.bytes;
      if (audioBytes == null) {
        throw Exception(context.l10n.selectedAudioCouldNotBeRead);
      }

      final response =
          await context.read<ApiClient>().dio.post<Map<String, dynamic>>(
                'speech_translate/',
                data: FormData.fromMap({
                  'source_language': _getLanguageName(_sourceLanguage),
                  'target_language': _getLanguageName(_targetLanguage),
                  'audio': MultipartFile.fromBytes(
                    audioBytes,
                    filename: _selectedAudioFile!.name,
                  ),
                }),
              );

      final data = response.data;
      if (data == null) {
        throw Exception(context.l10n.emptySpeechTranslationResponse);
      }
      setState(() {
        _translatedText = data['translated_text']?.toString() ?? '';
        _isUploading = false;
      });

      _showSnackBar(
        context.l10n.translationCompleted,
        Colors.green,
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
        _translationError = 'Translation failed: $e';
      });

      _showSnackBar(
        context.l10n.translationFailed(e.toString()),
        Colors.red,
      );
    }
  }

  // ============ TRANSLATE TEXT ============
  Future<void> _translateText(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translationError = null;
    });

    try {
      final response =
          await context.read<ApiClient>().dio.post<Map<String, dynamic>>(
        'translate_text/',
        data: {
          'text': text,
          'source_language': _getLanguageName(_sourceLanguage),
          'target_language': _getLanguageName(_targetLanguage),
        },
      );

      final data = response.data;
      if (data != null) {
        final translated = data['translated_text']?.toString() ?? '';

        setState(() {
          _translatedText = translated;
          _isTranslating = false;
        });

        _conversationHistory.add({
          'source': text,
          'translated': _translatedText,
          'sourceLang': _sourceLanguage,
          'targetLang': _targetLanguage,
        });
      } else {
        throw Exception(context.l10n.translationFailed(''));
      }
    } catch (e) {
      setState(() {
        _isTranslating = false;
        _translationError = 'Translation failed: $e';
      });

      _showSnackBar(
        context.l10n.translationFailed(e.toString()),
        Colors.red,
      );
    }
  }

  // ============ LOCALE HELPER ============
  String _getLocaleFromLanguage(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'en_US';
      case 'fr':
        return 'fr_FR';
      case 'rw':
        return 'rw_RW';
      case 'sw':
        return 'sw_TZ';
      case 'zh':
        return 'zh_CN';
      default:
        return 'en_US';
    }
  }

  // ============ SWAP LANGUAGES ============
  void _swapLanguages() {
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
    });
  }

  // ============ UI HELPERS ============
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.speechTranslation),
          elevation: 0,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          leading: const AppMenuButton(),
          automaticallyImplyLeading: false,
          actions: const [AppBrandControls()],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mic, size: 16),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Record Voice',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      selected: _selectedAudioFile == null && !_isListening,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedAudioFile = null);
                        }
                      },
                      selectedColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      labelStyle: const TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file, size: 16),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Upload Audio',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      selected: _selectedAudioFile != null,
                      onSelected: (selected) {
                        if (selected) _pickAudioFile();
                      },
                      selectedColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      labelStyle: const TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildLanguageDropdown(
                      value: _sourceLanguage,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sourceLanguage = value);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: _swapLanguages,
                    color: Colors.blue,
                  ),
                  Expanded(
                    child: _buildLanguageDropdown(
                      value: _targetLanguage,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _targetLanguage = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Record Button / Visualization
              Center(
                child: Column(
                  children: [
                    if (_isListening)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Listening\u2026 ${_formatRecordingTime()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Speak',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: _isListening
                          ? _buildListeningButton()
                          : _buildIdleButton(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isListening ? 'Tap to stop' : 'Tap and speak',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Translation',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 190),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF1B6B3A),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFFE8F5EE),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _isTranslating || _isUploading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1B6B3A),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Translating...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF17382A),
                                ),
                              ),
                            ],
                          )
                        : _translationError != null
                            ? Text(
                                _translationError!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                  height: 1.35,
                                ),
                              )
                            : Text(
                                _translatedText.isEmpty
                                    ? 'Translation will appear here'
                                    : _translatedText,
                                style: const TextStyle(
                                  fontSize: 22,
                                  height: 1.35,
                                  color: Color(0xFF17382A),
                                ),
                              ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // History Section
              if (_conversationHistory.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.recentTranslations,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._conversationHistory.reversed.take(3).map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _getLanguageName(item['sourceLang']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getLanguageName(item['targetLang']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['source'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  item['translated'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ LANGUAGE DROPDOWN ============
  Widget _buildLanguageDropdown({
    required String value,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          items: Languages.translationLanguages.map((lang) {
            return DropdownMenuItem(
              value: lang.code,
              child: Text(
                '${lang.flagEmoji} ${lang.name}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    for (final lang in Languages.translationLanguages) {
      if (lang.code == code) return lang.name;
    }
    return code;
  }
}

class _RecordingWavePainter extends CustomPainter {
  const _RecordingWavePainter({
    required this.progress,
    required this.reducedMotion,
  });

  final double progress;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (reducedMotion) return;

    const baseDiameter = 128.0;
    const maxDiameter = baseDiameter * 2.6;
    final center = Offset(size.width / 2, size.height / 2);

    for (var ring = 0; ring < 3; ring++) {
      var ringProgress = progress - (ring * 0.333333);
      if (ringProgress < 0) ringProgress += 1.0;
      final diameter =
          baseDiameter + (maxDiameter - baseDiameter) * ringProgress;
      final opacity = 0.55 * (1.0 - ringProgress);
      final paint = Paint()
        ..color = const Color(0xFF1E96E8).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, diameter / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_RecordingWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.reducedMotion != reducedMotion;
  }
}
