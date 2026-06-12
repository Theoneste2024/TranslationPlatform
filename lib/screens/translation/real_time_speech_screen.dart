import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/constants/app_constants.dart';
import '../../core/constants/languages.dart';

// =============================================================================
// WIDGET
// =============================================================================

class RealTimeSpeechScreen extends StatefulWidget {
  const RealTimeSpeechScreen({Key? key}) : super(key: key);

  @override
  State<RealTimeSpeechScreen> createState() => _RealTimeSpeechScreenState();
}

// =============================================================================
// STATE
// =============================================================================

class _RealTimeSpeechScreenState extends State<RealTimeSpeechScreen>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Services
  // ---------------------------------------------------------------------------

  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ---------------------------------------------------------------------------
  // UI States
  // ---------------------------------------------------------------------------

  bool _isListening = false;
  bool _isTranslating = false;
  bool _isPlayingAudio = false;
  bool _isUploading = false;
  bool _keepListening = false;

  // ---------------------------------------------------------------------------
  // Text & Language
  // ---------------------------------------------------------------------------

  String _recognizedText = '';
  String _translatedText = '';
  String _sourceLanguage = 'en';
  String _targetLanguage = 'fr';
  double _confidence = 0.0;
  String _finalTranscript = '';
  Timer? _listenRestartTimer;

  // ---------------------------------------------------------------------------
  // Output Options
  // ---------------------------------------------------------------------------

  bool _outputText = true;
  bool _outputAudio = true;

  // ---------------------------------------------------------------------------
  // Animation
  // ---------------------------------------------------------------------------

  late AnimationController _animationController;

  // ---------------------------------------------------------------------------
  // Audio File Upload
  // ---------------------------------------------------------------------------

  PlatformFile? _selectedAudioFile;
  String? _fileName;

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  final List<Map<String, dynamic>> _conversationHistory = [];

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _printSupportedLocales();
    _initTTS();

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _listenRestartTimer?.cancel();
    _keepListening = false;
    _speech.stop();
    _flutterTts.stop();
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // INIT HELPERS
  // ==========================================================================

  Future<void> _printSupportedLocales() async {
    final locales = await _speech.locales();
    for (final locale in locales) {
      debugPrint('${locale.localeId} - ${locale.name}');
    }
  }

  Future<void> _initTTS() async {
    await _flutterTts.setLanguage(_getTtsLanguage(_targetLanguage));
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      setState(() => _isPlayingAudio = false);
    });
  }

  // ==========================================================================
  // LOCALE / LANGUAGE HELPERS
  // ==========================================================================

  String _getTtsLanguage(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'en-US';
      case 'fr':
        return 'fr-FR';
      case 'rw':
        return 'rw-RW';
      case 'sw':
        return 'sw-KE';
      case 'ar':
        return 'ar-SA';
      case 'es':
        return 'es-ES';
      case 'de':
        return 'de-DE';
      default:
        return 'en-US';
    }
  }

  String _getLocaleFromLanguage(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'en_US';
      case 'fr':
        return 'fr_FR';
      case 'rw':
        return 'rw_RW';
      case 'sw':
        return 'sw_KE';
      case 'ar':
        return 'ar_SA';
      case 'es':
        return 'es_ES';
      case 'de':
        return 'de_DE';
      default:
        return 'en_US';
    }
  }

  String _getLanguageName(String code) {
    for (final lang in Languages.africanLanguages) {
      if (lang.code == code) return lang.nativeName;
    }
    for (final lang in Languages.globalLanguages) {
      if (lang.code == code) return lang.name;
    }
    return code;
  }

  // ==========================================================================
  // SPEECH RECOGNITION
  // ==========================================================================

  Future<void> _startListening() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (_keepListening) {
            _restartListening();
          } else {
            setState(() => _isListening = false);
            _animationController.stop();
          }
        }
      },
      onError: (error) {
        debugPrint('Speech error: $error');
        if (_keepListening && !error.permanent) {
          _restartListening();
          return;
        }

        _keepListening = false;
        setState(() => _isListening = false);
        _animationController.stop();
        _showSnackBar('Speech recognition error', Colors.red);
      },
    );

    if (!available) {
      _showSnackBar('Speech recognition not available', Colors.red);
      return;
    }

    setState(() {
      _keepListening = true;
      _isListening = true;
      _recognizedText = '';
      _translatedText = '';
      _finalTranscript = '';
    });

    _animationController.repeat(reverse: true);
    _showSnackBar(
        '💡 For best results, speak in a quiet environment', Colors.blue);

    await _listen();
  }

  Future<void> _listen() async {
    await _speech.listen(
      onResult: (result) async {
        final currentWords = result.recognizedWords.trim();
        final fullTranscript = [
          _finalTranscript,
          if (!result.finalResult) currentWords,
        ].where((text) => text.trim().isNotEmpty).join(' ');

        setState(() {
          _recognizedText = result.finalResult
              ? (_finalTranscript.isEmpty ? currentWords : _finalTranscript)
              : fullTranscript;
          _confidence = result.confidence;
        });

        if (result.finalResult && currentWords.isNotEmpty) {
          if (!_finalTranscript.endsWith(currentWords)) {
            _finalTranscript = [
              _finalTranscript,
              currentWords,
            ].where((text) => text.trim().isNotEmpty).join(' ');
          }

          setState(() => _recognizedText = _finalTranscript);
          await _translateText(_finalTranscript);
        }
      },
      localeId: _getLocaleFromLanguage(_sourceLanguage),
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
    );
  }

  void _restartListening() {
    _listenRestartTimer?.cancel();
    _listenRestartTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!_keepListening || !mounted) return;
      if (_speech.isListening) return;

      await _listen();

      if (mounted) {
        setState(() => _isListening = true);
        _animationController.repeat(reverse: true);
      }
    });
  }

  Future<void> _stopListening() async {
    _keepListening = false;
    _listenRestartTimer?.cancel();
    await _speech.stop();
    _animationController.stop();
    setState(() => _isListening = false);
  }

  // ==========================================================================
  // AUDIO FILE UPLOAD
  // ==========================================================================

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
      );

      if (result == null) return;

      setState(() {
        _selectedAudioFile = result.files.single;
        _fileName = result.files.single.name;
        _isUploading = true;
      });

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConstants.speechTranslate),
      );

      request.fields['source_language'] = _sourceLanguage;
      request.fields['target_language'] = _targetLanguage;
      request.files.add(http.MultipartFile.fromBytes('audio', result.files.single.bytes!, filename: result.files.single.name,),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _recognizedText = data['original_text'];
          _translatedText = data['translated_text'];
          _isUploading = false;
        });

        await _handleOutput();
        _showSnackBar('Translation completed!', Colors.green);
      } else {
        throw Exception(data['error']);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  // ==========================================================================
  // TRANSLATION
  // ==========================================================================

  Future<void> _translateText(String text) async {
    if (text.isEmpty) return;

    setState(() => _isTranslating = true);

    try {
      final response = await http.post(
        Uri.parse(AppConstants.speechTranslate),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'source_language': _sourceLanguage,
          'target_language': _targetLanguage,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _recognizedText = data['original_text'] ?? text;
          _translatedText = data['translated_text'] ?? '';
        });

        _conversationHistory.add({
          'source': _recognizedText,
          'translated': _translatedText,
          'sourceLang': _sourceLanguage,
          'targetLang': _targetLanguage,
          'time': DateTime.now(),
          'type': 'live',
        });

        await _handleOutput();
      } else {
        throw Exception(data['error'] ?? 'Unknown server error');
      }
    } catch (e) {
      _showSnackBar('Translation failed: $e', Colors.red);
    }

    setState(() => _isTranslating = false);
  }

  // ==========================================================================
  // OUTPUT HANDLING
  // ==========================================================================

  Future<void> _handleOutput() async {
    if (_outputAudio && _translatedText.isNotEmpty) {
      setState(() => _isPlayingAudio = true);
      await _flutterTts.speak(_translatedText);
    }
  }

  void _toggleAudioPlayback() {
    if (_isPlayingAudio) {
      _flutterTts.stop();
      setState(() => _isPlayingAudio = false);
    } else if (_translatedText.isNotEmpty) {
      setState(() => _isPlayingAudio = true);
      _flutterTts.speak(_translatedText);
    }
  }

  // ==========================================================================
  // LANGUAGE SWAP / CLEAR
  // ==========================================================================

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
    });
    _initTTS();
  }

  void _clearAll() {
    setState(() {
      _recognizedText = '';
      _translatedText = '';
      _selectedAudioFile = null;
      _fileName = null;
      _confidence = 0.0;
    });
    _stopListening();
  }

  // ==========================================================================
  // UI HELPERS
  // ==========================================================================

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

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLanguageCard(),
            const SizedBox(height: 16),
            if (_isUploading) _buildUploadingIndicator(),
            if (_fileName != null && !_isUploading) _buildFileNameBadge(),
            if (_selectedAudioFile == null) _buildRecordButton(),
            const SizedBox(height: 24),
            if (_recognizedText.isNotEmpty) _buildRecognizedCard(),
            const SizedBox(height: 12),
            if (_translatedText.isNotEmpty) _buildTranslationCard(),
            const SizedBox(height: 24),
            if (_conversationHistory.isNotEmpty) _buildHistoryCard(),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // APP BAR
  // ==========================================================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Speech Translation'),
      elevation: 0,
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _clearAll,
          tooltip: 'Clear All',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic, size: 16),
                      SizedBox(width: 4),
                      Text('Record Voice'),
                    ],
                  ),
                  selected: !_isUploading && !_isListening,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedAudioFile = null;
                        _fileName = null;
                      });
                    }
                  },
                  selectedColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, size: 16),
                      SizedBox(width: 4),
                      Text('Upload Audio'),
                    ],
                  ),
                  selected: _selectedAudioFile != null,
                  onSelected: (selected) {
                    if (selected) _pickAudioFile();
                  },
                  selectedColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // LANGUAGE CARD
  // ==========================================================================

  Widget _buildLanguageCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildLanguageDropdown(
                    value: _sourceLanguage,
                    onChanged: (value) =>
                        setState(() => _sourceLanguage = value!),
                    label: 'From',
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
                      setState(() => _targetLanguage = value!);
                      _initTTS();
                    },
                    label: 'To',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildOutputOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputOptions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Output Options:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: const Text('📝 Text'),
                  selected: _outputText,
                  onSelected: (value) => setState(() => _outputText = value),
                  backgroundColor: Colors.grey.shade200,
                  selectedColor: Colors.blue.shade100,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('🔊 Audio'),
                  selected: _outputAudio,
                  onSelected: (value) => setState(() => _outputAudio = value),
                  backgroundColor: Colors.grey.shade200,
                  selectedColor: Colors.blue.shade100,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('📝🔊 Both'),
                  selected: _outputText && _outputAudio,
                  onSelected: (value) => setState(() {
                    _outputText = value;
                    _outputAudio = value;
                  }),
                  backgroundColor: Colors.grey.shade200,
                  selectedColor: Colors.green.shade100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // UPLOAD STATUS WIDGETS
  // ==========================================================================

  Widget _buildUploadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Processing Audio...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _fileName ?? 'Converting speech to text',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileNameBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.audio_file, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _fileName!,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _selectedAudioFile = null;
              _fileName = null;
            }),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // RECORD BUTTON
  // ==========================================================================

  Widget _buildRecordButton() {
    return Center(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final pulse =
                  _isListening ? _animationController.value * 50 : 0.0;
              return GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: Container(
                  width: 200 + pulse,
                  height: 200 + pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? Colors.red.withOpacity(
                            0.3 - (_animationController.value * 0.1))
                        : Colors.blue.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.red : Colors.blue,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : Colors.blue)
                                .withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          if (_isListening) ...[
            const Text(
              'Listening...',
              style: TextStyle(
                fontSize: 20,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(_confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.grey),
            ),
          ] else if (_recognizedText.isEmpty) ...[
            const Text(
              'Tap to start recording',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // RESULT CARDS
  // ==========================================================================

  Widget _buildRecognizedCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recognized Speech',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        _getLanguageName(_sourceLanguage),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (_isTranslating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _recognizedText,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.translate, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Translation',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        _getLanguageName(_targetLanguage),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (_outputAudio)
                  IconButton(
                    icon: Icon(
                      _isPlayingAudio ? Icons.stop : Icons.volume_up,
                      color: Colors.blue,
                    ),
                    onPressed: _toggleAudioPlayback,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _translatedText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  color: Colors.blue,
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: _translatedText));
                    _showSnackBar('Copied to clipboard!', Colors.green);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  color: Colors.blue,
                  onPressed: () =>
                      _showSnackBar('Saved to favorites!', Colors.pink),
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  color: Colors.blue,
                  onPressed: () => _showSnackBar(
                      'Share feature coming soon!', Colors.orange),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HISTORY CARD
  // ==========================================================================

  Widget _buildHistoryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Translations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Icon(Icons.arrow_forward,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          _getLanguageName(item['targetLang']),
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
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
    );
  }

  // ==========================================================================
  // LANGUAGE DROPDOWN
  // ==========================================================================

  Widget _buildLanguageDropdown({
    required String value,
    required Function(String?) onChanged,
    required String label,
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
          items: [
            ...Languages.africanLanguages.map((lang) {
              return DropdownMenuItem(
                value: lang.code,
                child: Row(
                  children: [
                    Text(lang.flagEmoji),
                    const SizedBox(width: 8),
                    Text(lang.nativeName),
                  ],
                ),
              );
            }),
            ...Languages.globalLanguages.map((lang) {
              return DropdownMenuItem(
                value: lang.code,
                child: Row(
                  children: [
                    Text(lang.flagEmoji),
                    const SizedBox(width: 8),
                    Text(lang.nativeName),
                  ],
                ),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
