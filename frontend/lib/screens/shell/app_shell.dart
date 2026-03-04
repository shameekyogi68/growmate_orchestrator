import 'package:flutter/material.dart';
import '../advisory/advisory_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/theme/growmate_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _screens = [
    AdvisoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: GrowMateTheme.surfaceWhite,
        indicatorColor: GrowMateTheme.primaryGreen.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: GrowMateTheme.primaryGreen),
            label: 'Advisory · ಸಲಹೆ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: GrowMateTheme.primaryGreen),
            label: 'Profile · ಪ್ರೊಫೈಲ್',
          ),
        ],
      ),
    );
  }
}
