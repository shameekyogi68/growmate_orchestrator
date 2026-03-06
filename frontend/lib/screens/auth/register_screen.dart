import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/notification_service.dart';
import '../../shared/location_picker_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:growmate_frontend/core/localization/app_locale.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _obscurePin = true;
  String _language = 'en';
  LatLng? _selectedLocation;
  bool _loading = false;
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
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      setState(
        () => _errorMessage = L.tr(
          'Please set your farm location within Udupi District.',
          'ದಯವಿಟ್ಟು ಉಡುಪಿ ಜಿಲ್ಲೆಯೊಳಗೆ ನಿಮ್ಮ ಫಾರ್ಮ್ ಸ್ಥಳವನ್ನು ಹೊಂದಿಸಿ.',
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ApiService.instance.register(
        phoneNumber: _phoneCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
        language: _language,
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
        quickPin: _pinCtrl.text.trim(),
      );

      // Update FCM token immediately after registration
      final fcmToken = await NotificationService().getToken();
      if (fcmToken != null) {
        await ApiService.instance.updateFcmToken(fcmToken);
      }

      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
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
                      children: [
                        const SizedBox(height: 20),
                        // ── Header ──
                        Row(
                          children: [
                            _backButton(context),
                            const Spacer(),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/icons/logo.png',
                                width: 28,
                                height: 28,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'GrowMate',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // ── Register Card ──
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
                                  L.tr('Create Account', 'ಖಾತೆ ತೆರೆಯಿರಿ'),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: GrowMateTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  L.tr(
                                    'Set up your farmer profile',
                                    'ನಿಮ್ಮ ರೈತ ಪ್ರೊಫೈಲ್ ಅನ್ನು ಹೊಂದಿಸಿ',
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: GrowMateTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _premiumField(
                                  controller: _phoneCtrl,
                                  label: L.tr(
                                    'Phone Number *',
                                    'ದೂರವಾಣಿ ಸಂಖ್ಯೆ *',
                                  ),
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
                                const SizedBox(height: 14),
                                _premiumField(
                                  controller: _nameCtrl,
                                  label: L.tr('Full Name', 'ಪೂರ್ಣ ಹೆಸರು'),
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 14),
                                _premiumField(
                                  controller: _pinCtrl,
                                  label: L.tr(
                                    '4-Digit PIN *',
                                    '4-ಅಂಕಿಯ ಪಿನ್ *',
                                  ),
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
                                          'PIN must be exactly 4 digits',
                                          'ಪಿನ್ ಸರಿಯಾಗಿ 4 ಅಂಕಿಗಳಿರಬೇಕು',
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                // Language dropdown
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE8E8E8),
                                    ),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    value: _language,
                                    decoration: InputDecoration(
                                      labelText: L.tr('Language', 'ಭಾಷೆ'),
                                      labelStyle: TextStyle(
                                        fontFamily: 'Inter',
                                        color: GrowMateTheme.textSecondary,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.translate_outlined,
                                        color: GrowMateTheme.primaryGreen,
                                        size: 20,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: GrowMateTheme.textPrimary,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'en',
                                        child: Text('English'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'kn',
                                        child: Text('ಕನ್ನಡ'),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _language = v ?? 'en'),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Location picker tile
                                GestureDetector(
                                  onTap: () async {
                                    final loc = await Navigator.of(context)
                                        .push<LatLng>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                LocationPickerScreen(
                                                  initialLocation:
                                                      _selectedLocation,
                                                ),
                                          ),
                                        );
                                    if (loc != null) {
                                      setState(() => _selectedLocation = loc);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _selectedLocation != null
                                            ? GrowMateTheme.primaryGreen
                                                  .withValues(alpha: 0.5)
                                            : const Color(0xFFE8E8E8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: GrowMateTheme.primaryGreen
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.location_on_outlined,
                                            color: GrowMateTheme.primaryGreen,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedLocation == null
                                                    ? L.tr(
                                                        'Set Farm Location *',
                                                        'ಫಾರ್ಮ್ ಸ್ಥಳವನ್ನು ಹೊಂದಿಸಿ *',
                                                      )
                                                    : L.tr(
                                                        'Location Selected ✓',
                                                        'ಸ್ಥಳವನ್ನು ಆಯ್ಕೆ ✓',
                                                      ),
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color:
                                                      _selectedLocation != null
                                                      ? GrowMateTheme
                                                            .primaryGreen
                                                      : GrowMateTheme
                                                            .textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _selectedLocation != null
                                                    ? '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                                                    : L.tr(
                                                        'Tap to open map',
                                                        'ನಕ್ಷೆಯನ್ನು ತೆರೆಯಲು ಟ್ಯಾಪ್ ಮಾಡಿ',
                                                      ),
                                                style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontSize: 12,
                                                  color: GrowMateTheme
                                                      .textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: GrowMateTheme.textSecondary,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: GrowMateTheme.harvestOrange
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: GrowMateTheme.harvestOrange
                                            .withValues(alpha: 0.3),
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
                                            _errorMessage!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  GrowMateTheme.harvestOrange,
                                              fontFamily: 'Inter',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _register,
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
                                            L.tr(
                                              'Create Account',
                                              'ಖಾತೆ ತೆರೆಯಿರಿ',
                                            ),
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      L.tr(
                                        'Already have an account? ',
                                        'ಈಗಾಗಲೇ ಖಾತೆ ಹೊಂದಿದ್ದೀರಾ? ',
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        color: GrowMateTheme.textSecondary,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      child: Text(
                                        L.tr('Sign In', 'ಸೈನ್ ಇನ್'),
                                        style: TextStyle(
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
                        const SizedBox(height: 32),
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

  Widget _backButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 18,
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
