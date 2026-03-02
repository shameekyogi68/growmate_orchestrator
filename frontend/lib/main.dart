import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/growmate_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/quick_pin_screen.dart';
import 'screens/shell/app_shell.dart';
import 'screens/profile/crop_manager_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GrowMateApp());
}

/// Smooth slide-up page transition for all routes
class _SlideUpRoute extends PageRouteBuilder {
  final Widget page;
  _SlideUpRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.05);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
            return FadeTransition(
              opacity: animation.drive(fadeTween),
              child: SlideTransition(position: animation.drive(tween), child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
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
        final routes = <String, Widget>{
          '/':            const SplashScreen(),
          '/login':       const LoginScreen(),
          '/register':    const RegisterScreen(),
          '/quick-login': const QuickPinScreen(),
          '/home':        const AppShell(),
          '/crops':       const CropManagerScreen(),
        };
        final page = routes[settings.name];
        if (page != null) {
          // Splash has no transition
          if (settings.name == '/') {
            return MaterialPageRoute(builder: (_) => page);
          }
          return _SlideUpRoute(page: page);
        }
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      },
    );
  }
}
