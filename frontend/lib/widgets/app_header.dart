import 'package:flutter/material.dart';

class AppBrandControls extends StatelessWidget {
  const AppBrandControls({
    this.logoAssetPath = AppBrandLogo.primeLogoAssetPath,
    super.key,
  });

  final String logoAssetPath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLanguageSelector(),
          const SizedBox(width: 8),
          AppBrandLogo(assetPath: logoAssetPath),
        ],
      ),
    );
  }
}

class AppLanguageSelector extends StatefulWidget {
  const AppLanguageSelector({super.key});

  @override
  State<AppLanguageSelector> createState() => _AppLanguageSelectorState();
}

class _AppLanguageSelectorState extends State<AppLanguageSelector> {
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Select language',
      initialValue: _selectedLanguage,
      onSelected: (language) => setState(() => _selectedLanguage = language),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'English', child: Text('English')),
        PopupMenuItem(value: 'Kinyarwanda', child: Text('Kinyarwanda')),
        PopupMenuItem(value: 'French', child: Text('French')),
      ],
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, color: Color(0xFF14518A), size: 14),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 76),
              child: Text(
                _selectedLanguage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.black87, size: 16),
          ],
        ),
      ),
    );
  }
}

class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    this.assetPath = primeLogoAssetPath,
    super.key,
  });

  static const primeLogoAssetPath =
      'assets/images/PRIME LOGO PNG FORMATS-14.png';

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    if (assetPath == primeLogoAssetPath) {
      return SizedBox(
        width: 30,
        height: 30,
        child: Image.asset(assetPath, fit: BoxFit.contain),
      );
    }

    return SizedBox(
      width: 30,
      height: 30,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 52,
          maxWidth: 52,
          minHeight: 52,
          maxHeight: 52,
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
