import 'package:flutter/material.dart';
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
  // Color constants for easy maintenance
  static const Color _blueColor = Color(0xFF00A1DE);
  static const Color _greenColor = Color(0xFF20603D);
  static const Color _yellowColor = Color(0xFFE1BD00);

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
        color: Color.fromARGB(255, 33, 150, 243),
      ),
    );
  }

  // MARK: - Body
  Container _buildBody() {
    return Container(
      decoration: _buildBodyGradient(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(23.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildIconCircle(),
                const SizedBox(height: 30),
                _buildContentCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBodyGradient() {
    return const BoxDecoration(
      color: Color.fromARGB(255, 33, 150, 243),
    );
  }

  Container _buildIconCircle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTitle(),
          const SizedBox(height: 10),
          _buildLanguages(),
          const SizedBox(height: 40),
          _buildStartButton(),
          const SizedBox(height: 20),
          _buildTagline(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Text(
      'Translation Platform',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: _blueColor,
      ),
    );
  }

  Widget _buildLanguages() {
    return const Text(
      'Kinyarwanda • English • French',
      style: TextStyle(
        fontSize: 18,
        color: _greenColor,
      ),
    );
  }

  Widget _buildStartButton() {
    return ElevatedButton(
      onPressed: () => _navigateTo(const TextTranslationScreen()),
      style: ElevatedButton.styleFrom(
        backgroundColor: _blueColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
      ),
      child: const Text('Start Translating', style: TextStyle(fontSize: 18)),
    );
  }

  Widget _buildTagline() {
    return const Text(
      'For Driver\'s, Tourists, Students, and Everyone!',
      style: TextStyle(
        color: _greenColor,
        fontWeight: FontWeight.w500,
        fontSize: 14,
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

  Container _buildDrawerHeader() {
    return Container(
      height: 180,
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 5, 93, 166),
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
  void _navigateTo(Widget screen) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
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