import 'dart:convert';

/// AdvisoryResponse — strictly matches POST /farmer-advisory response schema.
/// Field names are EXACT backend field names. Do not rename.
class AdvisoryResponse {
  final String status;
  final double confidenceScore;
  final MainStatus mainStatus;
  final Map<String, dynamic> rainfall;
  final Map<String, dynamic> soil;
  final Map<String, dynamic> pest;
  final Map<String, dynamic> cropCalendar;
  final Map<String, dynamic> marketPrices;
  final Map<String, dynamic> weather;
  final Map<String, dynamic> udupiIntelligence;
  final List<dynamic> recommendations;
  final List<AdvisoryAlert> alerts;
  final bool partialData;
  final Map<String, String> serviceHealth;
  final String lastUpdated;
  final Map<String, dynamic>? uiConfig;

  const AdvisoryResponse({
    required this.status,
    required this.confidenceScore,
    required this.mainStatus,
    required this.rainfall,
    required this.soil,
    required this.pest,
    required this.cropCalendar,
    required this.marketPrices,
    required this.weather,
    required this.udupiIntelligence,
    required this.recommendations,
    required this.alerts,
    required this.partialData,
    required this.serviceHealth,
    required this.lastUpdated,
    this.uiConfig,
  });

  factory AdvisoryResponse.fromJson(Map<String, dynamic> json) {
    return AdvisoryResponse(
      status: json['status'] as String? ?? 'unknown',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 1.0,
      mainStatus: MainStatus.fromJson(
          json['main_status'] as Map<String, dynamic>? ?? {}),
      rainfall: json['rainfall'] as Map<String, dynamic>? ?? {},
      soil: json['soil'] as Map<String, dynamic>? ?? {},
      pest: json['pest'] as Map<String, dynamic>? ?? {},
      cropCalendar: json['crop_calendar'] as Map<String, dynamic>? ?? {},
      marketPrices: json['market_prices'] as Map<String, dynamic>? ?? {},
      weather: json['weather'] as Map<String, dynamic>? ?? {},
      udupiIntelligence:
          json['udupi_intelligence'] as Map<String, dynamic>? ?? {},
      recommendations: json['recommendations'] as List<dynamic>? ?? [],
      alerts: (json['alerts'] as List<dynamic>? ?? [])
          .map((a) => AdvisoryAlert.fromJson(a as Map<String, dynamic>))
          .toList(),
      partialData: json['partial_data'] as bool? ?? false,
      serviceHealth:
          (json['service_health'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      lastUpdated: json['last_updated'] as String? ?? '',
      uiConfig: json['ui_config'] as Map<String, dynamic>?,
    );
  }

  /// Returns true if any sub-service is in DEGRADED state
  bool get isRainfallDegraded =>
      rainfall['status'] == 'DEGRADED';
}

/// Matches backend main_status object exactly.
class MainStatus {
  final String riskLevel;  // "HIGH" | "MEDIUM" | "LOW"
  final String message;
  final String icon;
  final String colorCode;  // hex e.g. "#EF4444"
  final String statusLabel; // "High Risk" | "Caution" | "Safe"

  const MainStatus({
    required this.riskLevel,
    required this.message,
    required this.icon,
    required this.colorCode,
    required this.statusLabel,
  });

  factory MainStatus.fromJson(Map<String, dynamic> json) => MainStatus(
        riskLevel: json['risk_level'] as String? ?? 'LOW',
        message: json['message'] as String? ?? '',
        icon: json['icon'] as String? ?? 'check_circle',
        colorCode: json['color_code'] as String? ?? '#10B981',
        statusLabel: json['status_label'] as String? ?? 'Safe',
      );
}

/// Matches backend alert schema exactly.
class AdvisoryAlert {
  final String priorityLevel;  // "CRITICAL" | "HIGH" | "MEDIUM" | "LOW"
  final bool shouldNotify;
  final String source;         // "rainfall" | "pest" | "soil" | "weather"
  final String message;
  final String icon;
  final String colorCode;
  final String? actionText;

  const AdvisoryAlert({
    required this.priorityLevel,
    required this.shouldNotify,
    required this.source,
    required this.message,
    required this.icon,
    required this.colorCode,
    this.actionText,
  });

  factory AdvisoryAlert.fromJson(Map<String, dynamic> json) => AdvisoryAlert(
        priorityLevel: json['priority_level'] as String? ?? 'LOW',
        shouldNotify: json['should_notify'] as bool? ?? false,
        source: json['source'] as String? ?? '',
        message: json['message'] as String? ?? '',
        icon: json['icon'] as String? ?? 'warning',
        colorCode: json['color_code'] as String? ?? '#F59E0B',
        actionText: json['action_text'] as String?,
      );
}

/// UserProfile — matches GET /user/profile response.
class UserProfile {
  final String? fullName;
  final String language;
  final double? latitude;
  final double? longitude;
  final String? activeCrop;
  final String? activeSowingDate;

  const UserProfile({
    this.fullName,
    required this.language,
    this.latitude,
    this.longitude,
    this.activeCrop,
    this.activeSowingDate,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        fullName: json['full_name'] as String?,
        language: json['language'] as String? ?? 'en',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        activeCrop: json['active_crop'] as String?,
        activeSowingDate: json['active_sowing_date'] as String?,
      );
}

/// AuthResponse — matches POST /user/login and /user/register responses.
class AuthResponse {
  final String status;
  final String userId;
  final String token;
  final UserProfile profile;

  const AuthResponse({
    required this.status,
    required this.userId,
    required this.token,
    required this.profile,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        status: json['status'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        token: json['token'] as String? ?? '',
        profile: UserProfile.fromJson(
          json['profile'] as Map<String, dynamic>? ?? {},
        ),
      );
}

/// UserCrop — matches GET /user/crops list items.
class UserCrop {
  final int id;
  final String cropName;
  final String? variety;
  final String? sowingDate;
  final double? latitude;
  final double? longitude;
  final String? icon;
  final bool isPrimary;

  const UserCrop({
    required this.id,
    required this.cropName,
    this.variety,
    this.sowingDate,
    this.latitude,
    this.longitude,
    this.icon,
    required this.isPrimary,
  });

  factory UserCrop.fromJson(Map<String, dynamic> json) => UserCrop(
        id: json['id'] as int? ?? 0,
        cropName: json['crop_name'] as String? ?? '',
        variety: json['variety'] as String?,
        sowingDate: json['sowing_date'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        icon: json['icon'] as String?,
        isPrimary: json['is_primary'] as bool? ?? false,
      );
}
