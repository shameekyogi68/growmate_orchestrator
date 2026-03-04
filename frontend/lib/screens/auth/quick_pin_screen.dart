import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import 'package:growmate_frontend/core/localization/app_locale.dart';

class QuickPinScreen extends StatefulWidget {
  const QuickPinScreen({super.key});

  @override
  State<QuickPinScreen> createState() => _QuickPinScreenState();
}

class _QuickPinScreenState extends State<QuickPinScreen>
    with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  String _pin = '';
  bool _loading = false;
  String? _error;
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
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_pin.length < 4) setState(() => _pin += digit);
    if (_pin.length == 4 && _phoneCtrl.text.length >= 10) _submit();
  }

  void _removeDigit() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _submit() async {
    if (_phoneCtrl.text.trim().length < 10 || _pin.length != 4) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.instance.quickLogin(
        phoneNumber: _phoneCtrl.text.trim(),
        pin: _pin,
      );
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
      debugPrint('API Error: ${e.detail}');
      setState(() {
        _error = L.tr('Oops! Something went wrong. Let\'s try again.',
            'ಕ್ಷಮಿಸಿ! ಏನೋ ತಪ್ಪಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.');
        _pin = '';
      });
    } catch (_) {
      setState(() {
        _error = L.tr(
            'Connection failed.', 'ಸಂಪರ್ಕ ವಿಫಲವಾಗಿದೆ.');
        _pin = '';
      });
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
            child: Column(
              children: [
                const SizedBox(height: 16),
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _backButton(context),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ── Icon ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pin_rounded,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                Text(L.tr('Quick PIN Login', 'ತ್ವರಿತ ಪಿನ್ ಲಾಗಿನ್'),
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                    L.tr('Enter your phone and 4-digit PIN',
                        'ನಿಮ್ಮ ಫೋನ್ ಮತ್ತು 4-ಅಂಕಿಯ ಪಿನ್ ನಮೂದಿಸಿ'),
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7))),
                const SizedBox(height: 32),
                // ── Bottom card ──
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F6FA),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        // Phone field
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: GrowMateTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                L.tr('Phone Number', 'ದೂರವಾಣಿ ಸಂಖ್ಯೆ'),
                            labelStyle: TextStyle(
                                fontFamily: 'Inter',
                                color: GrowMateTheme.textSecondary),
                            prefixIcon: Icon(Icons.phone_outlined,
                                color: GrowMateTheme.primaryGreen,
                                size: 20),
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: const Color(0xFFE8E8E8)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: GrowMateTheme.primaryGreen,
                                  width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // PIN dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            4,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              width: i < _pin.length ? 20 : 16,
                              height: i < _pin.length ? 20 : 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < _pin.length
                                    ? GrowMateTheme.primaryGreen
                                    : const Color(0xFFE8E8E8),
                                boxShadow: i < _pin.length
                                    ? [
                                        BoxShadow(
                                          color: GrowMateTheme.primaryGreen
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: GrowMateTheme.harvestOrange
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: GrowMateTheme.harvestOrange
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              Icon(Icons.info_outline,
                                  color: GrowMateTheme.harvestOrange,
                                  size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: GrowMateTheme.harvestOrange,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 28),
                        if (_loading)
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                                color: GrowMateTheme.primaryGreen,
                                strokeWidth: 3),
                          )
                        else
                          _PinPad(
                              onDigit: _addDigit, onDelete: _removeDigit),
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
        child: const Icon(Icons.arrow_back_ios_new,
            color: Colors.white, size: 18),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  final Function(String) onDigit;
  final VoidCallback onDelete;
  const _PinPad({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final digits = [
      '1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: digits.map((d) {
        if (d.isEmpty) return const SizedBox();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: d == '⌫' ? onDelete : () => onDigit(d),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: d == '⌫'
                    ? Icon(Icons.backspace_outlined,
                        size: 20, color: GrowMateTheme.textSecondary)
                    : Text(d,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: GrowMateTheme.textPrimary,
                        )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
