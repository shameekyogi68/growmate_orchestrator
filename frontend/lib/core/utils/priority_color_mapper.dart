import 'package:flutter/material.dart';
import '../theme/growmate_theme.dart';

/// Maps backend `priority_level` strings to UI colors.
/// Frontend MUST NOT recalculate or infer priority.
/// Only use what the backend sends.
class PriorityColorMapper {
  PriorityColorMapper._();

  static Color forPriorityLevel(String? priorityLevel) {
    switch (priorityLevel?.toUpperCase()) {
      case 'CRITICAL':
        return GrowMateTheme.dangerRed;
      case 'HIGH':
        return GrowMateTheme.warningAmber;
      case 'MEDIUM':
        return GrowMateTheme.infoBlue;
      case 'LOW':
      default:
        return GrowMateTheme.successGreen;
    }
  }

  static Color forRiskLevel(String? riskLevel) {
    switch (riskLevel?.toUpperCase()) {
      case 'HIGH':
        return GrowMateTheme.dangerRed;
      case 'MEDIUM':
        return GrowMateTheme.warningAmber;
      case 'LOW':
      default:
        return GrowMateTheme.successGreen;
    }
  }

  /// Maps backend `color_code` hex string to Flutter Color.
  /// Backend sends hex like "#EF4444", "#F59E0B", "#10B981", "#1565C0".
  /// Fall back to successGreen if unparseable.
  static Color fromHexCode(String? hex) {
    if (hex == null || hex.isEmpty) return GrowMateTheme.successGreen;
    final cleaned = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return GrowMateTheme.successGreen;
    }
  }

  /// Maps backend `confidence_score` to badge color.
  static Color forConfidenceScore(double score) {
    if (score > 0.8) return GrowMateTheme.successGreen;
    if (score >= 0.5) return GrowMateTheme.warningAmber;
    return GrowMateTheme.dangerRed;
  }

  /// Maps backend `confidence_score` to human-readable label.
  static String labelForConfidenceScore(double score) {
    if (score > 0.8) return 'High Confidence';
    if (score >= 0.5) return 'Partial Data';
    return 'DEGRADED';
  }
}
