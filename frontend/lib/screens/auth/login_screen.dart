import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
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
        vsync: this, duration: const Duration(milliseconds: 600));
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
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on ApiException catch (e) {
      debugPrint('API Error: ${e.detail}');
      setState(() => _errorMessage = L.tr('Oops! Something went wrong. Let\'s try again.', 'ಕ್ಷಮಿಸಿ! ಏನೋ ತಪ್ಪಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.'));
    } catch (_) {
      setState(() => _errorMessage =
          L.tr('Connection failed. Check your network.', 'ಸಂಪರ್ಕ ವಿಫಲವಾಗಿದೆ. ನಿಮ್ಮ ನೆಟ್‌ವರ್ಕ್ ಪರಿಶೀಲಿಸಿ.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: GrowMateTheme.headerGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: CustomScrollView(
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
                            Image.asset('assets/icons/logo.png',
                                width: 48, height: 48),
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
                              L.tr('Intelligent Farming Platform',
                                  'ಬುದ್ಧಿವಂತ ಕೃಷಿ ವೇದಿಕೆ'),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),

                        // ── Login Card ──
                        Container(
                          decoration: BoxDecoration(
                            color: GrowMateTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: GrowMateTheme.elevatedShadow,
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
                                  L.tr('Sign in to your farm dashboard',
                                      'ನಿಮ್ಮ ಕೃಷಿ ಖಾತೆಗೆ ಲಾಗಿನ್ ಆಗಿ'),
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: GrowMateTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  decoration: InputDecoration(
                                    labelText: L.tr(
                                        'Phone Number', 'ದೂರವಾಣಿ ಸಂಖ್ಯೆ'),
                                    prefixIcon:
                                        const Icon(Icons.phone_outlined),
                                    counterText: '',
                                  ),
                                  validator: (v) =>
                                      (v == null || v.length < 10)
                                          ? L.tr('Enter valid phone number',
                                              'ಮಾನ್ಯವಾದ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ')
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _pinCtrl,
                                  obscureText: _obscurePin,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  decoration: InputDecoration(
                                    labelText: L.tr(
                                        '4-Digit PIN', '4-ಅಂಕಿಯ ಪಿನ್'),
                                    prefixIcon:
                                        const Icon(Icons.lock_outline),
                                    counterText: '',
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePin
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined),
                                      onPressed: () => setState(
                                          () => _obscurePin = !_obscurePin),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.length != 4)
                                          ? L.tr('Enter 4-digit PIN',
                                              '4-ಅಂಕಿಯ ಪಿನ್ ನಮೂದಿಸಿ')
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
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(L.tr(
                                            'Sign In', 'ಸೈನ್ ಇನ್')),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      L.tr("Don't have an account? ",
                                          "ಖಾತೆ ಇಲ್ಲವೇ? "),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color:
                                              GrowMateTheme.textSecondary),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.of(context)
                                          .pushNamed('/register'),
                                      child: Text(
                                        L.tr('Register', 'ನೋಂದಣಿ'),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              GrowMateTheme.primaryGreen,
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
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GrowMateTheme.dangerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: GrowMateTheme.dangerRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: GrowMateTheme.dangerRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: GrowMateTheme.dangerRed,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
