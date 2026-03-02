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
        if (mounted) setState(() => _isLoadingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition();
      final userLatLong = LatLng(pos.latitude, pos.longitude);
      
      if (mounted) {
        setState(() => _selectedLocation = userLatLong);
        _mapController.move(_selectedLocation, 12);
      }
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
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isValid = _isWithinUdupiBounds(_selectedLocation);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Farm Location', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        backgroundColor: GrowMateTheme.surfaceWhite,
        foregroundColor: GrowMateTheme.textPrimary,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: isValid ? _onConfirm : null,
            child: Text('Confirm', style: TextStyle(
              color: isValid ? GrowMateTheme.primaryGreen : GrowMateTheme.textSecondary.withValues(alpha: 0.5), 
              fontWeight: FontWeight.w700, 
              fontSize: 16
            )),
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
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: const [
                      LatLng(14.5, 74.4), // Top left
                      LatLng(14.5, 75.3), // Top right
                      LatLng(12.5, 75.3), // Bottom right
                      LatLng(12.5, 74.4), // Bottom left
                    ],
                    color: GrowMateTheme.primaryGreen.withValues(alpha: 0.15),
                    borderColor: GrowMateTheme.primaryGreenDark,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 52,
                    height: 52,
                    alignment: Alignment.topCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset('assets/icons/logo.png'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Instruction Card at Bottom
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
                  const Expanded(
                    child: Text(
                      'Tap on the map to place the pin on your farm. This helps us provide accurate localized weather and crop advisories.',
                      style: TextStyle(fontSize: 12, color: GrowMateTheme.textSecondary, fontFamily: 'Inter'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Error banner if outside bounded area
          if (!isValid)
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GrowMateTheme.dangerRed.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: GrowMateTheme.elevatedShadow,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Service available only inside Udupi District (Green Area). Please move your pin into the zone to confirm.',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Inter', height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton(
          onPressed: () async {
            setState(() => _isLoadingLocation = true);
            await _determinePosition();
          },
          backgroundColor: GrowMateTheme.surfaceWhite,
          child: _isLoadingLocation 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location, color: GrowMateTheme.primaryGreen),
        ),
      ),
    );
  }
}
