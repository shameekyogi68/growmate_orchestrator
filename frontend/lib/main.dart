import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/api_service.dart';
import 'core/theme/growmate_theme.dart';
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

  // Background warmup: Wake up Render server as early as possible
  // We don't await this so it doesn't block app launch
  ApiService.instance.getHealth().catchError((_) => {});

  final prefs = await SharedPreferences.getInstance();
  final hasToken = prefs.getString('auth_token') != null;
  runApp(GrowMateApp(hasToken: hasToken));
}

class GrowMateApp extends StatelessWidget {
  final bool hasToken;
  const GrowMateApp({required this.hasToken, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrowMate — Smart Farming',
      debugShowCheckedModeBanner: false,
      theme: GrowMateTheme.lightTheme,
      initialRoute: hasToken ? '/home' : '/login',
      routes: {
        '/login':      (_) => const LoginScreen(),
        '/register':   (_) => const RegisterScreen(),
        '/quick-login':(_) => const QuickPinScreen(),
        '/home':       (_) => const AppShell(),
        '/crops':      (_) => const CropManagerScreen(),
      },
    );
  }
}
