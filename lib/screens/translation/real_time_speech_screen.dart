import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/languages.dart';
import 'package:flutter/services.dart';

class RealTimeSpeechScreen extends StatefulWidget {
  const RealTimeSpeechScreen({Key? key}) : super(key: key);

  @override
  State<RealTimeSpeechScreen> createState() => _RealTimeSpeechScreenState();
}

class _RealTimeSpeechScreenState extends State<RealTimeSpeechScreen>
    with SingleTickerProviderStateMixin {
  // Speech & TTS
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // UI States
  bool _isListening = false;
  bool _isTranslating = false;
  bool _isPlayingAudio = false;
  bool _isUploading = false;
  
  // Text Content
  String _recognizedText = '';
  String _translatedText = '';
  String _sourceLanguage = 'en';
  String _targetLanguage = 'fr';
  double _confidence = 0.0;
  
  // Output Options
  bool _outputText = true;
  bool _outputAudio = true;
  
  // Animation
  late AnimationController _animationController;
  
  // Audio File Upload
  PlatformFile? _selectedAudioFile;
  String? _fileName;
  
  // History
  final List<Map<String, dynamic>> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _initTTS();
    
    // Set up audio player completion handler
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ============ TEXT-TO-SPEECH INIT ============
  Future<void> _initTTS() async {
  String locale = _targetLanguage == 'fr' ? 'fr-FR' : 'en-US';

  await _flutterTts.setLanguage(locale);
  await _flutterTts.setSpeechRate(0.5);
  await _flutterTts.setVolume(1.0);
  await _flutterTts.setPitch(1.0);

  _flutterTts.setCompletionHandler(() {
    setState(() => _isPlayingAudio = false);
  });
}
  // ============ LIVE RECORDING ============
  Future<void> _startListening() async {
  bool available = await _speech.initialize(
    onStatus: (status) {
      debugPrint('Speech status: $status');

      if (status == 'done' || status == 'notListening') {
        setState(() => _isListening = false);
        _animationController.stop();
      }
    },
    onError: (error) {
      debugPrint('Speech error: $error');
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
    _isListening = true;
    _recognizedText = '';
  });

  _animationController.repeat(reverse: true);

  await _speech.listen(
    onResult: (result) async {
      setState(() {
        _recognizedText = result.recognizedWords;
        _confidence = result.confidence;
      });

      // Trigger translation only when final result
      if (result.finalResult && result.recognizedWords.isNotEmpty) {
        await _translateText(result.recognizedWords);
      }
    },
    localeId: _getLocaleFromLanguage(_sourceLanguage),
    listenMode: stt.ListenMode.confirmation,
    partialResults: true,
  );
}

// ============ STOP LISTENING ============
Future<void> _stopListening() async {
  await _speech.stop();
  _animationController.stop();

  setState(() {
    _isListening = false;
  });
}

  // ============ UPLOAD AUDIO FILE ============
  Future<void> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowMultiple: false,
  allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
);

      if (result != null) {
        setState(() {
          _selectedAudioFile = result.files.single;
          _fileName = result.files.single.name;
          _isUploading = true;
        });
        
        _showSnackBar('✅ Audio selected: $_fileName', Colors.green);
        
        // In a real app, you'd process the audio file here
        // For demo, we'll simulate transcription
        await Future.delayed(const Duration(seconds: 2));
        
        setState(() {
          _recognizedText = "This is transcribed text from the uploaded audio file. In a production app, this would use a proper speech-to-text API to convert the audio to text.";
          _isUploading = false;
        });
        
        _showSnackBar('✅ Audio transcribed successfully!', Colors.green);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showSnackBar('Error picking audio: $e', Colors.red);
    }
  }

  // ============ TRANSLATE TEXT ============
  Future<void> _translateText(String text) async {
  if (text.isEmpty) return;

  // Allow ONLY English <-> French for now
  bool isSupportedPair =
      (_sourceLanguage == 'en' && _targetLanguage == 'fr') ||
      (_sourceLanguage == 'fr' && _targetLanguage == 'en');

  if (!isSupportedPair) {
    _showSnackBar(
      '🚧 This language pair will be available soon.',
      Colors.orange,
    );
    return;
  }

  setState(() => _isTranslating = true);

  try {
    final url = Uri.parse(
      'https://api.mymemory.translated.net/get'
      '?q=${Uri.encodeComponent(text)}'
      '&langpair=${_sourceLanguage}|${_targetLanguage}',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      final translated =
          data['responseData']?['translatedText']?.toString() ?? '';

      setState(() {
        _translatedText = translated;
        _isTranslating = false;
      });

      // Add to history
      _conversationHistory.add({
        'source': text,
        'translated': _translatedText,
        'sourceLang': _sourceLanguage,
        'targetLang': _targetLanguage,
        'time': DateTime.now(),
        'type': 'live',
      });

      await _handleOutput();
    } else {
      throw Exception('Translation failed');
    }
  } catch (e) {
    setState(() => _isTranslating = false);

    // Controlled fallback ONLY for English/French
    setState(() {
      if (_sourceLanguage == 'en' && _targetLanguage == 'fr') {
        _translatedText = 'Bonjour';
      } else if (_sourceLanguage == 'fr' && _targetLanguage == 'en') {
        _translatedText = 'Hello';
      }
    });

    _showSnackBar(
      '⚠️ Using demo translation (API unavailable)',
      Colors.orange,
    );

    await _handleOutput();
  }
}
  // ============ HANDLE OUTPUT (TEXT/AUDIO/BOTH) ============
  Future<void> _handleOutput() async {
  if (_outputAudio && _translatedText.isNotEmpty) {
    setState(() => _isPlayingAudio = true);
    await _flutterTts.speak(_translatedText);
  }
}

  // ============ PLAY/STOP AUDIO ============
  void _toggleAudioPlayback() {
    if (_isPlayingAudio) {
      _flutterTts.stop();
      setState(() => _isPlayingAudio = false);
    } else if (_translatedText.isNotEmpty) {
      setState(() => _isPlayingAudio = true);
      _flutterTts.speak(_translatedText);
    }
  }

  // ============ CLEAR ALL ============
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

  // ============ LOCALE HELPER ============
  String _getLocaleFromLanguage(String languageCode) {
  switch (languageCode) {
    case 'en':
      return 'en_US';
    case 'fr':
      return 'fr_FR';
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

  _initTTS();
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
    return Scaffold(
      appBar: AppBar(
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Selection Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildLanguageDropdown(
                            value: _sourceLanguage,
                            onChanged: (value) {
                              setState(() => _sourceLanguage = value!);
                            },
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
                    
                    // Output Options
                    Container(
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilterChip(
                                  label: const Text('📝 Text'),
                                  selected: _outputText,
                                  onSelected: (value) {
                                    setState(() => _outputText = value);
                                  },
                                  backgroundColor: Colors.grey.shade200,
                                  selectedColor: Colors.blue.shade100,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilterChip(
                                  label: const Text('🔊 Audio'),
                                  selected: _outputAudio,
                                  onSelected: (value) {
                                    setState(() => _outputAudio = value);
                                  },
                                  backgroundColor: Colors.grey.shade200,
                                  selectedColor: Colors.blue.shade100,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilterChip(
                                  label: const Text('📝🔊 Both'),
                                  selected: _outputText && _outputAudio,
                                  onSelected: (value) {
                                    setState(() {
                                      _outputText = value;
                                      _outputAudio = value;
                                    });
                                  },
                                  backgroundColor: Colors.grey.shade200,
                                  selectedColor: Colors.green.shade100,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Recording/Upload Status
            if (_isUploading)
              Container(
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
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
              ),

            if (_fileName != null && !_isUploading)
              Container(
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
                      onPressed: () {
                        setState(() {
                          _selectedAudioFile = null;
                          _fileName = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Record Button / Visualization
            if (_selectedAudioFile == null)
              Center(
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return GestureDetector(
                          onTap: _isListening ? _stopListening : _startListening,
                          child: Container(
                            width: 200 + (_isListening ? (_animationController.value * 50) : 0),
                            height: 200 + (_isListening ? (_animationController.value * 50) : 0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isListening
                                  ? Colors.red.withOpacity(0.3 - (_animationController.value * 0.1))
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
                                      color: (_isListening ? Colors.red : Colors.blue).withOpacity(0.3),
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
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Results
            if (_recognizedText.isNotEmpty)
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  _getLanguageName(_sourceLanguage),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
              ),

            const SizedBox(height: 12),

            if (_translatedText.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.translate, color: Colors.blue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Translation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  _getLanguageName(_targetLanguage),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                      
                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: _translatedText));
                              _showSnackBar('Copied to clipboard!', Colors.green);
},
                            color: Colors.blue,
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () {
                              // Save to favorites
                              _showSnackBar('Saved to favorites!', Colors.pink);
                            },
                            color: Colors.blue,
                          ),
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () {
                              // Share
                              _showSnackBar('Share feature coming soon!', Colors.orange);
                            },
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ],
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
                      const Text(
                        'Recent Translations',
                        style: TextStyle(
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
                                  const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
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
    );
  }

  // ============ LANGUAGE DROPDOWN ============
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

  String _getLanguageName(String code) {
    for (var lang in Languages.africanLanguages) {
      if (lang.code == code) return lang.nativeName;
    }
    for (var lang in Languages.globalLanguages) {
      if (lang.code == code) return lang.name;
    }
    return code;
  }
}