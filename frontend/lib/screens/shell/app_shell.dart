import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../advisory/advisory_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/localization/app_locale.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  int _previousIndex = 0;

  static const List<Widget> _screens = [
    AdvisoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
    _slideAnim = Tween<Offset>(
      begin: index > _previousIndex
          ? const Offset(0.08, 0)
          : const Offset(-0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isKn = L.isKn;

    return Scaffold(
      body: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _slideCtrl.drive(Tween<double>(begin: 0.85, end: 1.0))
              .drive(CurveTween(curve: Curves.easeOut)),
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
        ),
      ),
      bottomNavigationBar: _GrowMateNavBar(
        currentIndex: _currentIndex,
        isKn: isKn,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _GrowMateNavBar extends StatelessWidget {
  final int currentIndex;
  final bool isKn;
  final ValueChanged<int> onTap;

  const _GrowMateNavBar({
    required this.currentIndex,
    required this.isKn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _NavItem(
                index: 0,
                currentIndex: currentIndex,
                icon: Icons.eco_outlined,
                activeIcon: Icons.eco_rounded,
                label: isKn ? 'ಸಲಹೆ' : 'Advisory',
                sublabel: isKn ? 'Farm Advisory' : 'ಕೃಷಿ ಸಲಹೆ',
                onTap: onTap,
              ),
              _NavItem(
                index: 1,
                currentIndex: currentIndex,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: isKn ? 'ಪ್ರೊಫೈಲ್' : 'Profile',
                sublabel: isKn ? 'My Account' : 'ನನ್ನ ಖಾತೆ',
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
  final String sublabel;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.sublabel,
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
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? GrowMateTheme.primaryGreen.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  key: ValueKey(isSelected),
                  color: isSelected
                      ? GrowMateTheme.primaryGreen
                      : GrowMateTheme.textSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? GrowMateTheme.primaryGreen
                      : GrowMateTheme.textSecondary,
                  letterSpacing: 0.1,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
