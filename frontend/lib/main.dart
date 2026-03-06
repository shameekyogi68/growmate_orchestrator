import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/growmate_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/quick_pin_screen.dart';
import 'screens/shell/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (wrapped in try-catch to allow offline development)
  try {
    await Firebase.initializeApp();
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GrowMateApp());
}

/// Smooth fade + slide-up page transition for all routes
class _SlideUpRoute extends PageRouteBuilder {
  final Widget page;
  _SlideUpRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.04);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          final fadeTween = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).chain(CurveTween(curve: curve));
          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: SlideTransition(
              position: animation.drive(tween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
      );
}

class GrowMateApp extends StatelessWidget {
  const GrowMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrowMate — Smart Farming',
      debugShowCheckedModeBanner: false,
      theme: GrowMateTheme.lightTheme,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget? page;
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/login':
            page = const LoginScreen();
            break;
          case '/register':
            page = const RegisterScreen();
            break;
          case '/quick-login':
            page = const QuickPinScreen();
            break;
          case '/home':
            // Use the global key so AppShell.switchTab() works from anywhere
            page = AppShell(key: appShellKey);
            break;
          default:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
        }
        return _SlideUpRoute(page: page);
      },
    );
  }
}
