import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/system_ui.dart';
import '../providers/auth_provider.dart';

class AppRoutes {
  static const home = '/home';
  static const textTranslation = '/text-translation';
  static const speechTranslation = '/speech-translation';
  static const videoTranslation = '/video-translation';
  static const cameraTranslation = '/camera-translation';
  static const educationTools = '/education-tools';
  static const offlinePacks = '/offline-packs';
  static const driverMode = '/driver-mode';
  static const maps = '/maps';
  static const settings = '/settings';
}

class AppSidebarController extends ChangeNotifier {
  bool? _expandedOverride;

  bool get isExpanded => _expandedOverride ?? false;

  void toggle() {
    _expandedOverride = !isExpanded;
    notifyListeners();
  }

  void collapse() {
    if (!isExpanded) return;
    _expandedOverride = false;
    notifyListeners();
  }
}

class AppPageShell extends StatelessWidget {
  const AppPageShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebar = context.watch<AppSidebarController>();
        final expanded = sidebar.isExpanded;
        final expandedWidth = constraints.maxWidth >= 900
            ? 304.0
            : math.min(304.0, constraints.maxWidth * 0.8).toDouble();

        return AnnotatedRegion(
          value: appSystemUiOverlayStyle,
          child: ColoredBox(
            color: appSystemBarColor,
            child: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  if (expanded)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: sidebar.collapse,
                        child: const ColoredBox(color: Colors.black54),
                      ),
                    ),
                  if (expanded)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: expandedWidth,
                      child: AppSidebar(
                        expanded: true,
                        width: expandedWidth,
                        onToggle: sidebar.toggle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final sidebar = context.watch<AppSidebarController>();
    final expanded = sidebar.isExpanded;

    if (expanded) return const SizedBox.shrink();

    return Center(
      child: Material(
        color: const Color(0xFF06498E),
        borderRadius: BorderRadius.circular(5),
        child: IconButton(
          tooltip: expanded ? 'Collapse sidebar' : 'Open navigation menu',
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.menu, color: Colors.white, size: 20),
          onPressed: sidebar.toggle,
        ),
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    required this.expanded,
    required this.width,
    required this.onToggle,
    super.key,
  });

  final bool expanded;
  final double width;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _SidebarContents(
        expanded: expanded,
        onToggle: onToggle,
      ),
    );
  }
}

class _SidebarContents extends StatelessWidget {
  const _SidebarContents({
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;

  static const _backgroundColor = Color.fromARGB(255, 5, 93, 166);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Material(
      color: expanded ? _backgroundColor : Colors.transparent,
      child: ListView(
        padding: expanded ? EdgeInsets.zero : const EdgeInsets.only(top: 16),
        children: expanded
            ? [
                _header(
                  name: user?.name ?? 'Mpuza',
                  email: user?.email,
                  onToggle: onToggle,
                ),
                _item(
                  context,
                  icon: Icons.home,
                  title: 'Home',
                  route: AppRoutes.home,
                ),
                _item(
                  context,
                  icon: Icons.translate,
                  title: 'Text Translation',
                  route: AppRoutes.textTranslation,
                ),
                _item(
                  context,
                  icon: Icons.mic,
                  title: 'Speech Translation',
                  route: AppRoutes.speechTranslation,
                ),
                _item(
                  context,
                  icon: Icons.video_library,
                  title: 'Video Translation',
                  route: AppRoutes.videoTranslation,
                ),
                _item(
                  context,
                  icon: Icons.camera_alt,
                  title: 'Camera Translation',
                  route: AppRoutes.cameraTranslation,
                ),
                _item(
                  context,
                  icon: Icons.school,
                  title: 'Education Tools',
                  subtitle: 'Under Development',
                  route: AppRoutes.educationTools,
                ),
                _item(
                  context,
                  icon: Icons.offline_bolt,
                  title: 'Offline Packs',
                  subtitle: 'Under Development',
                  route: AppRoutes.offlinePacks,
                ),
                _item(
                  context,
                  icon: Icons.motorcycle,
                  title: 'Driver Mode',
                  subtitle: 'Under Development',
                  route: AppRoutes.driverMode,
                ),
                _item(
                  context,
                  icon: Icons.map,
                  title: 'Google Maps',
                  route: AppRoutes.maps,
                ),
                Divider(
                  height: 1,
                  color: Colors.white54,
                  indent: expanded ? 16 : 12,
                  endIndent: expanded ? 16 : 12,
                ),
                _item(
                  context,
                  icon: Icons.settings,
                  title: 'Settings',
                  route: AppRoutes.settings,
                ),
                _actionItem(
                  icon: Icons.info,
                  title: 'About',
                  onTap: () => _showAboutDialog(context),
                ),
              ]
            : [
                Center(
                  child: Material(
                    color: const Color(0xFF06498E),
                    borderRadius: BorderRadius.circular(5),
                    child: IconButton(
                      tooltip: 'Open navigation menu',
                      constraints:
                          const BoxConstraints.tightFor(width: 34, height: 34),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: onToggle,
                    ),
                  ),
                ),
              ],
      ),
    );
  }

  Widget _header({
    required String name,
    required String? email,
    required VoidCallback onToggle,
  }) {
    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'MPUZA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Collapse sidebar',
                  constraints:
                      const BoxConstraints.tightFor(width: 34, height: 34),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: onToggle,
                ),
              ],
            ),
            const Spacer(),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              email ?? 'Rwanda • Africa • World',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (email != null)
              const Text(
                'Rwanda • Africa • World',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    String? subtitle,
  }) {
    return _menuEntry(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => _navigateTo(context, route),
    );
  }

  Widget _actionItem({
    required IconData icon,
    required String title,
    required FutureOr<void> Function() onTap,
  }) {
    return _menuEntry(icon: icon, title: title, onTap: onTap);
  }

  Widget _menuEntry({
    required IconData icon,
    required String title,
    required FutureOr<void> Function() onTap,
    String? subtitle,
  }) {
    final item = InkWell(
      onTap: onTap,
      child: SizedBox(
        height: expanded && subtitle != null ? 64 : 52,
        child: Row(
          children: [
            SizedBox(
              width: expanded ? 56 : 72,
              child: Center(child: Icon(icon, color: Colors.white)),
            ),
            if (expanded)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (expanded) return item;
    return Tooltip(
      message: title,
      preferBelow: false,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      textStyle: const TextStyle(color: Color(0xFF17324D), fontSize: 13),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: item,
    );
  }

  void _navigateTo(BuildContext context, String route) {
    final navigator = Navigator.of(context);
    context.read<AppSidebarController>().collapse();
    if (route == AppRoutes.home) {
      navigator.pushNamedAndRemoveUntil(route, (entry) => false);
    } else {
      navigator.pushNamedAndRemoveUntil(
        route,
        (entry) => entry.isFirst,
      );
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF00A1DE),
                    Color(0xFF20603D),
                    Color(0xFFE1BD00),
                  ],
                ),
              ),
              child: const Icon(Icons.translate, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mpuza',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('Version 1.0.0', style: TextStyle(color: Colors.grey)),
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
}
