import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

import '../home/home_screen.dart';

class TextTranslationScreen extends StatefulWidget {
  const TextTranslationScreen({super.key});

  @override
  State<TextTranslationScreen> createState() => _TextTranslationScreenState();
}

class _TextTranslationScreenState extends State<TextTranslationScreen> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  String _lastTranslatedInput = '';
  String _sourceLanguage = 'en';
  String _targetLanguage = 'fr';
  bool _isTranslating = false;
  bool _isSpeaking = false;
  final Set<String> _favoriteTranslations = {};

  static const String _favoritesKey = 'text_translation_favorites';

  String get _translationUrl {
    final host = kIsWeb
        ? '127.0.0.1'
        : defaultTargetPlatform == TargetPlatform.android
            ? '10.0.2.2'
            : '127.0.0.1';

    return 'http://$host:5011/translationplatform-c24e2/us-central1/translate_text';
  }

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'fr', 'name': 'French', 'flag': '🇫🇷'},
    {'code': 'rw', 'name': 'Kinyarwanda', 'flag': '🇷🇼'},
  ];

  @override
  void initState() {
    super.initState();
    _sourceController.addListener(_handleTextChanged);
    _targetController.addListener(_handleTextChanged);
    _initTts();
    _loadFavorites();
  }

  void _handleTextChanged() {
    if (!mounted) return;

    final sourceText = _sourceController.text.trim();
    if (!_isTranslating &&
        _targetController.text.isNotEmpty &&
        sourceText != _lastTranslatedInput) {
      _flutterTts.stop();
      _isSpeaking = false;
      _lastTranslatedInput = '';
      _targetController.clear();
    }

    setState(() {});
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_favoritesKey) ?? <String>[];
    if (!mounted) return;
    setState(() {
      _favoriteTranslations
        ..clear()
        ..addAll(favorites);
    });
  }

  @override
  void dispose() {
    _sourceController.removeListener(_handleTextChanged);
    _targetController.removeListener(_handleTextChanged);
    _sourceController.dispose();
    _targetController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // ✅ REAL TRANSLATION FUNCTION (calls backend API)
  Future<void> _translate() async {
    final text = _sourceController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isTranslating = true);

    try {
      final url = Uri.parse(_translationUrl);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "text": text,
          "source_language": _getLanguageName(_sourceLanguage),
          "target_language": _getLanguageName(_targetLanguage),
        }),
      ).timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final translatedText = data['translated_text'] ?? '';
        _lastTranslatedInput = text;
        setState(() {
          _targetController.text = translatedText;
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Translation successful"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(data["error"]);
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _targetController.clear();
        _lastTranslatedInput = '';
        _isSpeaking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation is taking longer than expected. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _targetController.clear();
        _lastTranslatedInput = '';
        _isSpeaking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Translation failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;

      final tempText = _sourceController.text;
      _sourceController.text = _targetController.text;
      _targetController.text = tempText;
      _lastTranslatedInput = '';
      _isSpeaking = false;
      _flutterTts.stop();
    });
  }

  void _clearFields() {
    setState(() {
      _sourceController.clear();
      _targetController.clear();
      _lastTranslatedInput = '';
      _isSpeaking = false;
    });
    _flutterTts.stop();
  }

  String _languageLocale(String code) {
    switch (code) {
      case 'fr':
        return 'fr-FR';
      case 'rw':
        return 'rw-RW';
      default:
        return 'en-US';
    }
  }

  Future<void> _speakTranslation() async {
    if (_targetController.text.isEmpty) return;
    setState(() => _isSpeaking = true);
    await _flutterTts.setLanguage(_languageLocale(_targetLanguage));
    await _flutterTts.speak(_targetController.text);
  }

  Future<void> _copyTranslation() async {
    if (_targetController.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _targetController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_targetController.text.isEmpty) return;

    final favoriteKey = jsonEncode({
      'source': _sourceController.text.trim(),
      'translated': _targetController.text.trim(),
      'source_language': _sourceLanguage,
      'target_language': _targetLanguage,
    });

    final prefs = await SharedPreferences.getInstance();
    final isAlreadyFavorite = _favoriteTranslations.contains(favoriteKey);

    setState(() {
      if (isAlreadyFavorite) {
        _favoriteTranslations.remove(favoriteKey);
      } else {
        _favoriteTranslations.add(favoriteKey);
      }
    });

    await prefs.setStringList(_favoritesKey, _favoriteTranslations.toList());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAlreadyFavorite
              ? 'Removed from favorites!'
              : 'Saved to favorites!',
        ),
        backgroundColor: Colors.pink,
      ),
    );
  }

  bool _isFavoriteCurrentTranslation() {
    if (_targetController.text.isEmpty) return false;

    final favoriteKey = jsonEncode({
      'source': _sourceController.text.trim(),
      'translated': _targetController.text.trim(),
      'source_language': _sourceLanguage,
      'target_language': _targetLanguage,
    });

    return _favoriteTranslations.contains(favoriteKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Translation'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to menu',
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearFields,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Language Selector Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sourceLanguage,
                        isExpanded: true,
                        items: _languages.map((lang) {
                          return DropdownMenuItem(
                            value: lang['code'],
                            child: Row(
                              children: [
                                Text(lang['flag']!),
                                const SizedBox(width: 8),
                                Text(lang['name']!),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _sourceLanguage = value!;
                            _targetController.clear();
                            _lastTranslatedInput = '';
                            _isSpeaking = false;
                          });
                          _flutterTts.stop();
                        },
                      ),
                    ),
                  ),
                  
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: _swapLanguages,
                    color: Colors.blue,
                  ),
                  
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _targetLanguage,
                        isExpanded: true,
                        items: _languages.map((lang) {
                          return DropdownMenuItem(
                            value: lang['code'],
                            child: Row(
                              children: [
                                Text(lang['flag']!),
                                const SizedBox(width: 8),
                                Text(lang['name']!),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _targetLanguage = value!;
                            _targetController.clear();
                            _lastTranslatedInput = '';
                            _isSpeaking = false;
                          });
                          _flutterTts.stop();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Source Text Input
            Expanded(
              flex: 3,
              child: Card(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Source Text',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            _getLanguageName(_sourceLanguage),
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: TextField(
                          controller: _sourceController,
                          maxLines: null,
                          expands: true,
                          decoration: InputDecoration(
                            hintText: 'Enter text to translate...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${_sourceController.text.length} characters',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Translate Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isTranslating ? null : _translate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
                child: _isTranslating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Translating...'),
                        ],
                      )
                    : const Text(
                        'Translate',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Translation Result
            Expanded(
              flex: 3,
              child: Card(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Translation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            _getLanguageName(_targetLanguage),
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _targetController.text.isEmpty
                                ? 'Translation will appear here'
                                : _targetController.text,
                            style: TextStyle(
                              fontSize: 18,
                              color: _targetController.text.isEmpty
                                  ? Colors.grey.shade400
                                  : Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      if (_targetController.text.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: _copyTranslation,
                              color: Colors.blue.shade700,
                            ),
                            IconButton(
                              icon: Icon(
                                _isSpeaking ? Icons.stop : Icons.volume_up,
                              ),
                              onPressed: _targetController.text.isEmpty
                                  ? null
                                  : () {
                                      if (_isSpeaking) {
                                        _flutterTts.stop();
                                        setState(() => _isSpeaking = false);
                                      } else {
                                        _speakTranslation();
                                      }
                                    },
                              color: Colors.blue.shade700,
                            ),
                            IconButton(
                              icon: Icon(
                                _isFavoriteCurrentTranslation()
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                              onPressed: _toggleFavorite,
                              color: Colors.blue.shade700,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'fr':
        return 'French';
      case 'rw':
        return 'Kinyarwanda';
      default:
        return '';
    }
  }
}