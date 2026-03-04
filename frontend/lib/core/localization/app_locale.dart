import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight localisation helper for GrowMate.
///
/// Usage:
///   L.tr('Hello', 'ನಮಸ್ಕಾರ')  →  returns the correct string based on saved preference
///   L.isKn                     →  true if Kannada is selected
///   L.setLang('kn')            →  switch language at runtime
///
/// Call [L.load()] once at app startup (e.g. in SplashScreen or main).
class L {
  L._();

  static String _lang = 'en';

  /// Current language code ('en' or 'kn').
  static String get currentLang => _lang;

  /// Convenience check for Kannada.
  static bool get isKn => _lang == 'kn';

  /// Load the saved language from SharedPreferences.
  /// Call this once at startup before building screens.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('language') ?? 'en';
  }

  /// Switch language at runtime (e.g. from profile screen dropdown).
  /// Also persists to disk.
  static Future<void> setLang(String lang) async {
    _lang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
  }

  /// Returns the correct translation.
  /// [en] — English text, [kn] — Kannada text.
  static String tr(String en, String kn) {
    return _lang == 'kn' ? kn : en;
  }
}
