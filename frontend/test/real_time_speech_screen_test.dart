import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:translation_platform/screens/translation/real_time_speech_screen.dart';
import 'package:translation_platform/screens/translation/text_translation_screen.dart';
import 'package:translation_platform/widgets/app_sidebar.dart';

void main() {
  testWidgets('speech translation is text-only and fits phone and desktop',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [
      const Size(390, 844),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppSidebarController(),
          child: const MaterialApp(home: RealTimeSpeechScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Speak'), findsOneWidget);
      expect(find.text('Tap and speak'), findsOneWidget);
      expect(find.text('Translation'), findsOneWidget);
      expect(find.text('Translation will appear here'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);

      final translationContainerFinder = find.ancestor(
        of: find.text('Translation will appear here'),
        matching: find.byType(Container),
      );
      final translationContainer =
          tester.widget<Container>(translationContainerFinder.first);
      expect(
        translationContainer.padding,
        const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      );
      expect(
        translationContainer.decoration,
        BoxDecoration(
          border: Border.all(color: const Color(0xFF1B6B3A), width: 2),
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFE8F5EE),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Translation will appear here')).style,
        const TextStyle(
          fontSize: 22,
          height: 1.35,
          color: Color(0xFF17382A),
        ),
      );

      final boxFinder = find.ancestor(
        of: find.text('Translation will appear here'),
        matching: find.byType(ConstrainedBox),
      );
      expect(tester.getSize(boxFinder.first).height, greaterThanOrEqualTo(190));
      expect(tester.takeException(), isNull, reason: 'Viewport $size');
    }
  });

  testWidgets(
      'speech language selector offers only the five translation languages',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSidebarController(),
        child: const MaterialApp(home: RealTimeSpeechScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('🇬🇧 English'), findsWidgets);
    expect(find.text('🇫🇷 French'), findsWidgets);
    expect(find.text('🇷🇼 Kinyarwanda'), findsOneWidget);
    expect(find.text('🇹🇿 Kiswahili'), findsOneWidget);
    expect(find.text('🇨🇳 Chinese'), findsOneWidget);
    expect(find.textContaining('Spanish'), findsNothing);
    expect(find.textContaining('German'), findsNothing);
    expect(find.textContaining('Arabic'), findsNothing);
    expect(find.textContaining('Portuguese'), findsNothing);
    expect(find.textContaining('Rural'), findsNothing);
  });

  testWidgets(
      'text language selector offers only the five translation languages',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSidebarController(),
        child: const MaterialApp(home: TextTranslationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();

    expect(find.text('Kinyarwanda'), findsOneWidget);
    expect(find.text('Kiswahili'), findsOneWidget);
    expect(find.text('Chinese'), findsOneWidget);
    expect(find.text('Spanish'), findsNothing);
  });
}
