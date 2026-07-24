import 'package:flutter/material.dart';
import '../education/lecture_summarizer_screen.dart' deferred as lecture;
import '../maps/google_maps_screen.dart' deferred as maps;
import '../settings/settings_screen.dart' deferred as settings;
import '../translation/camera_translation_screen.dart' deferred as camera;
import '../translation/motorist_mode_screen.dart' deferred as motorist;
import '../translation/offline_packs_screen.dart' deferred as offline;
import '../translation/real_time_speech_screen.dart' deferred as speech;
import '../translation/text_translation_screen.dart' deferred as text;
import '../translation/video_translation_screen.dart' deferred as video;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Color constants for easy maintenance
  static const Color _blueColor = Color(0xFF003D82); // Dark Sky Blue
  static const Color _greenColor = Color(0xFF003D82); // Dark Sky Blue
  static const Color _yellowColor = Color(0xFF003D82); // Dark Sky Blue

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(context),
      body: _buildBody(),
    );
  }

  // MARK: - App Bar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 140,
      title: _buildAppBarTitle(),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: _buildMenuButton(),
      actions: _buildAppBarActions(),
      flexibleSpace: _buildAppBarGradient(),
    );
  }

  Column _buildAppBarTitle() {
    return const Column(
      children: [
        Text(
          'Translation Platform',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '@2026 Rwanda • Africa • World',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Builder _buildMenuButton() {
    return Builder(
      builder: (context) => IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      Padding(
        padding: const EdgeInsets.only(right: 26.0),
        child: Image.asset(
          'assets/images/logo.png',
          width: 100,
          height: 100,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.business, color: Colors.white, size: 70),
        ),
      ),
    ];
  }

  Container _buildAppBarGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_blueColor, _greenColor, _yellowColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.3, 0.6, 1.0],
        ),
      ),
    );
  }

  // MARK: - Body
  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: _buildBodyGradient(),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildIconCircle(),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _buildContentCard(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _buildBodyGradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_blueColor, _greenColor, _yellowColor],
        stops: [0.2, 0.5, 0.9],
      ),
    );
  }

  Container _buildIconCircle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.translate,
        size: 100,
        color: _blueColor,
      ),
    );
  }

  Container _buildContentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTitle(),
          const SizedBox(height: 10),
          _buildLanguages(),
          const SizedBox(height: 24),
          _buildStartButton(),
          const SizedBox(height: 16),
          _buildTagline(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Translation Platform',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: _blueColor,
      ),
    );
  }

  Widget _buildLanguages() {
    return const Text(
      'Kinyarwanda • English • French',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        color: _greenColor,
      ),
    );
  }

  Widget _buildStartButton() {
    return ElevatedButton(
      onPressed: () => _navigateToDeferred(
        loadLibrary: text.loadLibrary,
        screenBuilder: () => text.TextTranslationScreen(),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _blueColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
      ),
      child: const Text('Start Translating', style: TextStyle(fontSize: 16)),
    );
  }

  Widget _buildTagline() {
    return const Text(
      'For Driver\'s, Tourists, Students, and Everyone!',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _yellowColor,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
    );
  }

  // MARK: - Drawer
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: _buildDrawerGradient(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildDrawerHeader(),
            // Main Features
            _buildDrawerItem(
              icon: Icons.home,
              title: 'Home',
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.translate,
              title: 'Text Translation',
              onTap: () => _navigateToDeferred(
                loadLibrary: text.loadLibrary,
                screenBuilder: () => text.TextTranslationScreen(),
                closeDrawer: true,
              ),
            ),
            _buildDrawerItem(
              icon: Icons.mic,
              title: 'Speech Translation',
              onTap: () => _navigateToDeferred(
                loadLibrary: speech.loadLibrary,
                screenBuilder: () => speech.RealTimeSpeechScreen(),
                closeDrawer: true,
              ),
            ),
            _buildDrawerItem(
              icon: Icons.video_library,
              title: 'Video Translation',
              onTap: () => _navigateToDeferred(
                loadLibrary: video.loadLibrary,
                screenBuilder: () => video.VideoTranslationScreen(),
                closeDrawer: true,
              ),
            ),
            _buildDrawerItem(
              icon: Icons.camera_alt,
              title: 'Camera Translation',
              onTap: () => _navigateToDeferred(
                loadLibrary: camera.loadLibrary,
                screenBuilder: () => camera.CameraTranslationScreen(),
                closeDrawer: true,
              ),
            ),

            // Education & Utilities (Under Development)
            _buildDrawerItem(
              icon: Icons.school,
              title: 'Education Tools',
              subtitle: 'Under Development',
              onTap: () => _navigateToDeferred(
                loadLibrary: lecture.loadLibrary,
                screenBuilder: () => lecture.LectureSummarizerScreen(),
                closeDrawer: true,
              ),
            ),
            _buildDrawerItem(
              icon: Icons.offline_bolt,
              title: 'Offline Packs',
              subtitle: 'Under Development',
              onTap: () => _navigateToDeferred(
                loadLibrary: offline.loadLibrary,
                screenBuilder: () => offline.OfflinePacksScreen(),
                closeDrawer: true,
              ),
            ),
            _buildDrawerItem(
              icon: Icons.motorcycle,
              title: 'Driver Mode',
              subtitle: 'Under Development',
              onTap: () => _navigateToDeferred(
                loadLibrary: motorist.loadLibrary,
                screenBuilder: () => motorist.MotoristModeScreen(),
                closeDrawer: true,
              ),
            ),

            // Maps & Navigation
            _buildDrawerItem(
              icon: Icons.map,
              title: 'Google Maps',
              onTap: () => _navigateToDeferred(
                loadLibrary: maps.loadLibrary,
                screenBuilder: () => maps.GoogleMapsScreen(),
                closeDrawer: true,
              ),
            ),

            const Divider(color: Colors.white54),

            // Settings & Info
            _buildDrawerItem(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () => _navigateToDeferred(
                loadLibrary: settings.loadLibrary,
                screenBuilder: () => settings.SettingsScreen(),
                closeDrawer: true,
              ),
            ),
            _buildDrawerItem(
              icon: Icons.info,
              title: 'About',
              onTap: () => _showAboutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildDrawerGradient() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_blueColor, _greenColor, _yellowColor],
        stops: [0.1, 0.5, 0.9],
      ),
    );
  }

  Container _buildDrawerHeader() {
    return Container(
      height: 180,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_blueColor, _greenColor, _yellowColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.translate, size: 48, color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Translation Platform',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Rwanda • Africa • World',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            )
          : null,
      onTap: onTap,
    );
  }

  // MARK: - Helper Methods
  Future<void> _navigateToDeferred({
    required Future<dynamic> Function() loadLibrary,
    required Widget Function() screenBuilder,
    bool closeDrawer = false,
  }) async {
    if (closeDrawer) {
      Navigator.pop(context);
    }

    await loadLibrary();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screenBuilder()),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAboutIcon(),
            const SizedBox(height: 16),
            const Text(
              'Translation Platform',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Breaking language barriers in Rwanda, Africa & World.\n\n'
              'Supporting Kinyarwanda, English, and French.\n\n'
              '🇷🇼 Made with pride in Rwanda 🇷🇼\n\n'
              'Developed by Prime Data Consulting Group LTD',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Container _buildAboutIcon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_blueColor, _greenColor, _yellowColor],
        ),
      ),
      child: const Icon(Icons.translate, size: 48, color: Colors.white),
    );
  }
}
