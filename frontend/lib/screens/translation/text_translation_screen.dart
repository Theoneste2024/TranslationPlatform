import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/languages.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_sidebar.dart';

class TextTranslationScreen extends StatefulWidget {
  const TextTranslationScreen({super.key});

  @override
  State<TextTranslationScreen> createState() => _TextTranslationScreenState();
}

class _TextTranslationScreenState extends State<TextTranslationScreen> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<void>? _audioCompleteSubscription;
  CancelToken? _speechCancelToken;
  String _lastTranslatedInput = '';
  String _sourceLanguage = 'en';
  String _targetLanguage = 'fr';
  bool _isTranslating = false;
  bool _isGeneratingSpeech = false;
  bool _isSpeaking = false;
  final Set<String> _favoriteTranslations = {};

  static const String _favoritesKey = 'text_translation_favorites';
  static final Uint8List _silentWav = _createSilentWav();

  static Uint8List _createSilentWav() {
    const pcmSize = 480;
    final wav = Uint8List(44 + pcmSize);
    final data = ByteData.view(wav.buffer);

    void writeId(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        wav[offset + index] = value.codeUnitAt(index);
      }
    }

    writeId(0, 'RIFF');
    data.setUint32(4, wav.length - 8, Endian.little);
    writeId(8, 'WAVE');
    writeId(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, 24000, Endian.little);
    data.setUint32(28, 48000, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeId(36, 'data');
    data.setUint32(40, pcmSize, Endian.little);
    return wav;
  }

  final List<LanguageModel> _languages = Languages.translationLanguages;

  @override
  void initState() {
    super.initState();
    _sourceController.addListener(_handleTextChanged);
    _targetController.addListener(_handleTextChanged);
    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
    _loadFavorites();
  }

  void _handleTextChanged() {
    if (!mounted) return;

    final sourceText = _sourceController.text.trim();
    if (!_isTranslating &&
        _targetController.text.isNotEmpty &&
        sourceText != _lastTranslatedInput) {
      unawaited(_stopSpeaking());
      _isGeneratingSpeech = false;
      _isSpeaking = false;
      _lastTranslatedInput = '';
      _targetController.clear();
    }

    setState(() {});
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
    _speechCancelToken?.cancel('Translation screen disposed.');
    unawaited(_audioCompleteSubscription?.cancel());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }

  // ✅ REAL TRANSLATION FUNCTION (calls backend API)
  Future<void> _translate() async {
    final text = _sourceController.text.trim();
    if (text.isEmpty) return;

    unawaited(_stopSpeaking());
    setState(() => _isTranslating = true);

    try {
      final response =
          await context.read<ApiClient>().dio.post<Map<String, dynamic>>(
        'translate_text/',
        data: {
          'text': text,
          'source_language': _getLanguageName(_sourceLanguage),
          'target_language': _getLanguageName(_targetLanguage),
        },
      ).timeout(const Duration(seconds: 60));

      final translatedText =
          response.data?['translated_text']?.toString() ?? '';
      _lastTranslatedInput = text;
      setState(() {
        _targetController.text = translatedText;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.translationSuccessful),
          backgroundColor: Colors.green,
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _targetController.clear();
        _lastTranslatedInput = '';
        _isSpeaking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.translationTimedOut),
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
          content: Text(context.l10n.translationFailed(e.toString())),
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
      _isGeneratingSpeech = false;
      _isSpeaking = false;
    });
    unawaited(_stopSpeaking());
  }

  Future<void> _speakTranslation() async {
    final text = _targetController.text.trim();
    if (text.isEmpty || _isGeneratingSpeech || _isSpeaking) return;

    final cancelToken = CancelToken();
    _speechCancelToken = cancelToken;
    setState(() => _isGeneratingSpeech = true);

    var playbackStarted = false;
    try {
      if (kIsWeb) {
        await _audioPlayer.play(
          BytesSource(_silentWav, mimeType: 'audio/wav'),
        );
        if (!mounted || cancelToken.isCancelled) return;
      }

      final response = await context
          .read<ApiClient>()
          .dio
          .post<Map<String, dynamic>>(
            'translate_text/speech/',
            data: {
              'text': text,
              'target_language': _getLanguageName(_targetLanguage),
            },
            cancelToken: cancelToken,
          )
          .timeout(
        const Duration(seconds: 75),
        onTimeout: () {
          cancelToken.cancel('Speech generation timed out.');
          throw TimeoutException('Speech generation timed out.');
        },
      );
      if (!mounted || cancelToken.isCancelled) return;

      final audioBase64 = response.data?['audio_base64']?.toString();
      if (audioBase64 == null || audioBase64.isEmpty) {
        throw const FormatException('Speech response did not contain audio.');
      }
      final mimeType =
          response.data?['audio_mime_type']?.toString() ?? 'audio/wav';
      setState(() {
        _isGeneratingSpeech = false;
        _isSpeaking = true;
      });
      await _audioPlayer.play(
        BytesSource(base64Decode(audioBase64), mimeType: mimeType),
      );
      playbackStarted = true;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || !mounted) return;
      final responseData = error.response?.data;
      final message = responseData is Map<String, dynamic>
          ? responseData['error']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(message ?? 'Speech generation failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech generation timed out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not play translation: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (identical(_speechCancelToken, cancelToken)) {
        _speechCancelToken = null;
      }
      if (mounted) {
        setState(() {
          _isGeneratingSpeech = false;
          if (!playbackStarted) _isSpeaking = false;
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    _speechCancelToken?.cancel('Speech playback stopped.');
    _speechCancelToken = null;
    if (mounted && (_isGeneratingSpeech || _isSpeaking)) {
      setState(() {
        _isGeneratingSpeech = false;
        _isSpeaking = false;
      });
    }
    await _audioPlayer.stop();
  }

  Future<void> _copyTranslation() async {
    if (_targetController.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _targetController.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.copiedToClipboard),
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
              ? context.l10n.removedFromFavorites
              : context.l10n.savedToFavorites,
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

  Widget _buildLanguageDropdown({
    required String selectedCode,
    required ValueChanged<String?> onChanged,
  }) {
    Widget languageLabel(LanguageModel language) {
      return Row(
        children: [
          Text(language.flagEmoji),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              language.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Expanded(
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCode,
          isExpanded: true,
          padding: EdgeInsets.zero,
          iconSize: 18,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          selectedItemBuilder: (context) =>
              _languages.map(languageLabel).toList(),
          items: _languages.map((language) {
            return DropdownMenuItem<String>(
              value: language.code,
              child: languageLabel(language),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return AppPageShell(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.textTranslation),
          elevation: 0,
          leading: const AppMenuButton(),
          automaticallyImplyLeading: false,
          actions: const [AppBrandControls()],
        ),
        resizeToAvoidBottomInset: true,
        body: Padding(
          padding: EdgeInsets.all(keyboardVisible ? 8 : 16),
          child: Column(
            children: [
              // Language Selector Row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    _buildLanguageDropdown(
                      selectedCode: _sourceLanguage,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _sourceLanguage = value;
                          _targetController.clear();
                          _lastTranslatedInput = '';
                          _isSpeaking = false;
                        });
                        unawaited(_stopSpeaking());
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: _swapLanguages,
                      color: Colors.blue,
                    ),
                    _buildLanguageDropdown(
                      selectedCode: _targetLanguage,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _targetLanguage = value;
                          _targetController.clear();
                          _lastTranslatedInput = '';
                          _isSpeaking = false;
                        });
                        unawaited(_stopSpeaking());
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: keyboardVisible ? 8 : 20),

              // Source Text Input
              Expanded(
                flex: keyboardVisible ? 1 : 3,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(keyboardVisible ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.l10n.sourceText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _getLanguageName(_sourceLanguage),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
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
                              hintText: context.l10n.sourceTextHint,
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
                              context.l10n.characterCount(
                                _sourceController.text.length,
                              ),
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

              if (!keyboardVisible) ...[
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
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(context.l10n.translating),
                            ],
                          )
                        : Text(
                            context.l10n.translate,
                            style: const TextStyle(
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
                                context.l10n.translation,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  _getLanguageName(_targetLanguage),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                _targetController.text.isEmpty
                                    ? context.l10n.translationPlaceholder
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
                                  icon: _isGeneratingSpeech
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          _isSpeaking
                                              ? Icons.stop
                                              : Icons.volume_up,
                                        ),
                                  onPressed: _targetController.text.isEmpty
                                      ? null
                                      : () {
                                          if (_isGeneratingSpeech ||
                                              _isSpeaking) {
                                            unawaited(_stopSpeaking());
                                          } else {
                                            unawaited(_speakTranslation());
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
            ],
          ),
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    for (final language in Languages.translationLanguages) {
      if (language.code == code) return language.name;
    }
    return '';
  }
}
