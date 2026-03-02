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

  // No longer pre-fetching health here — the splash screen handles it
  runApp(const GrowMateApp());
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
      routes: {
        '/':           (_) => const SplashScreen(),
        '/login':      (_) => const LoginScreen(),
        '/register':   (_) => const RegisterScreen(),
        '/quick-login':(_) => const QuickPinScreen(),
        '/home':       (_) => const AppShell(),
        '/crops':      (_) => const CropManagerScreen(),
      },
    );
  }
}
