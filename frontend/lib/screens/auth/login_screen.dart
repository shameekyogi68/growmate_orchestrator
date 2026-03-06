import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/localization/app_locale.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePin = true;
  String? _errorMessage;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ApiService.instance.login(
        phoneNumber: _phoneCtrl.text.trim(),
        pin: _pinCtrl.text.trim(),
      );

      // Update FCM token immediately after login
      final fcmToken = await NotificationService().getToken();
      if (fcmToken != null) {
        await ApiService.instance.updateFcmToken(fcmToken);
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on ApiException catch (e) {
      debugPrint('API Error: ${e.detail}');
      setState(
        () => _errorMessage = L.tr(
          'Oops! Something went wrong. Let\'s try again.',
          'ಕ್ಷಮಿಸಿ! ಏನೋ ತಪ್ಪಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
        ),
      );
    } catch (_) {
      setState(
        () => _errorMessage = L.tr(
          'Connection failed. Check your network.',
          'ಸಂಪರ್ಕ ವಿಫಲವಾಗಿದೆ. ನಿಮ್ಮ ನೆಟ್‌ವರ್ಕ್ ಪರಿಶೀಲಿಸಿ.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48),
                        // ── Logo & tagline ──
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'assets/icons/logo.png',
                                width: 48,
                                height: 48,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'GrowMate',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              L.tr(
                                'Intelligent Farming Platform',
                                'ಬುದ್ಧಿವಂತ ಕೃಷಿ ವೇದಿಕೆ',
                              ),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),

                        // ── Login Card ──
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  L.tr('Welcome back', 'ಮತ್ತೆ ಸ್ವಾಗತ'),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: GrowMateTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  L.tr(
                                    'Sign in to your farm dashboard',
                                    'ನಿಮ್ಮ ಕೃಷಿ ಖಾತೆಗೆ ಲಾಗಿನ್ ಆಗಿ',
                                  ),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: GrowMateTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _premiumField(
                                  controller: _phoneCtrl,
                                  label: L.tr('Phone Number', 'ದೂರವಾಣಿ ಸಂಖ್ಯೆ'),
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (v) => (v == null || v.length < 10)
                                      ? L.tr(
                                          'Enter valid phone number',
                                          'ಮಾನ್ಯವಾದ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ',
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                _premiumField(
                                  controller: _pinCtrl,
                                  label: L.tr('4-Digit PIN', '4-ಅಂಕಿಯ ಪಿನ್'),
                                  icon: Icons.lock_outline,
                                  obscure: _obscurePin,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePin
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: GrowMateTheme.textSecondary,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePin = !_obscurePin,
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.length != 4)
                                      ? L.tr(
                                          'Enter 4-digit PIN',
                                          '4-ಅಂಕಿಯ ಪಿನ್ ನಮೂದಿಸಿ',
                                        )
                                      : null,
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  _ErrorBanner(message: _errorMessage!),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          GrowMateTheme.harvestOrange,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            L.tr('Sign In', 'ಸೈನ್ ಇನ್'),
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      L.tr(
                                        "Don't have an account? ",
                                        "ಖಾತೆ ಇಲ್ಲವೇ? ",
                                      ),
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: GrowMateTheme.textSecondary,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.of(
                                        context,
                                      ).pushNamed('/register'),
                                      child: Text(
                                        L.tr('Register', 'ನೋಂದಣಿ'),
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: GrowMateTheme.primaryGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _premiumField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: GrowMateTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          color: GrowMateTheme.textSecondary,
        ),
        prefixIcon: Icon(icon, color: GrowMateTheme.primaryGreen, size: 20),
        suffixIcon: suffixIcon,
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFE8E8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: GrowMateTheme.primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: GrowMateTheme.harvestOrange),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GrowMateTheme.harvestOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GrowMateTheme.harvestOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: GrowMateTheme.harvestOrange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: GrowMateTheme.harvestOrange,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
