import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
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
        password: _passwordCtrl.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.detail);
    } catch (_) {
      setState(() => _errorMessage = 'Connection failed. Check your network.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: GrowMateTheme.headerGradient),
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
                        const _Logo(),
                        const SizedBox(height: 48),
                        _LoginCard(
                          formKey: _formKey,
                          phoneCtrl: _phoneCtrl,
                          passwordCtrl: _passwordCtrl,
                          obscurePassword: _obscurePassword,
                          onToggleObscure: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                          errorMessage: _errorMessage,
                          loading: _loading,
                          onLogin: _login,
                          onGoRegister: () =>
                              Navigator.of(context).pushNamed('/register'),
                          onQuickPin: () =>
                              Navigator.of(context).pushNamed('/quick-login'),
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.eco_rounded, color: Colors.white, size: 48),
        SizedBox(height: 12),
        Text(
          'GrowMate',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Intelligent Farming Platform',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Colors.white70,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final VoidCallback onGoRegister;
  final VoidCallback onQuickPin;

  const _LoginCard({
    required this.formKey,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.loading,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onGoRegister,
    required this.onQuickPin,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GrowMateTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: GrowMateTheme.elevatedShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: GrowMateTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sign in to your farm dashboard',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: GrowMateTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
                counterText: '',
              ),
              validator: (v) =>
                  (v == null || v.length < 10) ? 'Enter valid phone number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              
              controller: passwordCtrl,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Password required' : null,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 14),
              _ErrorBanner(message: errorMessage!),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                
                onPressed: loading ? null : onLogin,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: GrowMateTheme.borderLight)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or',
                      style: TextStyle(color: GrowMateTheme.textSecondary, fontSize: 12)),
                ),
                Expanded(child: Divider(color: GrowMateTheme.borderLight)),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              
              onPressed: onQuickPin,
              icon: const Icon(Icons.pin_outlined, size: 18),
              label: const Text('Quick PIN Login'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account? ",
                    style: TextStyle(
                        fontSize: 13, color: GrowMateTheme.textSecondary)),
                GestureDetector(
                  onTap: onGoRegister,
                  child: const Text(
                    'Register',
                    style: TextStyle(
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
        color: GrowMateTheme.dangerRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GrowMateTheme.dangerRed.withOpacity(0.3)),
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
