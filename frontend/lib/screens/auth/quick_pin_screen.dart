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

class _QuickPinScreenState extends State<QuickPinScreen> {
  final _phoneCtrl = TextEditingController();
  String _pin = '';
  bool _loading = false;
  String? _error;

  void _addDigit(String digit) {
    if (_pin.length < 4) setState(() => _pin += digit);
    if (_pin.length == 4 && _phoneCtrl.text.length >= 10) _submit();
  }

  void _removeDigit() {
    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_phoneCtrl.text.trim().length < 10 || _pin.length != 4) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.instance.quickLogin(
        phoneNumber: _phoneCtrl.text.trim(),
        pin: _pin,
      );
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
      setState(() { _error = e.detail; _pin = ''; });
    } catch (_) {
      setState(() { _error = L.tr('Connection failed.', 'ಸಂಪರ್ಕ ವಿಫಲವಾಗಿದೆ.'); _pin = ''; });
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
          child: Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Icon(Icons.pin_rounded, color: Colors.white70, size: 52),
              const SizedBox(height: 16),
              Text(L.tr('Quick PIN Login', 'ತ್ವರಿತ ಪಿನ್ ಲಾಗಿನ್'), style: TextStyle(
                fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 8),
              Text(L.tr('Enter your phone and 4-digit PIN', 'ನಿಮ್ಮ ಫೋನ್ ಮತ್ತು 4-ಅಂಕಿಯ ಪಿನ್ ನಮೂದಿಸಿ'), style: TextStyle(
                fontFamily: 'Inter', fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 32),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: GrowMateTheme.backgroundCream,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: L.tr('Phone Number', 'ದೂರವಾಣಿ ಸಂಖ್ಯೆ'),
                          prefixIcon: Icon(Icons.phone_outlined),
                          filled: true,
                          fillColor: GrowMateTheme.surfaceWhite,
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _pin.length
                                ? GrowMateTheme.primaryGreen
                                : GrowMateTheme.borderLight,
                          ),
                        )),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: GrowMateTheme.dangerRed, fontSize: 13)),
                      ],
                      const SizedBox(height: 28),
                      if (_loading)
                        const CircularProgressIndicator(color: GrowMateTheme.primaryGreen)
                      else
                        _PinPad(onDigit: _addDigit, onDelete: _removeDigit),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final digits = ['1','2','3','4','5','6','7','8','9','','0','⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: digits.map((d) {
        if (d.isEmpty) return const SizedBox();
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: d == '⌫' ? onDelete : () => onDigit(d),
          child: Container(
            decoration: BoxDecoration(
              color: GrowMateTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              boxShadow: GrowMateTheme.cardShadow,
            ),
            child: Center(
              child: Text(d, style: TextStyle(
                fontFamily: 'Inter',
                fontSize: d == '⌫' ? 18 : 22,
                fontWeight: FontWeight.w600,
                color: GrowMateTheme.textPrimary,
              )),
            ),
          ),
        );
      }).toList(),
    );
  }
}
