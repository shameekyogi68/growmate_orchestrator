import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/api_models.dart';
import '../../shared/location_picker_screen.dart';
import '../../shared/widgets.dart';
import 'package:latlong2/latlong.dart';

class CropManagerScreen extends StatefulWidget {
  const CropManagerScreen({super.key});

  @override
  State<CropManagerScreen> createState() => _CropManagerScreenState();
}

class _CropManagerScreenState extends State<CropManagerScreen> {
  List<UserCrop> _crops = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    setState(() { _loading = true; _error = null; });
    try {
      final crops = await ApiService.instance.getCrops();
      setState(() => _crops = crops);
    } on ApiException catch (e) {
      setState(() => _error = e.detail);
    } catch (_) {
      setState(() => _error = 'Could not load crops.');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.detail), backgroundColor: GrowMateTheme.dangerRed));
      }
    }
  }

  Future<void> _deleteCrop(int cropId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Crop?'),
        content: const Text('This will remove the crop from your profile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: GrowMateTheme.dangerRed))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.instance.deleteCrop(cropId);
        await _loadCrops();
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.detail), backgroundColor: GrowMateTheme.dangerRed));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrowMateTheme.backgroundCream,
      appBar: AppBar(title: const Text('My Crops')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCropSheet(context),
        backgroundColor: GrowMateTheme.harvestOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Crop',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: GrowMateTheme.primaryGreen))
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style:
                          const TextStyle(color: GrowMateTheme.textSecondary)))
              : _crops.isEmpty
                  ? const Center(
                      child: Text('No crops added yet.',
                          style: TextStyle(
                              color: GrowMateTheme.textSecondary, fontSize: 15)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _crops.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _CropTile(
                        crop: _crops[i],
                        onSetPrimary: () => _setPrimary(_crops[i].id),
                        onDelete: () => _deleteCrop(_crops[i].id),
                      ),
                    ),
    );
  }

  void _showAddCropSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddCropSheet(onAdded: _loadCrops, existingCrops: _crops),
    );
  }
}

class _CropTile extends StatelessWidget {
  final UserCrop crop;
  final VoidCallback onSetPrimary;
  final VoidCallback onDelete;

  const _CropTile(
      {required this.crop,
      required this.onSetPrimary,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GrowMateTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: GrowMateTheme.cardShadow,
        border: crop.isPrimary
            ? Border.all(color: GrowMateTheme.primaryGreen, width: 1.5)
            : null,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: crop.isPrimary
                ? GrowMateTheme.primaryGreen.withValues(alpha: 0.1)
                : GrowMateTheme.borderLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: CropIcon(
              icon: crop.icon,
              color: crop.isPrimary
                  ? GrowMateTheme.primaryGreen
                  : GrowMateTheme.textSecondary,
              size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(crop.cropName,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: GrowMateTheme.textPrimary)),
              if (crop.isPrimary) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: GrowMateTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Primary',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: GrowMateTheme.primaryGreen)),
                ),
              ]
            ]),
            if (crop.variety != null)
              Text(crop.variety!,
                  style: const TextStyle(
                      fontSize: 12, color: GrowMateTheme.textSecondary)),
            if (crop.sowingDate != null)
              Text('Sown: ${crop.sowingDate}',
                  style: const TextStyle(
                      fontSize: 11, color: GrowMateTheme.textSecondary)),
          ]),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'primary') onSetPrimary();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            if (!crop.isPrimary)
              const PopupMenuItem(
                  value: 'primary',
                  child: Text('Set as Primary')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: GrowMateTheme.dangerRed))),
          ],
        ),
      ]),
    );
  }
}

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
      setState(() {
        _selectedLocation = LatLng(lat, lon);
      });
      _fetchSupportedCrops();
    } else {
      _fetchSupportedCrops();
    }
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
      final seasonalGroups = supportedMap['seasonal_groups'] as List<dynamic>? ?? [];
      
      final existingNames = widget.existingCrops.map((e) => '${e.cropName}-${e.variety ?? "General"}').toSet();

      for (var group in seasonalGroups) {
        final List<dynamic> crops = group['crops'] ?? [];
        for (var c in crops) {
          final identity = c['identity'] as Map<String, dynamic>?;
          final cName = identity?['crop_name']?.toString() ?? c['name']?.toString() ?? '';
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
          _error = 'Discovery taking longer than expected. Please wait a moment and retry.';
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
    setState(() { _saving = true; _error = null; });
    try {
      final identity = _selectedCropData?['identity'] as Map<String, dynamic>?;
      await ApiService.instance.addCrop(
        cropName: identity?['crop_name']?.toString() ?? _selectedCropData?['name']?.toString() ?? 'Unknown',
        variety: identity?['variety_name']?.toString(),
        sowingDate: _sowingCtrl.text,
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
        isPrimary: _isPrimary,
      );
      widget.onAdded();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.detail);
    } catch (_) {
      setState(() => _error = 'Save failed.');
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
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: GrowMateTheme.borderLight, borderRadius: BorderRadius.circular(2))),
          ),
          
          if (_selectedCropData == null) ...[
            const Text('Discover Verified Crops',
                style: TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (_detectedPlace != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: GrowMateTheme.primaryGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GrowMateTheme.primaryGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: GrowMateTheme.primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Location: $_detectedPlace',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: GrowMateTheme.textPrimary)),
                    ),
                    const Icon(Icons.verified, color: GrowMateTheme.primaryGreen, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: _loadingCrops
                  ? _buildLoadingState()
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: GrowMateTheme.dangerRed)))
                      : _allCropsData.isEmpty
                          ? const Center(child: Text("No crops found for this region.", style: TextStyle(color: GrowMateTheme.textSecondary)))
                          : _buildCropList(),
            ),
          ] else
             Expanded(child: _buildCropDetails()),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: GrowMateTheme.primaryGreen, strokeWidth: 3)),
        const SizedBox(height: 20),
        Text('Analyzing soil & weather for ${_detectedPlace ?? "your area"}...', 
            style: const TextStyle(fontSize: 14, color: GrowMateTheme.primaryGreen, fontWeight: FontWeight.w500)),
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
        final cropName = identity?['crop_name']?.toString() ?? c['name']?.toString() ?? 'Crop';
        final variety = identity?['variety_name']?.toString() ?? 'General';
        final category = identity?['crop_category']?.toString() ?? '';
        final statusColor = _parseColor(c['status_color']?.toString(), GrowMateTheme.primaryGreen);
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
                color: GrowMateTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                border: Border.all(color: GrowMateTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: CropIcon(icon: c['icon']?.toString(), color: statusColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$cropName - $variety', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (category.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(category, style: const TextStyle(fontSize: 11, color: GrowMateTheme.textSecondary)),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text(c['status_label']?.toString() ?? 'Verified', 
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                                ),
                                if (showPrice)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                    child: Text('Price: $price', 
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: GrowMateTheme.textSecondary, size: 20),
                    ],
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags.map((t) {
                        final tagText = t['text']?.toString() ?? '';
                        final tColor = _parseColor(t['color']?.toString(), GrowMateTheme.textSecondary);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(border: Border.all(color: tColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
                          child: Text(tagText, style: TextStyle(fontSize: 10, color: tColor)),
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
    final cropName = identity?['crop_name']?.toString() ?? c['name']?.toString() ?? 'Crop';
    final variety = identity?['variety_name']?.toString() ?? 'General';
    final statusColor = _parseColor(c['status_color']?.toString(), GrowMateTheme.primaryGreen);
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
    if (isValid(avgYield)) metricCards.add(_buildMetricCard(Icons.agriculture, 'Yield/Acre', avgYield!));
    if (isValid(duration)) metricCards.add(_buildMetricCard(Icons.timer_outlined, 'Duration', duration!));
    if (isValid(tempRange)) metricCards.add(_buildMetricCard(Icons.thermostat_outlined, 'Temp Range', tempRange!));
    if (isValid(rainRange)) metricCards.add(_buildMetricCard(Icons.water_drop_outlined, 'Rainfall', rainRange!));
    if (isValid(seedRate)) metricCards.add(_buildMetricCard(Icons.eco_outlined, 'Seed Rate', seedRate!));
    if (isValid(germination)) metricCards.add(_buildMetricCard(Icons.grass, 'Germination', germination!));
    
    final metricRows = <Widget>[];
    for (int i = 0; i < metricCards.length; i += 2) {
      if (i + 1 < metricCards.length) {
        metricRows.add(Row(children: [metricCards[i], const SizedBox(width: 12), metricCards[i + 1]]));
      } else {
        metricRows.add(Row(children: [metricCards[i], const SizedBox(width: 12), const Expanded(child: SizedBox.shrink())]));
      }
      metricRows.add(const SizedBox(height: 12));
    }
    
    final showMarket = isValid(marketName) && isValid(minPrice) && isValid(maxPrice);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedCropData = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('$cropName ($variety)', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: statusColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['status_label']?.toString() ?? 'Notice', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                              const SizedBox(height: 4),
                              Text(desc, style: const TextStyle(fontSize: 13, height: 1.4)),
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
                          const Icon(Icons.storefront, color: Color(0xFF9333EA)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Local Market Pricing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9333EA))),
                                const SizedBox(height: 2),
                                Text('$marketName: $minPrice - $maxPrice', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GrowMateTheme.textPrimary)),
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
                        color: GrowMateTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GrowMateTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.layers_outlined, size: 20, color: GrowMateTheme.textSecondary),
                          const SizedBox(width: 12),
                          const Text('Ideal Soil:', style: TextStyle(fontSize: 12, color: GrowMateTheme.textSecondary)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(soilType!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GrowMateTheme.textPrimary))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text('Sowing Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                            colorScheme: const ColorScheme.light(primary: GrowMateTheme.primaryGreen, onPrimary: Colors.white),
                          ),
                          child: child!,
                        ),
                      );
                      if (date != null && mounted) {
                        setState(() => _sowingCtrl.text = date.toIso8601String().split('T')[0]);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Sowing Date *',
                      hintText: 'Select when you plan to sow',
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Sowing date is mandatory' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    value: _isPrimary,
                    onChanged: (v) => setState(() => _isPrimary = v),
                    title: const Text('Set as Primary Crop', style: TextStyle(fontSize: 14)),
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
              child: Text(_error!, style: const TextStyle(color: GrowMateTheme.dangerRed, fontSize: 13)),
            ),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: GrowMateTheme.harvestOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Add to My Farm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
          color: GrowMateTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GrowMateTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: GrowMateTheme.textSecondary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: GrowMateTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GrowMateTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}

