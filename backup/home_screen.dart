import 'package:flutter/material.dart';

class TextTranslationScreen extends StatefulWidget {
  const TextTranslationScreen({Key? key}) : super(key: key);

  @override
  State<TextTranslationScreen> createState() => _TextTranslationScreenState();
}

class _TextTranslationScreenState extends State<TextTranslationScreen> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  String _sourceLanguage = 'en';
  String _targetLanguage = 'fr';
  bool _isTranslating = false;

  final List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
    {'code': 'fr', 'name': 'French', 'flag': '🇫🇷'},
    {'code': 'rw', 'name': 'Kinyarwanda', 'flag': '🇷🇼'},
  ];

  @override
  void dispose() {
    _sourceController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _translate() async {
    if (_sourceController.text.isEmpty) return;
    
    setState(() => _isTranslating = true);
    
    // Simulate translation API call
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      // Demo translation
      if (_sourceLanguage == 'en' && _targetLanguage == 'fr') {
        _targetController.text = 'Bonjour, comment allez-vous?';
      } else if (_sourceLanguage == 'fr' && _targetLanguage == 'en') {
        _targetController.text = 'Hello, how are you?';
      } else if (_sourceLanguage == 'en' && _targetLanguage == 'rw') {
        _targetController.text = 'Muraho, amakuru?';
      } else if (_sourceLanguage == 'rw' && _targetLanguage == 'en') {
        _targetController.text = 'Hello, how are you?';
      } else {
        _targetController.text = 'Translation: ${_sourceController.text}';
      }
      _isTranslating = false;
    });
  }

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLanguage;
      _sourceLanguage = _targetLanguage;
      _targetLanguage = temp;
      
      final tempText = _sourceController.text;
      _sourceController.text = _targetController.text;
      _targetController.text = tempText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Translation'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Language Selector
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
                          setState(() => _sourceLanguage = value!);
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
                          setState(() => _targetLanguage = value!);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Source Text
            Expanded(
              child: Card(
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
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _sourceController.clear();
                              _targetController.clear();
                            },
                          ),
                        ],
                      ),
                      Expanded(
                        child: TextField(
                          controller: _sourceController,
                          maxLines: null,
                          expands: true,
                          decoration: const InputDecoration(
                            hintText: 'Enter text to translate...',
                            border: InputBorder.none,
                          ),
                        ),
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
              height: 50,
              child: ElevatedButton(
                onPressed: _isTranslating ? null : _translate,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isTranslating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Translate',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Target Text
            Expanded(
              child: Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Translation',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                            ),
                          ),
                        ),
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
}