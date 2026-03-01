import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/growmate_theme.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const LocationPickerScreen({this.initialLocation, super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _selectedLocation;
  late final MapController _mapController;
  
  // Default to Udupi, Karnataka if no initial location provided
  static const _defaultLocation = LatLng(13.3409, 74.7421);

  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _defaultLocation;
    _mapController = MapController();
    if (widget.initialLocation == null) {
      _determinePosition();
    } else {
      _isLoadingLocation = false;
    }
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition();
      final userLatLong = LatLng(pos.latitude, pos.longitude);
      
      // Auto-snap to user location if within Udupi bounds
      if (_isWithinUdupiBounds(userLatLong)) {
        setState(() => _selectedLocation = userLatLong);
      }
      _mapController.move(_selectedLocation, 12);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  bool _isWithinUdupiBounds(LatLng pos) {
    // Orchestrator validation bounds
    return pos.latitude >= 12.5 &&
        pos.latitude <= 14.5 &&
        pos.longitude >= 74.4 &&
        pos.longitude <= 75.3;
  }

  void _onConfirm() {
    if (_isWithinUdupiBounds(_selectedLocation)) {
      Navigator.of(context).pop(_selectedLocation);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Farm must be within Udupi District bounds'),
          backgroundColor: GrowMateTheme.dangerRed,
        ),
      );
      // Snap map back to center
      _mapController.move(_defaultLocation, 10);
      setState(() => _selectedLocation = _defaultLocation);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Farm Location', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        backgroundColor: GrowMateTheme.surfaceWhite,
        foregroundColor: GrowMateTheme.textPrimary,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _onConfirm,
            child: const Text('Confirm', style: TextStyle(color: GrowMateTheme.primaryGreen, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 12.0,
              onTap: (tapPosition, point) {
                setState(() => _selectedLocation = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.growmate.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: GrowMateTheme.dangerRed,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: GrowMateTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: GrowMateTheme.cardShadow,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: GrowMateTheme.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap on the map to place the pin on your farm. This helps us provide accurate localized weather and crop advisories.',
                      style: const TextStyle(fontSize: 12, color: GrowMateTheme.textSecondary, fontFamily: 'Inter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          setState(() => _isLoadingLocation = true);
          await _determinePosition();
        },
        backgroundColor: GrowMateTheme.surfaceWhite,
        child: _isLoadingLocation 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location, color: GrowMateTheme.primaryGreen),
      ),
    );
  }
}
