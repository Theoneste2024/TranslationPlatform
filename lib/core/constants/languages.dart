class Languages {
  static const List<LanguageModel> africanLanguages = [
    LanguageModel(
      code: 'rw',
      name: 'Kinyarwanda',
      nativeName: 'Ikinyarwanda',
      flagEmoji: '🇷🇼',
      isOfflineSupported: true,
    ),
    LanguageModel(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flagEmoji: '🇬🇧',
      isOfflineSupported: true,
    ),
    LanguageModel(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flagEmoji: '🇫🇷',
      isOfflineSupported: true,
    ),
    LanguageModel(
      code: 'sw',
      name: 'Swahili',
      nativeName: 'Kiswahili',
      flagEmoji: '🇰🇪',
    ),
    LanguageModel(
      code: 'kin',
      name: 'Kinyarwanda (Rural)',
      nativeName: 'Ikinyarwanda cy\'icyaro',
      flagEmoji: '🇷🇼',
      isOfflineSupported: true,
    ),
   
  ];

  static const List<LanguageModel> globalLanguages = [
    LanguageModel(code: 'es', name: 'Spanish', nativeName: 'Español', flagEmoji: '🇪🇸'),
    LanguageModel(code: 'de', name: 'German', nativeName: 'Deutsch', flagEmoji: '🇩🇪'),
    LanguageModel(code: 'zh', name: 'Chinese', nativeName: '中文', flagEmoji: '🇨🇳'),
    LanguageModel(code: 'ar', name: 'Arabic', nativeName: 'العربية', flagEmoji: '🇸🇦'),
    LanguageModel(code: 'pt', name: 'Portuguese', nativeName: 'Português', flagEmoji: '🇵🇹'),
  ];
}

class LanguageModel {
  final String code;
  final String name;
  final String nativeName;
  final String flagEmoji;
  final bool isOfflineSupported;

  const LanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flagEmoji,
    this.isOfflineSupported = false,
  });
}