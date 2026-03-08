import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../profile/crop_manager_screen.dart';
import '../profile/profile_screen.dart';
import '../advisory/advisory_screen.dart';
import '../advisory/crop_calendar_screen.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/localization/app_locale.dart';

/// Global key so any screen can switch tabs from outside AppShell.
final appShellKey = GlobalKey<AppShellState>();

class AppShell extends StatefulWidget {
  const AppShell({super.key}) : super();

  /// Call from anywhere to jump to a specific tab.
  static void switchTab(int index) {
    appShellKey.currentState?.switchTab(index);
  }

  @override
  AppShellState createState() => AppShellState();
}

class AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fadeCtrl;

  final List<Widget> _screens = const [
    AdvisoryScreen(),
    CropCalendarScreen(),
    CropManagerScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void switchTab(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentIndex = index);
      _fadeCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut),
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: _currentIndex,
        onTap: switchTab,
      ),
    );
  }
}

// ─── Premium Bottom Nav Bar (Swiggy/Zomato style) ───────────────────────────

class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _PremiumNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _NavTab(
                index: 0,
                currentIndex: currentIndex,
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: L.tr('Advisory', 'ಸಲಹೆ'),
                onTap: onTap,
              ),
              _NavTab(
                index: 1,
                currentIndex: currentIndex,
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today_rounded,
                label: L.tr('Planner', 'ಯೋಜನೆ'),
                onTap: onTap,
              ),
              _NavTab(
                index: 2,
                currentIndex: currentIndex,
                icon: Icons.grass_outlined,
                activeIcon: Icons.grass_rounded,
                label: L.tr('My Farm', 'ನನ್ನ ಫಾರ್ಮ್'),
                onTap: onTap,
              ),
              _NavTab(
                index: 3,
                currentIndex: currentIndex,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: L.tr('Profile', 'ಪ್ರೊಫೈಲ್'),
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _NavTab({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated indicator line
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isActive ? 24 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: GrowMateTheme.primaryGreen,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Icon with smooth swap
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1.0).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey('nav-$index-$isActive'),
                size: 24,
                color: isActive
                    ? GrowMateTheme.primaryGreen
                    : const Color(0xFFB0B0B0),
              ),
            ),
            const SizedBox(height: 3),
            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? GrowMateTheme.primaryGreen
                    : const Color(0xFFB0B0B0),
                letterSpacing: 0.1,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
