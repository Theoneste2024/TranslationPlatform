import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations_extensions.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_sidebar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.settings),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          leading: const AppMenuButton(),
          automaticallyImplyLeading: false,
          actions: const [AppBrandControls()],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.l10n.settingsTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(context.l10n.darkMode),
              subtitle: Text(context.l10n.enableDarkTheme),
              value: false,
              onChanged: (value) {},
              secondary: const Icon(Icons.dark_mode),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(context.l10n.defaultLanguage),
              subtitle: Text(
                _languageName(
                  context.l10n,
                  context.watch<AuthProvider>().systemLanguage,
                ),
              ),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: Text(context.l10n.speechRate),
              subtitle: Text(context.l10n.normal),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: Text(context.l10n.clearCache),
              subtitle: Text(context.l10n.cacheUsage('245 MB')),
              onTap: () {},
            ),
          ],
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
}
