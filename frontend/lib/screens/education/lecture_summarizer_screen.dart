import 'package:flutter/material.dart';

import '../../l10n/app_localizations_extensions.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_sidebar.dart';

class LectureSummarizerScreen extends StatelessWidget {
  const LectureSummarizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.educationTools),
          elevation: 0,
          leading: const AppMenuButton(),
          automaticallyImplyLeading: false,
          actions: const [AppBrandControls()],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.school,
                  size: 100,
                  color: Colors.indigo,
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.lectureSummarizer,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.comingSoon,
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                Text(
                  '• ${context.l10n.autoSummarizeLectures}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${context.l10n.studyNotesGeneration}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${context.l10n.vocabularyExtraction}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(context.l10n.backToHome),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
