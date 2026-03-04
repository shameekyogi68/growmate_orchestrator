import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final List<Widget> _screens = const [
    CropManagerScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void switchTab(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    _animCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentIndex = index);
      _animCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: List.generate(2, (i) {
                final isSelected = i == _currentIndex;
                final icons = [Icons.grass_outlined, Icons.person_outline_rounded];
                final activeIcons = [Icons.grass_rounded, Icons.person_rounded];
                final labels = [
                  L.tr('My Crops', 'ನನ್ನ ಬೆಳೆ'),
                  L.tr('Profile', 'ಪ್ರೊಫೈಲ್'),
                ];

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => switchTab(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? GrowMateTheme.primaryGreen
                                .withValues(alpha: 0.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Active dot
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isSelected ? 5 : 0,
                            height: isSelected ? 5 : 0,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: const BoxDecoration(
                              color: GrowMateTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isSelected ? activeIcons[i] : icons[i],
                              key: ValueKey('$i-$isSelected'),
                              size: 24,
                              color: isSelected
                                  ? GrowMateTheme.primaryGreen
                                  : GrowMateTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? GrowMateTheme.primaryGreen
                                  : GrowMateTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
