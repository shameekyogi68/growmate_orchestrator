import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import '../../shared/location_picker_screen.dart';
import 'package:latlong2/latlong.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _obscurePin = true;
  String _language = 'en';
  LatLng? _selectedLocation;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      setState(() => _errorMessage = 'Please set your farm location within Udupi District.');
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
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
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
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Spacer(),
                          const Icon(Icons.eco_rounded,
                              color: Colors.white, size: 28),
                          const SizedBox(width: 8),
                          const Text('GrowMate',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 24),
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
                              const Text('Create Account',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: GrowMateTheme.textPrimary)),
                              const SizedBox(height: 4),
                              const Text('Set up your farmer profile',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: GrowMateTheme.textSecondary)),
                              const SizedBox(height: 24),
                              TextFormField(
                                
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number *',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  counterText: '',
                                ),
                                validator: (v) => (v == null || v.length < 10)
                                    ? 'Enter valid phone number'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const SizedBox(height: 14),
                              TextFormField(
                                
                                controller: _pinCtrl,
                                obscureText: _obscurePin,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                decoration: InputDecoration(
                                  labelText: '4-Digit PIN *',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  counterText: '',
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePin
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined),
                                    onPressed: () => setState(() =>
                                        _obscurePin = !_obscurePin),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.length != 4) {
                                    return 'PIN must be exactly 4 digits';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                value: _language,
                                decoration: const InputDecoration(
                                  labelText: 'Language',
                                  prefixIcon: Icon(Icons.translate_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'en', child: Text('English')),
                                  DropdownMenuItem(
                                      value: 'kn', child: Text('ಕನ್ನಡ (Kannada)')),
                                ],
                                onChanged: (v) =>
                                    setState(() => _language = v ?? 'en'),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: GrowMateTheme.borderLight),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.location_on_outlined, color: GrowMateTheme.primaryGreen),
                                  title: Text(_selectedLocation == null ? 'Set Farm Location' : 'Location Selected'),
                                  subtitle: _selectedLocation != null 
                                      ? Text('${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}')
                                      : const Text('Tap to open map'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    final loc = await Navigator.of(context).push<LatLng>(
                                      MaterialPageRoute(builder: (_) => LocationPickerScreen(initialLocation: _selectedLocation)),
                                    );
                                    if (loc != null) setState(() => _selectedLocation = loc);
                                  },
                                ),
                              ),
                              // Quick PIN field removed, merged to top
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: GrowMateTheme.dangerRed
                                        .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: GrowMateTheme.dangerRed
                                            .withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: GrowMateTheme.dangerRed),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  
                                  onPressed: _loading ? null : _register,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2),
                                        )
                                      : const Text('Create Account'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Already have an account? ',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: GrowMateTheme.textSecondary)),
                                  GestureDetector(
                                    onTap: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Sign In',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: GrowMateTheme.primaryGreen)),
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
    );
  }
}
