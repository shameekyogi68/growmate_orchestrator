import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/api_models.dart';
import '../../shared/location_picker_screen.dart';
import '../../shared/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:growmate_frontend/core/localization/app_locale.dart';

class CropManagerScreen extends StatefulWidget {
  const CropManagerScreen({super.key});

  @override
  State<CropManagerScreen> createState() => _CropManagerScreenState();
}

class _CropManagerScreenState extends State<CropManagerScreen>
    with TickerProviderStateMixin {
  List<UserCrop> _crops = [];
  bool _loading = true;
  String? _error;
  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadCrops();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCrops() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final crops = await ApiService.instance.getCrops();
      setState(() => _crops = crops);
      _staggerCtrl.forward(from: 0.0);
    } on ApiException catch (e) {
      debugPrint('API Error: ${e.detail}');
      setState(
        () => _error = L.tr(
          'Oops! Something went wrong. Let\'s try again.',
          'ಕ್ಷಮಿಸಿ! ಏನೋ ತಪ್ಪಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
        ),
      );
    } catch (_) {
      setState(
        () => _error = L.tr(
          'Could not load crops.',
          'ಬೆಳೆಗಳನ್ನು ಲೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setPrimary(int cropId) async {
    try {
      await ApiService.instance.setPrimaryCrop(cropId);
      await _loadCrops();
    } on ApiException catch (e) {
      if (mounted) {
        debugPrint('API Error: ${e.detail}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L.tr(
                'Oops! Something went wrong. Let\'s try again.',
                'ಕ್ಷಮಿಸಿ! ಏನೋ ತಪ್ಪಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
              ),
            ),
            backgroundColor: GrowMateTheme.harvestOrange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteCrop(int cropId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.delete_outline,
              color: GrowMateTheme.harvestOrange,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              L.tr('Delete Crop?', 'ಬೆಳೆಯನ್ನು ಅಳಿಸುವುದೇ?'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          L.tr(
            'This will remove the crop from your profile.',
            'ಇದು ನಿಮ್ಮ ಪ್ರೊಫೈಲ್‌ನಿಂದ ಬೆಳೆಯನ್ನು ತೆಗೆದುಹಾಕುತ್ತದೆ.',
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
              backgroundColor: GrowMateTheme.harvestOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              L.tr('Delete', 'ಅಳಿಸಿ'),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.instance.deleteCrop(cropId);
        await _loadCrops();
      } on ApiException catch (e) {
        if (mounted) {
          debugPrint('API Error: ${e.detail}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L.tr(
                  'Oops! Something went wrong. Let\'s try again.',
                  'ಕ್ಷಮಿಸಿ! ಏನೋ ತಪ್ಪಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
                ),
              ),
              backgroundColor: GrowMateTheme.harvestOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
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
      body: _loading ? _buildLoadingState() : _buildContent(),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddCropSheet(context),
              backgroundColor: GrowMateTheme.harvestOrange,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                L.tr('Add Crop', 'ಬೆಳೆ ಸೇರಿಸಿ'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ),
    );
  }

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
            L.tr('Loading crops...', 'ಬೆಳೆಗಳನ್ನು ಲೋಡ್ ಮಾಡಲಾಗುತ್ತಿದೆ...'),
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

  Widget _buildContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  _buildErrorBanner(),
                  const SizedBox(height: 12),
                ],
                if (_crops.isEmpty)
                  _buildEmptyState()
                else ...[
                  // Summary row
                  _buildSummaryRow(),
                  const SizedBox(height: 16),
                  // Crop cards
                  ...List.generate(_crops.length, (i) {
                    final interval = _crops.length > 1
                        ? i / _crops.length
                        : 0.0;
                    final endInterval = _crops.length > 1
                        ? (i + 1) / _crops.length
                        : 1.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildStaggeredCard(
                        interval * 0.6,
                        endInterval * 0.6 + 0.3,
                        _CropCard(
                          crop: _crops[i],
                          onSetPrimary: () => _setPrimary(_crops[i].id),
                          onDelete: () => _deleteCrop(_crops[i].id),
                        ),
                      ),
                    );
                  }),
                ],
              ],
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
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/icons/Crops_icon.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                L.tr('My Crops', 'ನನ್ನ ಬೆಳೆಗಳು'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                L.tr(
                  'Manage your farm crops',
                  'ನಿಮ್ಮ ಕೃಷಿ ಬೆಳೆಗಳನ್ನು ನಿರ್ವಹಿಸಿ',
                ),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Summary Row ──────────────────────────────────────────────────────────

  Widget _buildSummaryRow() {
    final primaryCrop = _crops.where((c) => c.isPrimary).toList();
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          _summaryChip(
            icon: Icons.grass_rounded,
            value: '${_crops.length}',
            label: L.tr('Total', 'ಒಟ್ಟು'),
            color: GrowMateTheme.primaryGreen,
          ),
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFFE8E8E8),
          ),
          _summaryChip(
            icon: Icons.star_rounded,
            value: primaryCrop.isNotEmpty ? primaryCrop.first.cropName : '—',
            label: L.tr('Primary', 'ಪ್ರಾಥಮಿಕ'),
            color: GrowMateTheme.harvestOrange,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: GrowMateTheme.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: GrowMateTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: GrowMateTheme.primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.eco_outlined,
                size: 48,
                color: GrowMateTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              L.tr('No crops added yet', 'ಇನ್ನೂ ಯಾವುದೇ ಬೆಳೆಗಳನ್ನು ಸೇರಿಸಿಲ್ಲ'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: GrowMateTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              L.tr(
                'Tap the button below to add your first crop',
                'ನಿಮ್ಮ ಮೊದಲ ಬೆಳೆಯನ್ನು ಸೇರಿಸಲು ಕೆಳಗಿನ ಬಟನ್ ಒತ್ತಿ',
              ),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: GrowMateTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error Banner ─────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GrowMateTheme.harvestOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: GrowMateTheme.harvestOrange.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: GrowMateTheme.harvestOrange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: GrowMateTheme.harvestOrange,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _error = null),
            child: Icon(
              Icons.close,
              color: GrowMateTheme.harvestOrange,
              size: 16,
            ),
          ),
        ],
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

  void _showAddCropSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _AddCropSheet(onAdded: _loadCrops, existingCrops: _crops),
      ),
    );
  }
}

// ─── Crop Card ──────────────────────────────────────────────────────────────

class _CropCard extends StatelessWidget {
  final UserCrop crop;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;

  const _CropCard({
    required this.crop,
    required this.onSetPrimary,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        border: crop.isPrimary
            ? Border.all(
                color: GrowMateTheme.primaryGreen.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: crop.isPrimary
                  ? GrowMateTheme.primaryGreen.withValues(alpha: 0.10)
                  : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CropIcon(
              icon: crop.icon,
              color: crop.isPrimary
                  ? GrowMateTheme.primaryGreen
                  : GrowMateTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        crop.cropName,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: GrowMateTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (crop.isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: GrowMateTheme.primaryGreen.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          L.tr('Primary', 'ಪ್ರಾಥಮಿಕ'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: GrowMateTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (crop.variety != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    crop.variety!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: GrowMateTheme.textSecondary,
                    ),
                  ),
                ],
                if (crop.sowingDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: GrowMateTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        L.tr(
                          'Sown: ${crop.sowingDate}',
                          'ಬಿತ್ತನೆ: ${crop.sowingDate}',
                        ),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: GrowMateTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'primary') onSetPrimary();
              if (v == 'delete') onDelete();
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            icon: Icon(
              Icons.more_vert_rounded,
              color: GrowMateTheme.textSecondary,
            ),
            itemBuilder: (_) => [
              if (!crop.isPrimary)
                PopupMenuItem(
                  value: 'primary',
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: GrowMateTheme.harvestOrange,
                      ),
                      const SizedBox(width: 8),
                      Text(L.tr('Set as Primary', 'ಪ್ರಾಥಮಿಕವಾಗಿ ಹೊಂದಿಸಿ')),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: GrowMateTheme.harvestOrange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      L.tr('Delete', 'ಅಳಿಸಿ'),
                      style: TextStyle(color: GrowMateTheme.harvestOrange),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Add Crop Sheet (existing logic, matching theme) ────────────────────────

class _AddCropSheet extends StatefulWidget {
  final VoidCallback onAdded;
  final List<UserCrop> existingCrops;
  const _AddCropSheet({required this.onAdded, required this.existingCrops});

  @override
  State<_AddCropSheet> createState() => _AddCropSheetState();
}

class _AddCropSheetState extends State<_AddCropSheet> {
  final _formKey = GlobalKey<FormState>();
  final _sowingCtrl = TextEditingController();
  LatLng? _selectedLocation;
  bool _isPrimary = false;
  bool _saving = false;
  bool _loadingCrops = false;
  String? _error;
  String? _detectedPlace;

  List<Map<String, dynamic>> _allCropsData = [];
  Map<String, dynamic>? _selectedCropData;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  Future<void> _initDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('latitude');
    final lon = prefs.getDouble('longitude');
    if (lat != null && lon != null && mounted) {
      setState(() => _selectedLocation = LatLng(lat, lon));
    }
    _fetchSupportedCrops();
  }

  Future<void> _fetchSupportedCrops() async {
    setState(() {
      _loadingCrops = true;
      _error = null;
      _selectedCropData = null;
      _allCropsData = [];
    });
    try {
      final now = DateTime.now();
      final dateStr = now.toIso8601String().split('T')[0];
      final supportedMap = await ApiService.instance.getSupportedCrops(
        latitude: _selectedLocation?.latitude ?? 13.8,
        longitude: _selectedLocation?.longitude ?? 74.6,
        date: dateStr,
      );
      final String? locationName = supportedMap['location']?.toString();
      final List<Map<String, dynamic>> flattened = [];
      final seasonalGroups =
          supportedMap['seasonal_groups'] as List<dynamic>? ?? [];
      final existingNames = widget.existingCrops
          .map((e) => '${e.cropName}-${e.variety ?? "General"}')
          .toSet();
      for (var group in seasonalGroups) {
        final List<dynamic> crops = group['crops'] ?? [];
        for (var c in crops) {
          final identity = c['identity'] as Map<String, dynamic>?;
          final cName =
              identity?['crop_name']?.toString() ?? c['name']?.toString() ?? '';
          final cVariety = identity?['variety_name']?.toString() ?? 'General';
          final uniqueKey = '$cName-$cVariety';
          if (!existingNames.contains(uniqueKey)) {
            flattened.add(c as Map<String, dynamic>);
          }
        }
      }
      if (mounted) {
        setState(() {
          _allCropsData = flattened;
          _detectedPlace = locationName;
          _loadingCrops = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = L.tr(
            'Discovery taking longer than expected. Please wait and retry.',
            'ಅನ್ವೇಷಣೆಗೆ ಹೆಚ್ಚು ಸಮಯ ತೆಗೆದುಕೊಳ್ಳುತ್ತಿದೆ. ದಯವಿಟ್ಟು ಕಾಯಿರಿ ಮತ್ತು ಮರುಪ್ರಯತ್ನಿಸಿ.',
          );
          _loadingCrops = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sowingCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final identity = _selectedCropData?['identity'] as Map<String, dynamic>?;
      await ApiService.instance.addCrop(
        cropName:
            identity?['crop_name']?.toString() ??
            _selectedCropData?['name']?.toString() ??
            'Unknown',
        variety: identity?['variety_name']?.toString(),
        sowingDate: _sowingCtrl.text,
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
        isPrimary: _isPrimary,
      );
      widget.onAdded();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      debugPrint('API Error: ${e.detail}');
      setState(
        () => _error = L.tr(
          'Oops! Something went wrong. Let\'s try again.',
          'ಕ್ಷಮಿಸಿ! ಏನೋ ತಪ್ಪಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
        ),
      );
    } catch (_) {
      setState(() => _error = L.tr('Save failed.', 'ಉಳಿಸಲು ವಿಫಲವಾಗಿದೆ.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _parseColor(String? colorStr, Color fallback) {
    if (colorStr == null || !colorStr.startsWith('#')) return fallback;
    try {
      return Color(int.parse(colorStr.substring(1, 7), radix: 16) + 0xFF000000);
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      height: sheetHeight,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (_selectedCropData == null) ...[
            Text(
              L.tr(
                'Discover Verified Crops',
                'ಪರಿಶೀಲಿಸಿದ ಬೆಳೆಗಳನ್ನು ಅನ್ವೇಷಿಸಿ',
              ),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: GrowMateTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (_detectedPlace != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: GrowMateTheme.primaryGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: GrowMateTheme.primaryGreen.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: GrowMateTheme.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        L.tr(
                          'Location: $_detectedPlace',
                          'ಸ್ಥಳ: $_detectedPlace',
                        ),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          color: GrowMateTheme.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.verified,
                      color: GrowMateTheme.primaryGreen,
                      size: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: _loadingCrops
                  ? _buildSheetLoading()
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(color: GrowMateTheme.harvestOrange),
                      ),
                    )
                  : _allCropsData.isEmpty
                  ? Center(
                      child: Text(
                        L.tr(
                          'No crops found for this region.',
                          'ಈ ಪ್ರದೇಶಕ್ಕೆ ಯಾವುದೇ ಬೆಳೆಗಳು ಕಂಡುಬಂದಿಲ್ಲ.',
                        ),
                        style: TextStyle(color: GrowMateTheme.textSecondary),
                      ),
                    )
                  : _buildCropList(),
            ),
          ] else
            Expanded(child: _buildCropDetails()),
        ],
      ),
    );
  }

  Widget _buildSheetLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            color: GrowMateTheme.primaryGreen,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          L.tr(
            'Analyzing soil & weather for ${_detectedPlace ?? "your area"}...',
            '${_detectedPlace ?? "ನಿಮ್ಮ ಪ್ರದೇಶಕ್ಕೆ"} ಮಣ್ಣು ಮತ್ತು ಹವಾಮಾನ ವಿಶ್ಲೇಷಣೆ...',
          ),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: GrowMateTheme.primaryGreen,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCropList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _allCropsData.length,
      itemBuilder: (ctx, i) {
        final c = _allCropsData[i];
        final identity = c['identity'] as Map<String, dynamic>?;
        final cropName =
            identity?['crop_name']?.toString() ??
            c['name']?.toString() ??
            'Crop';
        final variety = identity?['variety_name']?.toString() ?? 'General';
        final category = identity?['crop_category']?.toString() ?? '';
        final statusColor = _parseColor(
          c['status_color']?.toString(),
          GrowMateTheme.primaryGreen,
        );
        final market = c['financial_intelligence'] as Map<String, dynamic>?;
        final price = market?['modal_price']?.toString();
        final tags = c['ui_tags'] as List<dynamic>? ?? [];
        final showPrice = price != null && price != 'N/A' && price.isNotEmpty;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (i * 100)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: () => setState(() => _selectedCropData = c),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CropIcon(
                          icon: c['icon']?.toString(),
                          color: statusColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$cropName - $variety',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: GrowMateTheme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (category.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: GrowMateTheme.textSecondary,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c['status_label']?.toString() ?? 'Verified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                if (showPrice)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Price: $price',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ),
                              ],
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
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags.map((t) {
                        final tagText = t['text']?.toString() ?? '';
                        final tColor = _parseColor(
                          t['color']?.toString(),
                          GrowMateTheme.textSecondary,
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: tColor.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tagText,
                            style: TextStyle(fontSize: 10, color: tColor),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCropDetails() {
    final c = _selectedCropData!;
    final identity = c['identity'] as Map<String, dynamic>?;
    final cropName =
        identity?['crop_name']?.toString() ?? c['name']?.toString() ?? 'Crop';
    final variety = identity?['variety_name']?.toString() ?? 'General';
    final statusColor = _parseColor(
      c['status_color']?.toString(),
      GrowMateTheme.primaryGreen,
    );
    final desc = c['description']?.toString() ?? '';

    final yieldPot = c['yield_potential'] as Map<String, dynamic>?;
    final avgYield = yieldPot?['average_yield_per_acre']?.toString();

    final morph = c['morphological_characteristics'] as Map<String, dynamic>?;
    final duration = morph?['maturity_duration_range']?.toString();

    final agroInfo = c['agro_climatic_suitability'] as Map<String, dynamic>?;
    final tempRange = agroInfo?['suitable_temperature_range']?.toString();
    final rainRange = agroInfo?['suitable_rainfall_range']?.toString();
    final soilType = agroInfo?['suitable_soil_types']?.toString();

    final seedSpecs = c['seed_specifications'] as Map<String, dynamic>?;
    final seedRate = seedSpecs?['seed_rate_per_acre']?.toString();
    final germination = seedSpecs?['germination_period']?.toString();

    final market = c['financial_intelligence'] as Map<String, dynamic>?;
    final marketName = market?['market_name']?.toString();
    final minPrice = market?['min_price']?.toString();
    final maxPrice = market?['max_price']?.toString();

    bool isValid(String? val) => val != null && val != 'N/A' && val.isNotEmpty;

    final metricCards = <Widget>[];
    if (isValid(avgYield))
      metricCards.add(
        _buildMetricCard(
          Icons.agriculture,
          L.tr('Yield/Acre', 'ಇಳುವರಿ/ಎಕರೆ'),
          avgYield!,
        ),
      );
    if (isValid(duration))
      metricCards.add(
        _buildMetricCard(
          Icons.timer_outlined,
          L.tr('Duration', 'ಅವಧಿ'),
          duration!,
        ),
      );
    if (isValid(tempRange))
      metricCards.add(
        _buildMetricCard(
          Icons.thermostat_outlined,
          L.tr('Temp Range', 'ತಾಪಮಾನ'),
          tempRange!,
        ),
      );
    if (isValid(rainRange))
      metricCards.add(
        _buildMetricCard(
          Icons.water_drop_outlined,
          L.tr('Rainfall', 'ಮಳೆ'),
          rainRange!,
        ),
      );
    if (isValid(seedRate))
      metricCards.add(
        _buildMetricCard(
          Icons.eco_outlined,
          L.tr('Seed Rate', 'ಬೀಜ ದರ'),
          seedRate!,
        ),
      );
    if (isValid(germination))
      metricCards.add(
        _buildMetricCard(
          Icons.grass,
          L.tr('Germination', 'ಮೊಳಕೆಯೊಡೆಯುವಿಕೆ'),
          germination!,
        ),
      );

    final metricRows = <Widget>[];
    for (int i = 0; i < metricCards.length; i += 2) {
      if (i + 1 < metricCards.length) {
        metricRows.add(
          Row(
            children: [
              metricCards[i],
              const SizedBox(width: 12),
              metricCards[i + 1],
            ],
          ),
        );
      } else {
        metricRows.add(
          Row(
            children: [
              metricCards[i],
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        );
      }
      metricRows.add(const SizedBox(height: 12));
    }

    final showMarket =
        isValid(marketName) && isValid(minPrice) && isValid(maxPrice);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _selectedCropData = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$cropName ($variety)',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: GrowMateTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: statusColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['status_label']?.toString() ?? 'Notice',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: GrowMateTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (showMarket) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD8B4FE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.storefront,
                            color: Color(0xFF9333EA),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  L.tr(
                                    'Local Market Pricing',
                                    'ಸ್ಥಳೀಯ ಮಾರುಕಟ್ಟೆ ಬೆಲೆ',
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF9333EA),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$marketName: $minPrice - $maxPrice',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: GrowMateTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...metricRows,
                  if (isValid(soilType)) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.layers_outlined,
                            size: 20,
                            color: GrowMateTheme.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            L.tr('Ideal Soil:', 'ಮಣ್ಣಿನ ಪ್ರಕಾರ:'),
                            style: TextStyle(
                              fontSize: 12,
                              color: GrowMateTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              soilType!,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: GrowMateTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    L.tr('Sowing Details', 'ಬಿತ್ತನೆ ವಿವರಗಳು'),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GrowMateTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sowingCtrl,
                    readOnly: true,
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: GrowMateTheme.primaryGreen,
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (date != null && mounted) {
                        setState(
                          () => _sowingCtrl.text = date.toIso8601String().split(
                            'T',
                          )[0],
                        );
                      }
                    },
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: L.tr('Sowing Date *', 'ಬಿತ್ತನೆ ದಿನಾಂಕ *'),
                      hintText: L.tr(
                        'Select when you plan to sow',
                        'ಬಿತ್ತನೆ ದಿನಾಂಕ ಆಯ್ಕೆಮಾಡಿ',
                      ),
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FC),
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
                        borderSide: BorderSide(
                          color: GrowMateTheme.primaryGreen,
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? L.tr(
                            'Sowing date is mandatory',
                            'ಬಿತ್ತನೆ ದಿನಾಂಕ ಕಡ್ಡಾಯವಾಗಿದೆ',
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    value: _isPrimary,
                    onChanged: (v) => setState(() => _isPrimary = v),
                    title: Text(
                      L.tr('Set as Primary Crop', 'ಪ್ರಾಥಮಿಕ ಬೆಳೆಯಾಗಿ ಹೊಂದಿಸಿ'),
                      style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                    ),
                    activeThumbColor: GrowMateTheme.primaryGreen,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _error!,
                style: TextStyle(
                  color: GrowMateTheme.harvestOrange,
                  fontSize: 13,
                ),
              ),
            ),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: GrowMateTheme.harvestOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      L.tr('Add to My Farm', 'ನನ್ನ ಫಾರ್ಮ್‌ಗೆ ಸೇರಿಸಿ'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: GrowMateTheme.textSecondary),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: GrowMateTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: GrowMateTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
