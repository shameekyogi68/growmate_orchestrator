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
      builder: (_) => _AddCropSheet(onAdded: _loadCrops),
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
  const _AddCropSheet({required this.onAdded});

  @override
  State<_AddCropSheet> createState() => _AddCropSheetState();
}

class _AddCropSheetState extends State<_AddCropSheet> {
  final _formKey = GlobalKey<FormState>();
  final _sowingCtrl = TextEditingController();
  final _varietyCtrl = TextEditingController();
  LatLng? _selectedLocation;
  bool _isPrimary = false;
  bool _saving = false;
  bool _loadingCrops = false;
  String? _error;
  String? _detectedPlace;

  List<Map<String, dynamic>> _allCropsData = [];
  String? _selectedCropName;
  String? _selectedVariety;

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
      _selectedCropName = null;
      _selectedVariety = null;
      _allCropsData = [];
    });
    try {
      final supportedMap = await ApiService.instance.getSupportedCrops(
        latitude: _selectedLocation?.latitude,
        longitude: _selectedLocation?.longitude,
      );
      
      final String? locationName = supportedMap['location']?.toString();
      final List<Map<String, dynamic>> flattened = [];
      for (var group in groups) {
        final List<dynamic> crops = group['crops'] ?? [];
        for (var c in crops) {
          flattened.add(c as Map<String, dynamic>);
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
    _varietyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      await ApiService.instance.addCrop(
        cropName: _selectedCropName!,
        variety: _selectedVariety,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: GrowMateTheme.borderLight, borderRadius: BorderRadius.circular(2))),
            const Text('Add New Crop',
                style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _loadingCrops
               ? Container(
                   height: 100,
                   decoration: BoxDecoration(
                     color: GrowMateTheme.primaryGreen.withValues(alpha: 0.05),
                     borderRadius: BorderRadius.circular(16),
                   ),
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       const SizedBox(
                         width: 24,
                         height: 24,
                         child: CircularProgressIndicator(strokeWidth: 2.5, color: GrowMateTheme.primaryGreen),
                       ),
                       const SizedBox(height: 12),
                       Text('Analyzing soil & weather for $_detectedPlace...', 
                         style: const TextStyle(fontSize: 12, color: GrowMateTheme.primaryGreen, fontWeight: FontWeight.w500)),
                     ],
                   ),
                 )
               : DropdownButtonFormField<String>(
              initialValue: _selectedCropName,
              hint: const Text('Select Verified Crop *'),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.grass_outlined)),
              items: _allCropsData.map((c) => DropdownMenuItem(
                value: c['name'].toString(), 
                child: Row(
                  children: [
                    CropIcon(icon: c['icon']?.toString(), color: GrowMateTheme.primaryGreen, size: 18),
                    const SizedBox(width: 10),
                    Text(c['name'].toString()),
                  ],
                )
              )).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCropName = v;
                  final cropData = _allCropsData.firstWhere((c) => c['name'] == v);
                  _selectedVariety = cropData['variety_name']?.toString();
                });
              },
              validator: (v) => v == null ? 'Please select a crop' : null,
            ),
            const SizedBox(height: 12),
            if (_selectedCropName != null) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedVariety,
                hint: const Text('Variety Selection *'),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                items: [
                   DropdownMenuItem(value: _selectedVariety, child: Text(_selectedVariety ?? 'General')),
                ],
                onChanged: (v) => setState(() => _selectedVariety = v),
                validator: (v) => v == null ? 'Please select a variety' : null,
              ),
              const SizedBox(height: 12),
            ],
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
                  setState(() {
                    // Force ISO format for database compliance
                    _sowingCtrl.text = date.toIso8601String().split('T')[0];
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Sowing Date *',
                hintText: 'Select Date',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: GrowMateTheme.primaryGreen.withValues(alpha: 0.05),
                border: Border.all(color: GrowMateTheme.primaryGreen.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined, color: GrowMateTheme.primaryGreen),
                title: Text(_detectedPlace ?? 'Identifying Location...', 
                    style: const TextStyle(fontWeight: FontWeight.w600, color: GrowMateTheme.primaryGreen)),
                subtitle: _selectedLocation != null 
                    ? Text('${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}')
                    : const Text('Fetching farm coordinates...'),
                trailing: const Icon(Icons.verified_user_outlined, color: GrowMateTheme.primaryGreen, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _isPrimary,
              onChanged: (v) => setState(() => _isPrimary = v),
              title: const Text('Set as Primary Crop', style: TextStyle(fontSize: 14)),
              activeThumbColor: GrowMateTheme.primaryGreen,
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: GrowMateTheme.dangerRed, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Add Crop'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
