import 'package:flutter/material.dart';
import '../../../core/theme/growmate_theme.dart';
import '../../../shared/widgets.dart';

/// RainfallCard — checks for DEGRADED status explicitly.
/// If status == 'DEGRADED', shows DegradedBanner.
/// Never shows fake data.
class RainfallCard extends StatelessWidget {
  final Map<String, dynamic> rainfall;

  const RainfallCard({required this.rainfall, super.key});

  @override
  Widget build(BuildContext context) {
    final isDegraded = rainfall['status'] == 'DEGRADED';

    return Container(
      decoration: BoxDecoration(
        color: GrowMateTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: GrowMateTheme.cardShadow,
        border: Border.all(color: GrowMateTheme.skyBlue.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GrowMateTheme.skyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.water_drop_outlined,
                    color: GrowMateTheme.skyBlue, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Rainfall',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: GrowMateTheme.textPrimary,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          if (isDegraded)
            DegradedBanner(
              source: rainfall['source'] ?? 'rainfall',
              message: rainfall['message'] ?? 'Rainfall data unavailable',
            )
          else
            _RainfallContent(data: rainfall),
        ],
      ),
    );
  }
}

class _RainfallContent extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RainfallContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final mainStatus = data['main_status'] as Map<String, dynamic>?;
    final intelligence = data['intelligence'] as Map<String, dynamic>?;
    final soilStatus = data['soil_status'] as Map<String, dynamic>?;

    final statusMsg = mainStatus?['message'] as String?;
    final rainfallStatus = intelligence?['rainfall_status'] as String?;
    final monthlyPattern = intelligence?['monthly_pattern'] as String?;
    final irrigationNeeded = soilStatus?['irrigation_needed'] as bool?;

    if (statusMsg == null && rainfallStatus == null) {
      return const Text('No rainfall data available.',
          style: TextStyle(fontSize: 13, color: GrowMateTheme.textSecondary));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (statusMsg != null)
          Text(statusMsg,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: GrowMateTheme.textPrimary,
              )),
        if (rainfallStatus != null) ...[
          const SizedBox(height: 6),
          Text(rainfallStatus,
              style: const TextStyle(
                  fontSize: 13, color: GrowMateTheme.textSecondary)),
        ],
        if (monthlyPattern != null) ...[
          const SizedBox(height: 6),
          Text(monthlyPattern,
              style: const TextStyle(
                  fontSize: 12, color: GrowMateTheme.textSecondary, height: 1.4)),
        ],
        if (irrigationNeeded != null) ...[
          const SizedBox(height: 10),
          _IrrigationChip(needed: irrigationNeeded),
        ],
      ],
    );
  }
}

class _IrrigationChip extends StatelessWidget {
  final bool needed;
  const _IrrigationChip({required this.needed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: needed
            ? GrowMateTheme.warningAmber.withOpacity(0.1)
            : GrowMateTheme.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: needed
              ? GrowMateTheme.warningAmber.withOpacity(0.4)
              : GrowMateTheme.successGreen.withOpacity(0.4),
        ),
      ),
      child: Text(
        needed ? 'Irrigation Recommended' : 'No Irrigation Needed',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: needed ? GrowMateTheme.warningAmber : GrowMateTheme.successGreen,
        ),
      ),
    );
  }
}
