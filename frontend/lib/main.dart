import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/system_ui.dart';
import 'core/network/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/offline_provider.dart';
import 'repositories/auth_repository.dart';
import 'screens/education/lecture_summarizer_screen.dart';
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
          create: (context) => AuthProvider(
            AuthRepository(context.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mpuza - Rwanda',
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
      home: const HomeScreen(),
    );
  }
}
