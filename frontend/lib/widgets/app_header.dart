import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations_extensions.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';

class AppBrandControls extends StatelessWidget {
  const AppBrandControls({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLanguageSelector(),
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
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => PopupMenuButton<String>(
        tooltip: context.l10n.selectLanguage,
        initialValue: auth.systemLanguage,
        onSelected: (language) {
          unawaited(_selectLanguage(auth, language));
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'en',
            child: Text(context.l10n.languageEnglish),
          ),
          PopupMenuItem(
            value: 'rw',
            child: Text(context.l10n.languageKinyarwanda),
          ),
          PopupMenuItem(
            value: 'fr',
            child: Text(context.l10n.languageFrench),
          ),
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
                  _languageName(context.l10n, auth.systemLanguage),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down,
                  color: Colors.black87, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _languageName(AppLocalizations localizations, String language) {
    switch (language) {
      case 'rw':
        return localizations.languageKinyarwanda;
      case 'fr':
        return localizations.languageFrench;
      default:
        return localizations.languageEnglish;
    }
  }

  Future<void> _selectLanguage(AuthProvider auth, String language) async {
    try {
      await auth.updateSystemLanguage(language);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.languageUpdateFailed(error.toString()),
          ),
        ),
      );
    }
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
        width: 44,
        height: 44,
        child: Image.asset(assetPath, fit: BoxFit.contain),
      );
    }

    return SizedBox(
      width: 44,
      height: 44,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 64,
          maxWidth: 64,
          minHeight: 64,
          maxHeight: 64,
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
