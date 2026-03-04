import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/api_models.dart';
import '../../shared/location_picker_screen.dart';
import '../shell/app_shell.dart';
import 'package:growmate_frontend/core/localization/app_locale.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  late TextEditingController _nameCtrl;
  String _language = 'en';
  LatLng? _selectedLocation;

  // PIN change
  final _currentPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _showPinSection = false;
  bool _savingPin = false;
  String? _pinError;

  // Track unsaved changes
  bool _hasUnsavedChanges = false;

  // Staggered animation
  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _nameCtrl.addListener(_markChanged);
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_markChanged);
    _nameCtrl.dispose();
    _currentPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    _staggerCtrl.dispose();
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
      if (!mounted) return;
      setState(() {
        _profile = p;
        _nameCtrl.text = p.fullName ?? '';
        _language = p.language;
        if (p.latitude != null && p.longitude != null) {
          _selectedLocation = LatLng(p.latitude!, p.longitude!);
        }
        _hasUnsavedChanges = false;
      });
      _staggerCtrl.forward();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await ApiService.instance.clearAuthData();
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      if (mounted) setState(() => _error = e.detail);
    } catch (_) {
      if (mounted) {
        setState(() => _error = L.tr(
            'Could not load profile.', 'ಪ್ರೊಫೈಲ್ ಲೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() =>
          _error = L.tr('Name cannot be empty.', 'ಹೆಸರು ಖಾಲಿ ಇರಬಾರದು.'));
      return;
    }
    if (name.length < 2) {
      setState(() => _error = L.tr(
          'Name must be at least 2 characters.',
          'ಹೆಸರು ಕನಿಷ್ಠ 2 ಅಕ್ಷರಗಳಾಗಿರಬೇಕು.'));
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
      await L.setLang(_language);
      if (_selectedLocation != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('latitude', _selectedLocation!.latitude);
        await prefs.setDouble('longitude', _selectedLocation!.longitude);
      }
      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(L.tr('✅ Profile saved', '✅ ಪ್ರೊಫೈಲ್ ಉಳಿಸಲಾಗಿದೆ')),
            backgroundColor: GrowMateTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.detail);
    } catch (_) {
      if (mounted) {
        setState(() => _error = L.tr('Save failed. Check your connection.',
            'ಉಳಿಸಲು ವಿಫಲ. ಸಂಪರ್ಕ ಪರಿಶೀಲಿಸಿ.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePin() async {
    final newPin = _newPinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();
    setState(() => _pinError = null);
    if (newPin.length != 4) {
      setState(() => _pinError = L.tr(
          'New PIN must be 4 digits.', 'ಹೊಸ ಪಿನ್ 4 ಅಂಕಿಗಳಾಗಿರಬೇಕು.'));
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) {
      setState(() => _pinError = L.tr(
          'PIN must contain only digits.', 'ಪಿನ್ ಅಂಕಿಗಳನ್ನು ಮಾತ್ರ ಹೊಂದಿರಬೇಕು.'));
      return;
    }
    if (newPin != confirmPin) {
      setState(() => _pinError =
          L.tr('PINs do not match.', 'ಪಿನ್‌ಗಳು ಹೊಂದಿಕೆಯಾಗಿಲ್ಲ.'));
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
          SnackBar(
            content: Text(L.tr('🔒 PIN updated', '🔒 ಪಿನ್ ನವೀಕರಿಸಲಾಗಿದೆ')),
            backgroundColor: GrowMateTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _pinError = e.detail);
    } catch (_) {
      if (mounted) {
        setState(() => _pinError =
            L.tr('PIN update failed.', 'ಪಿನ್ ನವೀಕರಣ ವಿಫಲವಾಗಿದೆ.'));
      }
    } finally {
      if (mounted) setState(() => _savingPin = false);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.logout, color: GrowMateTheme.dangerRed, size: 22),
          SizedBox(width: 10),
          Text(L.tr('Sign Out', 'ಸೈನ್ ಔಟ್'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          L.tr(
            'Are you sure you want to sign out? You will need your phone number and PIN to sign back in.',
            'ನೀವು ಸೈನ್ ಔಟ್ ಮಾಡಲು ಖಚಿತವಾಗಿದ್ದೀರಾ? ಮರಳಿ ಸೈನ್ ಇನ್ ಮಾಡಲು ನಿಮ್ಮ ಫೋನ್ ನಂಬರ್ ಮತ್ತು ಪಿನ್ ಅಗತ್ಯವಿದೆ.',
          ),
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L.tr('Cancel', 'ರದ್ದುಮಾಡಿ')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: GrowMateTheme.dangerRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(L.tr('Sign Out', 'ಸೈನ್ ಔಟ್'),
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

  // ── Staggered animation helper ──
  Animation<double> _staggerAnimation(double start, double end) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: _loading
          ? _buildLoadingState()
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      children: [
                        // Error banner
                        if (_error != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 12),
                        ],
                        // Personal Info
                        _buildStaggeredCard(
                          0.0,
                          0.3,
                          _buildPersonalSection(),
                        ),
                        const SizedBox(height: 12),
                        // Location
                        _buildStaggeredCard(
                          0.15,
                          0.45,
                          _buildLocationSection(),
                        ),
                        const SizedBox(height: 12),
                        // Security
                        _buildStaggeredCard(
                          0.3,
                          0.6,
                          _buildSecuritySection(),
                        ),
                        const SizedBox(height: 12),
                        // Farm / Crops
                        _buildStaggeredCard(
                          0.45,
                          0.75,
                          _buildFarmSection(),
                        ),
                        const SizedBox(height: 16),
                        // Save button
                        if (_hasUnsavedChanges)
                          _buildStaggeredCard(0.6, 0.85, _buildSaveButton()),
                        if (_hasUnsavedChanges) const SizedBox(height: 12),
                        // Logout
                        _buildStaggeredCard(
                          0.7,
                          0.95,
                          _buildLogoutButton(),
                        ),
                        const SizedBox(height: 16),
                        // version
                        FadeTransition(
                          opacity: _staggerAnimation(0.85, 1.0),
                          child: Text(
                            'GrowMate v1.0.0',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: GrowMateTheme.textSecondary
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── Loading ──────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: GrowMateTheme.primaryGreen,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            L.tr('Loading profile...', 'ಪ್ರೊಫೈಲ್ ಲೋಡ್ ಆಗುತ್ತಿದೆ...'),
            style: TextStyle(
              fontFamily: 'Inter',
              color: GrowMateTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            children: [
              // Avatar
              Hero(
                tag: 'profile-avatar',
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
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
              ),
              const SizedBox(height: 12),
              Text(
                L.tr('My Profile', 'ನನ್ನ ಪ್ರೊಫೈಲ್'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Staggered card wrapper ───────────────────────────────────────────────

  Widget _buildStaggeredCard(double start, double end, Widget child) {
    final anim = _staggerAnimation(start, end);
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }

  // ─── Section Card ─────────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: GrowMateTheme.primaryGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: GrowMateTheme.primaryGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: GrowMateTheme.textPrimary,
                )),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ─── Personal Info ────────────────────────────────────────────────────────

  Widget _buildPersonalSection() {
    return _sectionCard(
      icon: Icons.person_outline_rounded,
      title: L.tr('Personal Details', 'ವೈಯಕ್ತಿಕ ವಿವರಗಳು'),
      children: [
        _label(L.tr('Full Name', 'ಪೂರ್ಣ ಹೆಸರು')),
        const SizedBox(height: 6),
        _premiumTextField(
          controller: _nameCtrl,
          hint: L.tr('Enter your name', 'ನಿಮ್ಮ ಹೆಸರನ್ನು ನಮೂದಿಸಿ'),
          icon: Icons.badge_outlined,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        _label(L.tr('Language', 'ಭಾಷೆ')),
        const SizedBox(height: 6),
        _premiumDropdown(),
      ],
    );
  }

  // ─── Location ─────────────────────────────────────────────────────────────

  Widget _buildLocationSection() {
    final hasLoc = _selectedLocation != null;
    return _sectionCard(
      icon: Icons.location_on_outlined,
      title: L.tr('Farm Location', 'ಫಾರ್ಮ್ ಸ್ಥಳ'),
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final loc = await Navigator.of(context).push<LatLng>(
              MaterialPageRoute(
                builder: (_) => LocationPickerScreen(
                    initialLocation: _selectedLocation),
              ),
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
              color: hasLoc
                  ? GrowMateTheme.primaryGreen.withValues(alpha: 0.04)
                  : const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasLoc
                    ? GrowMateTheme.primaryGreen.withValues(alpha: 0.25)
                    : const Color(0xFFE8E8E8),
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      GrowMateTheme.primaryGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.map_outlined,
                    color: GrowMateTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLoc
                          ? L.tr('Location Set', 'ಸ್ಥಳ ಹೊಂದಿಸಲಾಗಿದೆ')
                          : L.tr(
                              'Set Farm Location', 'ಫಾರ್ಮ್ ಸ್ಥಳ ಹೊಂದಿಸಿ'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasLoc
                            ? GrowMateTheme.primaryGreen
                            : GrowMateTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLoc
                          ? '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                          : L.tr('Tap to open map',
                              'ನಕ್ಷೆ ತೆರೆಯಲು ಟ್ಯಾಪ್ ಮಾಡಿ'),
                      style: TextStyle(
                        fontSize: 12,
                        color: GrowMateTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: GrowMateTheme.textSecondary),
            ]),
          ),
        ),
      ],
    );
  }

  // ─── Security ─────────────────────────────────────────────────────────────

  Widget _buildSecuritySection() {
    return _sectionCard(
      icon: Icons.shield_outlined,
      title: L.tr('Security', 'ಭದ್ರತೆ'),
      children: [
        if (!_showPinSection)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _showPinSection = true),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Row(children: [
                Icon(Icons.lock_outline,
                    color: GrowMateTheme.harvestOrange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    L.tr('Change PIN', 'ಪಿನ್ ಬದಲಾಯಿಸಿ'),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: GrowMateTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: GrowMateTheme.textSecondary),
              ]),
            ),
          )
        else ...[
          _label(L.tr('New PIN', 'ಹೊಸ ಪಿನ್')),
          const SizedBox(height: 6),
          _premiumTextField(
            controller: _newPinCtrl,
            hint: '••••',
            icon: Icons.lock_outline,
            obscure: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            iconColor: GrowMateTheme.harvestOrange,
            focusColor: GrowMateTheme.harvestOrange,
          ),
          const SizedBox(height: 12),
          _label(L.tr('Confirm PIN', 'ಪಿನ್ ಖಚಿತಪಡಿಸಿ')),
          const SizedBox(height: 6),
          _premiumTextField(
            controller: _confirmPinCtrl,
            hint: '••••',
            icon: Icons.lock_reset_outlined,
            obscure: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            iconColor: GrowMateTheme.harvestOrange,
            focusColor: GrowMateTheme.harvestOrange,
          ),
          if (_pinError != null) ...[
            const SizedBox(height: 8),
            Text(_pinError!,
                style:
                    TextStyle(fontSize: 12, color: GrowMateTheme.dangerRed)),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _showPinSection = false;
                  _pinError = null;
                  _newPinCtrl.clear();
                  _confirmPinCtrl.clear();
                  _currentPinCtrl.clear();
                }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: GrowMateTheme.textSecondary.withValues(alpha: 0.3)),
                ),
                child: Text(L.tr('Cancel', 'ರದ್ದುಮಾಡಿ'),
                    style: TextStyle(color: GrowMateTheme.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _savingPin ? null : _changePin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GrowMateTheme.harvestOrange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _savingPin
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(L.tr('Update', 'ನವೀಕರಿಸಿ'),
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ],
      ],
    );
  }

  // ─── Farm Section ─────────────────────────────────────────────────────────

  Widget _buildFarmSection() {
    return _sectionCard(
      icon: Icons.grass_outlined,
      title: L.tr('My Farm', 'ನನ್ನ ಫಾರ್ಮ್'),
      children: [
        if (_profile?.activeCrop != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GrowMateTheme.primaryGreen.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color:
                      GrowMateTheme.primaryGreen.withValues(alpha: 0.18)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      GrowMateTheme.primaryGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.eco_outlined,
                    color: GrowMateTheme.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L.tr('Active Crop', 'ಸಕ್ರಿಯ ಬೆಳೆ'),
                        style: TextStyle(
                            fontSize: 11,
                            color: GrowMateTheme.textSecondary)),
                    Text(_profile!.activeCrop!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: GrowMateTheme.textPrimary,
                        )),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => AppShell.switchTab(0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:
                        GrowMateTheme.primaryGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(L.tr('Change', 'ಬದಲಾಯಿಸಿ'),
                      style: TextStyle(
                          fontSize: 12,
                          color: GrowMateTheme.primaryGreen,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () => AppShell.switchTab(0),
            icon: Icon(Icons.grass_outlined, size: 20),
            label: Text(L.tr(
                'Manage My Crops', 'ನನ್ನ ಬೆಳೆಗಳನ್ನು ನಿರ್ವಹಿಸಿ')),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(
                  color: GrowMateTheme.primaryGreen.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Save Button ──────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _saveProfile,
        icon: _saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
        label: Text(
          L.tr('Save Changes', 'ಬದಲಾವಣೆಗಳನ್ನು ಉಳಿಸಿ'),
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: GrowMateTheme.primaryGreen,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: Icon(Icons.logout, color: GrowMateTheme.dangerRed, size: 20),
        label: Text(
          L.tr('Sign Out', 'ಸೈನ್ ಔಟ್'),
          style: TextStyle(
              color: GrowMateTheme.dangerRed, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(
              color: GrowMateTheme.dangerRed.withValues(alpha: 0.4)),
        ),
      ),
    );
  }

  // ─── Error Banner ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GrowMateTheme.dangerRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: GrowMateTheme.dangerRed.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline,
            color: GrowMateTheme.dangerRed, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_error!,
              style: TextStyle(
                  color: GrowMateTheme.dangerRed,
                  fontSize: 12,
                  fontFamily: 'Inter')),
        ),
        GestureDetector(
          onTap: () => setState(() => _error = null),
          child: Icon(Icons.close,
              color: GrowMateTheme.dangerRed, size: 16),
        ),
      ]),
    );
  }

  // ─── Reusable Widgets ─────────────────────────────────────────────────────

  Widget _label(String text) {
    return Text(text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: GrowMateTheme.textSecondary,
          letterSpacing: 0.3,
        ));
  }

  Widget _premiumTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Color iconColor = GrowMateTheme.primaryGreen,
    Color focusColor = GrowMateTheme.primaryGreen,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: GrowMateTheme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: GrowMateTheme.textSecondary.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        counterText: '',
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: BorderSide(color: focusColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _premiumDropdown() {
    return DropdownButtonFormField<String>(
      value: _language,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: GrowMateTheme.textPrimary,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.translate_outlined,
            color: GrowMateTheme.primaryGreen, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: const Color(0xFFE8E8E8)),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'en', child: Text('English')),
        DropdownMenuItem(value: 'kn', child: Text('ಕನ್ನಡ')),
      ],
      onChanged: (v) {
        setState(() {
          _language = v ?? 'en';
          _hasUnsavedChanges = true;
        });
      },
    );
  }
}
