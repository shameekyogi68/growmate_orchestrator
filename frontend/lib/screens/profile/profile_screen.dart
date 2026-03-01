import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/api_models.dart';

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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await ApiService.instance.getProfile();
      setState(() {
        _profile = p;
        _nameCtrl.text = p.fullName ?? '';
        _language = p.language;
      });
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await ApiService.instance.clearAuthData();
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      setState(() => _error = e.detail);
    } catch (_) {
      setState(() => _error = 'Could not load profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ApiService.instance.updateProfile(
        fullName: _nameCtrl.text.trim(),
        language: _language,
      );
      // Persist language locally for advisory calls
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', _language);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated'), backgroundColor: GrowMateTheme.successGreen),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.detail);
    } catch (_) {
      setState(() => _error = 'Save failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.instance.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrowMateTheme.backgroundCream,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GrowMateTheme.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: GrowMateTheme.headerGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (_nameCtrl.text.isNotEmpty
                                  ? _nameCtrl.text[0]
                                  : '?')
                              .toUpperCase(),
                          style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name field
                  const _SectionLabel('Full Name'),
                  const SizedBox(height: 8),
                  TextField(
                    
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Your name',
                      prefixIcon: Icon(Icons.person_outline),
                      filled: true,
                      fillColor: GrowMateTheme.surfaceWhite,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Language
                  const _SectionLabel('Language'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _language,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.translate_outlined),
                      filled: true,
                      fillColor: GrowMateTheme.surfaceWhite,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'kn', child: Text('ಕನ್ನಡ (Kannada)')),
                    ],
                    onChanged: (v) => setState(() => _language = v ?? 'en'),
                  ),
                  const SizedBox(height: 16),

                  // Active crop info (read-only, sourced from backend)
                  if (_profile?.activeCrop != null) ...[
                    const _SectionLabel('Active Crop'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: GrowMateTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GrowMateTheme.borderLight),
                      ),
                      child: Row(children: [
                        const Icon(Icons.grass_outlined,
                            color: GrowMateTheme.primaryGreen, size: 20),
                        const SizedBox(width: 10),
                        Text(_profile!.activeCrop!,
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: GrowMateTheme.textPrimary)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushNamed('/crops'),
                          child: const Text('Change',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: GrowMateTheme.primaryGreen,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: GrowMateTheme.dangerRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: GrowMateTheme.dangerRed, fontSize: 12)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Crop Manager link
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/crops'),
                    icon: const Icon(Icons.grass_outlined),
                    label: const Text('Manage My Crops'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Logout
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: GrowMateTheme.dangerRed),
                    label: const Text('Sign Out',
                        style: TextStyle(color: GrowMateTheme.dangerRed)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: GrowMateTheme.dangerRed),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: GrowMateTheme.textSecondary,
            letterSpacing: 0.5));
  }
}
