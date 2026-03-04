import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/api_models.dart';
import '../../shared/location_picker_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late TextEditingController _nameCtrl;
  String _language = 'en';
  LatLng? _selectedLocation;
  String? _phoneNumber;

  // PIN change
  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _showPinSection = false;
  bool _savingPin = false;
  String? _pinError;

  // Track unsaved changes
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _nameCtrl.addListener(_markChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_markChanged);
    _nameCtrl.dispose();
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasUnsavedChanges && mounted) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ApiService.instance.getProfile();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _nameCtrl.text = p.fullName ?? '';
        _language = p.language;
        _phoneNumber = p.phoneNumber ?? prefs.getString('phone_number');
        if (p.latitude != null && p.longitude != null) {
          _selectedLocation = LatLng(p.latitude!, p.longitude!);
        }
        _hasUnsavedChanges = false;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await ApiService.instance.clearAuthData();
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      if (mounted) setState(() => _error = e.detail);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not load profile. · ಪ್ರೊಫೈಲ್ ಲೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    // Validate name
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty. · ಹೆಸರು ಖಾಲಿ ಇರಬಾರದು.');
      return;
    }
    if (name.length < 2) {
      setState(() => _error =
          'Name must be at least 2 characters. · ಹೆಸರು ಕನಿಷ್ಠ 2 ಅಕ್ಷರಗಳಾಗಿರಬೇಕು.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.instance.updateProfile(
        fullName: name,
        language: _language,
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', _language);
      if (_selectedLocation != null) {
        await prefs.setDouble('latitude', _selectedLocation!.latitude);
        await prefs.setDouble('longitude', _selectedLocation!.longitude);
      }
      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile saved · ಪ್ರೊಫೈಲ್ ಉಳಿಸಲಾಗಿದೆ'),
            backgroundColor: GrowMateTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.detail);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Save failed. Check your connection. · ಉಳಿಸಲು ವಿಫಲ.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePin() async {
    final newPin = _newPinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    setState(() {
      _pinError = null;
    });

    if (newPin.length != 4) {
      setState(() => _pinError =
          'New PIN must be 4 digits. · ಹೊಸ ಪಿನ್ 4 ಅಂಕಿಗಳಾಗಿರಬೇಕು.');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
      setState(() => _pinError =
          'PIN must contain only digits. · ಪಿನ್ ಅಂಕಿಗಳನ್ನು ಮಾತ್ರ ಹೊಂದಿರಬೇಕು.');
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _pinError =
          'PINs do not match. · ಪಿನ್‌ಗಳು ಹೊಂದಿಕೆಯಾಗಿಲ್ಲ.');
      return;
    }

    setState(() => _savingPin = true);

    try {
      await ApiService.instance.updateProfile(quickPin: newPin);
      if (mounted) {
        setState(() {
          _showPinSection = false;
          _newPinCtrl.clear();
          _confirmPinCtrl.clear();
          _currentPinCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('🔒 PIN updated · ಪಿನ್ ನವೀಕರಿಸಲಾಗಿದೆ'),
            backgroundColor: GrowMateTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _pinError = e.detail);
    } catch (_) {
      if (mounted) {
        setState(() => _pinError =
            'PIN update failed. · ಪಿನ್ ನವೀಕರಣ ವಿಫಲವಾಗಿದೆ.');
      }
    } finally {
      if (mounted) setState(() => _savingPin = false);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: GrowMateTheme.dangerRed, size: 24),
            SizedBox(width: 10),
            Text('Sign Out · ಸೈನ್ ಔಟ್'),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out? You will need your phone number and PIN to sign back in.\n\nನೀವು ಸೈನ್ ಔಟ್ ಮಾಡಲು ಖಚಿತವಾಗಿದ್ದೀರಾ? ಮರಳಿ ಸೈನ್ ಇನ್ ಮಾಡಲು ನಿಮ್ಮ ಫೋನ್ ನಂಬರ್ ಮತ್ತು ಪಿನ್ ಅಗತ್ಯವಿದೆ.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel · ರದ್ದುಮಾಡಿ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: GrowMateTheme.dangerRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out · ಸೈನ್ ಔಟ್',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ApiService.instance.clearAuthData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrowMateTheme.backgroundCream,
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: GrowMateTheme.primaryGreen),
                  SizedBox(height: 16),
                  Text('Loading profile... · ಪ್ರೊಫೈಲ್ ಲೋಡ್ ಆಗುತ್ತಿದೆ...',
                      style: TextStyle(
                          color: GrowMateTheme.textSecondary, fontSize: 13)),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // --- Premium Header ---
                SliverAppBar(
                  expandedHeight: 220,
                  floating: false,
                  pinned: true,
                  backgroundColor: GrowMateTheme.primaryGreenDark,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                          gradient: GrowMateTheme.headerGradient),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 24),
                            // Avatar
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/icons/Farmer_Avatar.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _nameCtrl.text.isNotEmpty
                                  ? _nameCtrl.text
                                  : 'Farmer · ರೈತ',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (_phoneNumber != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _phoneNumber!,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color:
                                      Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    title: const Text('My Profile · ನನ್ನ ಪ್ರೊಫೈಲ್',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    titlePadding: const EdgeInsetsDirectional.only(
                        start: 20, bottom: 14),
                  ),
                  actions: [
                    if (_hasUnsavedChanges)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: TextButton(
                          onPressed: _saving ? null : _saveProfile,
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withValues(
                                            alpha: 0.4)),
                                  ),
                                  child: const Text('Save · ಉಳಿಸಿ',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                ),
                        ),
                      ),
                  ],
                ),

                // --- Body ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error banner
                        if (_error != null) ...[
                          _ErrorBanner(
                              message: _error!, onDismiss: () => setState(() => _error = null)),
                          const SizedBox(height: 16),
                        ],

                        // ═══ PERSONAL INFO SECTION ═══
                        _buildSectionCard(
                          title: 'Personal Details · ವೈಯಕ್ತಿಕ ವಿವರಗಳು',
                          icon: Icons.person_outline,
                          children: [
                            // Full Name
                            const _FieldLabel(
                                'Full Name · ಪೂರ್ಣ ಹೆಸರು'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameCtrl,
                              textCapitalization:
                                  TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText:
                                    'Enter your name · ನಿಮ್ಮ ಹೆಸರನ್ನು ನಮೂದಿಸಿ',
                                prefixIcon: const Icon(
                                    Icons.badge_outlined,
                                    color: GrowMateTheme.primaryGreen),
                                filled: true,
                                fillColor: GrowMateTheme.surfaceWhite,
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color:
                                            GrowMateTheme.borderLight)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color:
                                            GrowMateTheme.primaryGreen,
                                        width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Phone Number (Display only)
                            const _FieldLabel(
                                'Phone Number · ದೂರವಾಣಿ ಸಂಖ್ಯೆ'),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: GrowMateTheme.borderLight
                                    .withValues(alpha: 0.4),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color: GrowMateTheme.borderLight),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone_outlined,
                                      color:
                                          GrowMateTheme.textSecondary,
                                      size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    _phoneNumber ?? 'Not available',
                                    style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            GrowMateTheme.textPrimary),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: GrowMateTheme.skyBlue
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Text('Verified · ಪರಿಶೀಲಿಸಲಾಗಿದೆ',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                GrowMateTheme.skyBlue)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Language
                            const _FieldLabel(
                                'Language · ಭಾಷೆ'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: _language,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                    Icons.translate_outlined,
                                    color: GrowMateTheme.primaryGreen),
                                filled: true,
                                fillColor: GrowMateTheme.surfaceWhite,
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color:
                                            GrowMateTheme.borderLight)),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'en',
                                    child: Text('English')),
                                DropdownMenuItem(
                                    value: 'kn',
                                    child:
                                        Text('ಕನ್ನಡ (Kannada)')),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _language = v ?? 'en';
                                  _hasUnsavedChanges = true;
                                });
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ═══ LOCATION SECTION ═══
                        _buildSectionCard(
                          title: 'Farm Location · ಫಾರ್ಮ್ ಸ್ಥಳ',
                          icon: Icons.location_on_outlined,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final loc = await Navigator.of(context)
                                    .push<LatLng>(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          LocationPickerScreen(
                                              initialLocation:
                                                  _selectedLocation)),
                                );
                                if (loc != null && mounted) {
                                  setState(() {
                                    _selectedLocation = loc;
                                    _hasUnsavedChanges = true;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _selectedLocation != null
                                      ? GrowMateTheme.primaryGreen
                                          .withValues(alpha: 0.05)
                                      : GrowMateTheme.surfaceWhite,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color: _selectedLocation != null
                                          ? GrowMateTheme.primaryGreen
                                              .withValues(alpha: 0.3)
                                          : GrowMateTheme.borderLight),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: GrowMateTheme
                                            .primaryGreen
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(
                                                10),
                                      ),
                                      child: const Icon(
                                          Icons.map_outlined,
                                          color: GrowMateTheme
                                              .primaryGreen,
                                          size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedLocation == null
                                                ? 'Set Farm Location · ಫಾರ್ಮ್ ಸ್ಥಳ ಹೊಂದಿಸಿ'
                                                : 'Location Set · ಸ್ಥಳ ಹೊಂದಿಸಲಾಗಿದೆ',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: _selectedLocation !=
                                                      null
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
                                                : 'Tap to open map · ನಕ್ಷೆ ತೆರೆಯಲು ಟ್ಯಾಪ್ ಮಾಡಿ',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: GrowMateTheme
                                                    .textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        color: GrowMateTheme
                                            .textSecondary),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ═══ SECURITY SECTION — PIN CHANGE ═══
                        _buildSectionCard(
                          title:
                              'Security · ಭದ್ರತೆ',
                          icon: Icons.shield_outlined,
                          children: [
                            if (!_showPinSection)
                              InkWell(
                                borderRadius:
                                    BorderRadius.circular(12),
                                onTap: () => setState(
                                    () => _showPinSection = true),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color:
                                        GrowMateTheme.surfaceWhite,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color: GrowMateTheme
                                            .borderLight),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.lock_outline,
                                          color: GrowMateTheme
                                              .harvestOrange,
                                          size: 20),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Change PIN · ಪಿನ್ ಬದಲಾಯಿಸಿ',
                                          style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 14,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: GrowMateTheme
                                                  .textPrimary),
                                        ),
                                      ),
                                      Icon(Icons.chevron_right,
                                          color: GrowMateTheme
                                              .textSecondary),
                                    ],
                                  ),
                                ),
                              )
                            else ...[
                              // New PIN
                              const _FieldLabel(
                                  'New PIN · ಹೊಸ ಪಿನ್'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _newPinCtrl,
                                obscureText: true,
                                keyboardType:
                                    TextInputType.number,
                                maxLength: 4,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly
                                ],
                                decoration: InputDecoration(
                                  hintText: '••••',
                                  prefixIcon: const Icon(
                                      Icons.lock_outline,
                                      color: GrowMateTheme
                                          .harvestOrange),
                                  counterText: '',
                                  filled: true,
                                  fillColor:
                                      GrowMateTheme.surfaceWhite,
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide.none),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: GrowMateTheme
                                              .borderLight)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: GrowMateTheme
                                              .harvestOrange,
                                          width: 1.5)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Confirm PIN
                              const _FieldLabel(
                                  'Confirm PIN · ಪಿನ್ ಖಚಿತಪಡಿಸಿ'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _confirmPinCtrl,
                                obscureText: true,
                                keyboardType:
                                    TextInputType.number,
                                maxLength: 4,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly
                                ],
                                decoration: InputDecoration(
                                  hintText: '••••',
                                  prefixIcon: const Icon(
                                      Icons.lock_reset_outlined,
                                      color: GrowMateTheme
                                          .harvestOrange),
                                  counterText: '',
                                  filled: true,
                                  fillColor:
                                      GrowMateTheme.surfaceWhite,
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide.none),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: GrowMateTheme
                                              .borderLight)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: GrowMateTheme
                                              .harvestOrange,
                                          width: 1.5)),
                                ),
                              ),
                              if (_pinError != null) ...[
                                const SizedBox(height: 8),
                                Text(_pinError!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: GrowMateTheme
                                            .dangerRed)),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _showPinSection = false;
                                          _pinError = null;
                                          _newPinCtrl.clear();
                                          _confirmPinCtrl.clear();
                                          _currentPinCtrl.clear();
                                        });
                                      },
                                      style:
                                          OutlinedButton.styleFrom(
                                        shape:
                                            RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            12)),
                                      ),
                                      child: const Text(
                                          'Cancel · ರದ್ದುಮಾಡಿ'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _savingPin
                                          ? null
                                          : _changePin,
                                      style:
                                          ElevatedButton.styleFrom(
                                        backgroundColor:
                                            GrowMateTheme
                                                .harvestOrange,
                                        shape:
                                            RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                            12)),
                                      ),
                                      child: _savingPin
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                      color: Colors
                                                          .white,
                                                      strokeWidth:
                                                          2),
                                            )
                                          : const Text(
                                              'Update · ನವೀಕರಿಸಿ',
                                              style: TextStyle(
                                                  color: Colors
                                                      .white,
                                                  fontWeight:
                                                      FontWeight
                                                          .w600)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ═══ CROP SECTION ═══
                        _buildSectionCard(
                          title: 'My Farm · ನನ್ನ ಫಾರ್ಮ್',
                          icon: Icons.grass_outlined,
                          children: [
                            if (_profile?.activeCrop != null) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: GrowMateTheme.primaryGreen
                                      .withValues(alpha: 0.05),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color: GrowMateTheme
                                          .primaryGreen
                                          .withValues(alpha: 0.2)),
                                ),
                                child: Row(children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: GrowMateTheme
                                          .primaryGreen
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(
                                              10),
                                    ),
                                    child: const Icon(
                                        Icons.eco_outlined,
                                        color: GrowMateTheme
                                            .primaryGreen,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        const Text(
                                            'Active Crop · ಸಕ್ರಿಯ ಬೆಳೆ',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: GrowMateTheme
                                                    .textSecondary)),
                                        Text(
                                            _profile!.activeCrop!,
                                            style: const TextStyle(
                                                fontFamily:
                                                    'Inter',
                                                fontSize: 15,
                                                fontWeight:
                                                    FontWeight
                                                        .w600,
                                                color: GrowMateTheme
                                                    .textPrimary)),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        Navigator.of(context)
                                            .pushNamed('/crops'),
                                    child: Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 10,
                                          vertical: 5),
                                      decoration: BoxDecoration(
                                        color: GrowMateTheme
                                            .primaryGreen
                                            .withValues(
                                                alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(
                                                8),
                                      ),
                                      child: const Text(
                                          'Change · ಬದಲಾಯಿಸಿ',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: GrowMateTheme
                                                  .primaryGreen,
                                              fontWeight:
                                                  FontWeight
                                                      .w600)),
                                    ),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    Navigator.of(context)
                                        .pushNamed('/crops'),
                                icon: const Icon(
                                    Icons.grass_outlined),
                                label: const Text(
                                    'Manage My Crops · ನನ್ನ ಬೆಳೆಗಳನ್ನು ನಿರ್ವಹಿಸಿ'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              12)),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ═══ SAVE BUTTON (prominent) ═══
                        if (_hasUnsavedChanges) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _saving ? null : _saveProfile,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                          CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                  : const Icon(Icons.save_outlined,
                                      color: Colors.white),
                              label: const Text(
                                  'Save Changes · ಬದಲಾವಣೆಗಳನ್ನು ಉಳಿಸಿ',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    GrowMateTheme.primaryGreen,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14)),
                                elevation: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ═══ SIGN OUT ═══
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout,
                                color: GrowMateTheme.dangerRed),
                            label: const Text(
                                'Sign Out · ಸೈನ್ ಔಟ್',
                                style: TextStyle(
                                    color:
                                        GrowMateTheme.dangerRed,
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                              side: const BorderSide(
                                  color: GrowMateTheme.dangerRed),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // App version
                        Center(
                          child: Text(
                            'GrowMate v1.0.0 · Made for Udupi Farmers 🌾',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: GrowMateTheme.textSecondary
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: GrowMateTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GrowMateTheme.primaryGreen
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    color: GrowMateTheme.primaryGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GrowMateTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: GrowMateTheme.textSecondary,
            letterSpacing: 0.3));
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GrowMateTheme.dangerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: GrowMateTheme.dangerRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: GrowMateTheme.dangerRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: GrowMateTheme.dangerRed, fontSize: 12)),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                color: GrowMateTheme.dangerRed, size: 16),
          ),
        ],
      ),
    );
  }
}
