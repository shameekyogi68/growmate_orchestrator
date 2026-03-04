import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../advisory/advisory_screen.dart';
import '../profile/crop_manager_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/localization/app_locale.dart';

/// Global key so any screen can switch tabs from outside AppShell.
final appShellKey = GlobalKey<AppShellState>();

class AppShell extends StatefulWidget {
  const AppShell({super.key}) : super();

  /// Call this from anywhere to jump to a specific tab.
  static void switchTab(int index) {
    appShellKey.currentState?.switchTab(index);
  }

  @override
  AppShellState createState() => AppShellState();
}

class AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final List<Widget> _screens = const [
    AdvisoryScreen(),
    CropManagerScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.value = 1.0; // start fully visible
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void switchTab(int index) {
    if (index == _currentIndex) return;
    _animCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentIndex = index);
      _animCtrl.forward();
    });
    HapticFeedback.selectionClick();
  }

  void _onTabTapped(int index) => switchTab(index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: _GrowMateNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ─── Premium Bottom Navigation Bar ───────────────────────────────────────────

class _GrowMateNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _GrowMateNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              _NavItem(
                index: 0,
                currentIndex: currentIndex,
                icon: Icons.eco_outlined,
                activeIcon: Icons.eco_rounded,
                label: L.tr('Advisory', 'ಸಲಹೆ'),
                onTap: onTap,
              ),
              _NavItem(
                index: 1,
                currentIndex: currentIndex,
                icon: Icons.grass_outlined,
                activeIcon: Icons.grass_rounded,
                label: L.tr('My Crops', 'ನನ್ನ ಬೆಳೆ'),
                onTap: onTap,
              ),
              _NavItem(
                index: 2,
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

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? GrowMateTheme.primaryGreen.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated dot indicator above icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: isSelected ? 4 : 0,
                height: isSelected ? 4 : 0,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: GrowMateTheme.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween<double>(begin: 0.7, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey(isSelected),
                  color: isSelected
                      ? GrowMateTheme.primaryGreen
                      : GrowMateTheme.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? GrowMateTheme.primaryGreen
                      : GrowMateTheme.textSecondary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
