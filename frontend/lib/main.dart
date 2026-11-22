import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/constants/system_ui.dart';
import 'core/network/api_client.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/app_localizations_extensions.dart';
import 'providers/auth_provider.dart';
import 'providers/offline_provider.dart';
import 'screens/education/lecture_summarizer_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/maps/google_maps_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/translation/camera_translation_screen.dart';
import 'screens/translation/motorist_mode_screen.dart';
import 'screens/translation/offline_packs_screen.dart';
import 'screens/translation/real_time_speech_screen.dart';
import 'screens/translation/text_translation_screen.dart';
import 'screens/translation/video_translation_screen.dart';
import 'widgets/app_sidebar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(appSystemUiOverlayStyle);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>(
          create: (_) => ApiClient(),
          dispose: (_, client) => client.dispose(),
        ),
        ChangeNotifierProvider(create: (_) => AppSidebarController()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..restoreSession(),
        ),
        ChangeNotifierProvider(create: (_) => OfflineProvider()),

// You don't need to import OfflinePacksScreen here – it's used in the drawer.
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        locale: Locale(auth.systemLanguage),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          _EnglishFallbackForKinyarwanda<MaterialLocalizations>(
            GlobalMaterialLocalizations.delegate,
          ),
          _EnglishFallbackForKinyarwanda<WidgetsLocalizations>(
            GlobalWidgetsLocalizations.delegate,
          ),
          _EnglishFallbackForKinyarwanda<CupertinoLocalizations>(
            GlobalCupertinoLocalizations.delegate,
          ),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            systemOverlayStyle: appSystemUiOverlayStyle,
          ),
        ),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: appSystemUiOverlayStyle,
          child: child ?? const SizedBox.shrink(),
        ),
        routes: {
          AppRoutes.home: (_) => const HomeScreen(),
          AppRoutes.textTranslation: (_) => const TextTranslationScreen(),
          AppRoutes.speechTranslation: (_) => const RealTimeSpeechScreen(),
          AppRoutes.videoTranslation: (_) => const VideoTranslationScreen(),
          AppRoutes.cameraTranslation: (_) => const CameraTranslationScreen(),
          AppRoutes.educationTools: (_) => const LectureSummarizerScreen(),
          AppRoutes.offlinePacks: (_) => const OfflinePacksScreen(),
          AppRoutes.driverMode: (_) => const MotoristModeScreen(),
          AppRoutes.maps: (_) => const GoogleMapsScreen(),
          AppRoutes.settings: (_) => const SettingsScreen(),
        },
        home: const _AppHome(),
      ),
    );
  }
}

class _EnglishFallbackForKinyarwanda<T> extends LocalizationsDelegate<T> {
  const _EnglishFallbackForKinyarwanda(this.delegate);

  final LocalizationsDelegate<T> delegate;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'rw';

  @override
  Future<T> load(Locale locale) => delegate.load(const Locale('en'));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

class _AppHome extends StatelessWidget {
  const _AppHome();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.initializationError != null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      auth.initializationError!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: auth.restoreSession,
                      child: Text(context.l10n.retry),
                    ),
                    TextButton(
                      onPressed: auth.continueToLogin,
                      child: Text(context.l10n.continueToLogin),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return auth.isAuthenticated ? const HomeScreen() : const AuthScreen();
      },
    );
  }
}
