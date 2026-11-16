import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/system_ui.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../translation/text_translation_screen.dart';
import '../translation/real_time_speech_screen.dart';
import '../translation/video_translation_screen.dart';
import '../translation/camera_translation_screen.dart';
import '../translation/offline_packs_screen.dart';
import '../education/lecture_summarizer_screen.dart';
import '../translation/motorist_mode_screen.dart';
import '../maps/google_maps_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _blueColor = Color(0xFF00A1DE);
  static const Color _greenColor = Color(0xFF20603D);
  static const Color _yellowColor = Color(0xFFE1BD00);

  @override
  Widget build(BuildContext context) {
    final systemInsets = MediaQuery.paddingOf(context);

    return AnnotatedRegion(
      value: appSystemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: appSystemBarColor,
        drawer: _buildDrawer(context),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/mpuza_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final titleSize = (constraints.maxWidth * 0.085)
                      .clamp(40.0, 64.0)
                      .toDouble();
                  return Stack(
                    children: [
                      Positioned(
                        top: 18,
                        left: 18,
                        child: _buildMenuButton(),
                      ),
                      const Positioned(
                        top: 18,
                        right: 8,
                        child: AppBrandControls(
                          logoAssetPath: 'assets/images/logo.png',
                        ),
                      ),
                      Center(
                        child: Transform.translate(
                          offset: const Offset(0, -12),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 24,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: Center(
                                    child: Icon(
                                      Icons.translate,
                                      color: Colors.white,
                                      size: 80,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'MPUZA',
                                  style: TextStyle(
                                    color: const Color(0xFF092C78),
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w900,
                                    height: 0.95,
                                  ),
                                ),
                                const Text(
                                  'Connecting People',
                                  style: TextStyle(
                                    color: Color(0xFF092C78),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _buildStartButton(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: systemInsets.top,
              child: const ColoredBox(color: appSystemBarColor),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: systemInsets.bottom,
              child: const ColoredBox(color: appSystemBarColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton() {
    return Builder(
      builder: (context) => Material(
        color: const Color(0xFF06498E),
        borderRadius: BorderRadius.circular(5),
        child: IconButton(
          tooltip: 'Open navigation menu',
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.menu, color: Colors.white, size: 20),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return ElevatedButton(
      onPressed: () => _navigateTo(const TextTranslationScreen()),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0667F9),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Start Translating',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 20),
        ],
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
            _buildDrawerHeader(context),
            // Main Features
            _buildDrawerItem(
              icon: Icons.home,
              title: 'Home',
              onTap: () => Navigator.pop(context),
            ),
            _buildDrawerItem(
              icon: Icons.translate,
              title: 'Text Translation',
              onTap: () => _navigateTo(const TextTranslationScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.mic,
              title: 'Speech Translation',
              onTap: () => _navigateTo(const RealTimeSpeechScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.video_library,
              title: 'Video Translation',
              onTap: () => _navigateTo(const VideoTranslationScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.camera_alt,
              title: 'Camera Translation',
              onTap: () => _navigateTo(const CameraTranslationScreen()),
            ),

            // Education & Utilities (Under Development)
            _buildDrawerItem(
              icon: Icons.school,
              title: 'Education Tools',
              subtitle: 'Under Development',
              onTap: () => _navigateTo(const LectureSummarizerScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.offline_bolt,
              title: 'Offline Packs',
              subtitle: 'Under Development',
              onTap: () => _navigateTo(const OfflinePacksScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.motorcycle,
              title: 'Driver Mode',
              subtitle: 'Under Development',
              onTap: () => _navigateTo(const MotoristModeScreen()),
            ),

            // Maps & Navigation
            _buildDrawerItem(
              icon: Icons.map,
              title: 'Google Maps',
              onTap: () => _navigateTo(const GoogleMapsScreen()),
            ),

            const Divider(color: Colors.white54),

            // Settings & Info
            _buildDrawerItem(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () => _navigateTo(const SettingsScreen()),
            ),
            _buildDrawerItem(
              icon: Icons.info,
              title: 'About',
              onTap: () => _showAboutDialog(context),
            ),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Log out',
              onTap: () => _logout(context, closeDrawer: true),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildDrawerGradient() {
    return const BoxDecoration(
      color: Color.fromARGB(255, 5, 93, 166),
    );
  }

  Container _buildDrawerHeader(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 5, 93, 166),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text(
              'MPUZA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.name ?? 'Mpuza',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              user?.email ?? 'Rwanda • Africa • World',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (user != null)
              const Text(
                'Rwanda • Africa • World',
                style: TextStyle(color: Colors.white70, fontSize: 12),
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
  void _navigateTo(Widget screen) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  Future<void> _logout(BuildContext context, {bool closeDrawer = false}) async {
    if (closeDrawer) Navigator.pop(context);
    try {
      await context.read<AuthProvider>().logout();
    } on AuthException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
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
              'Mpuza',
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
