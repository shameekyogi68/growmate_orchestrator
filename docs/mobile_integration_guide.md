## 1. Crop Discovery
Before requesting an advisory, use this endpoint to populate your crop selection screen.

**Endpoint**: `GET /supported-crops?latitude=13.3&longitude=74.7&date=2026-07-20&language=en`

```dart
class CropMeta {
  final String id;
  final String nameEn;
  final String nameKn;
  final String icon;
  final List<String> varieties;
  final String descriptionEn;
  final String descriptionKn;
  final int durationWeeks;
  final String expectedYield;
  final String difficulty;
  final String marketValue;
  final String waterRequirement;
  final String investmentCost;
  final String laborIntensity;
  final String primaryUse;
  final String riskLevel;

  CropMeta({
    required this.id, 
    required this.nameEn, 
    required this.nameKn, 
    required this.icon,
    required this.varieties,
    required this.descriptionEn,
    required this.descriptionKn,
    required this.durationWeeks,
    required this.expectedYield,
    required this.difficulty,
    required this.marketValue,
    required this.waterRequirement,
    required this.investmentCost,
    required this.laborIntensity,
    required this.primaryUse,
    required this.riskLevel,
  });

  factory CropMeta.fromJson(Map<String, dynamic> json) {
    return CropMeta(
      id: json['id'],
      nameEn: json['name_en'],
      nameKn: json['name_kn'],
      icon: json['icon'],
      varieties: List<String>.from(json['varieties']),
      descriptionEn: json['description_en'],
      descriptionKn: json['description_kn'],
      durationWeeks: json['duration_weeks'],
      expectedYield: json['expected_yield'],
      difficulty: json['difficulty'],
      marketValue: json['market_value'],
      waterRequirement: json['water_requirement'],
      investmentCost: json['investment_cost'],
      laborIntensity: json['labor_intensity'],
      primaryUse: json['primary_use'],
      riskLevel: json['risk_level'],
    );
  }
}
```
## 2. Dart Data Models

Use these models to map the API response directly into your Flutter application.

```dart
class Alert {
  final String priorityLevel;
  final bool shouldNotify;
  final String source;
  final String message;
  final String icon; // Material Icon name
  final String colorHex; // Hex color code

  Alert({
    required this.priorityLevel,
    required this.shouldNotify,
    required this.source,
    required this.message,
    required this.icon,
    required this.colorHex,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      priorityLevel: json['priority_level'],
      shouldNotify: json['should_notify'],
      source: json['source'],
      message: json['message'],
      icon: json['icon'],
      colorHex: json['color_code'],
    );
  }
}

class MainStatus {
  final String riskLevel;
  final String message;
  final String icon;
  final String colorHex;

  MainStatus({
    required this.riskLevel,
    required this.message,
    required this.icon,
    required this.colorHex,
  });

  factory MainStatus.fromJson(Map<String, dynamic> json) {
    return MainStatus(
      riskLevel: json['risk_level'],
      message: json['message'],
      icon: json['icon'],
      colorHex: json['color_code'],
    );
  }
}
```

## 2. Using Icons and Colors in Flutter

The API now provides Material Icon names and HEX codes. Use this helper to convert them.

```dart
// Convert Icon Name to IconData
IconData getIcon(String iconName) {
  switch (iconName) {
    case 'report_problem': return Icons.report_problem;
    case 'warning': return Icons.warning;
    case 'check_circle': return Icons.check_circle;
    case 'error_outline': return Icons.error_outline;
    default: return Icons.info;
  }
}

// Convert Hex String to Color
Color hexToColor(String hexCode) {
  return Color(int.parse(hexCode.replaceFirst('#', '0xff')));
}
```

## 3. Recommended UI Architecture
- **Dashboard**: Use a `CustomScrollView` with `SliverAppBar`.
- **Alerts**: Use a `ListView.builder` with `Card` widgets wrapped in `BackdropFilter` for that glassmorphism look.
- **Language**: Send the `language` parameter ("kn" or "en") in your API request based on the user's localized app profile.

## 4. Sample API Request
```dart
final response = await http.post(
  Uri.parse('https://your-api.com/farmer-advisory'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer grower_secret_token',
  },
  body: jsonEncode({
    'user_id': 'farmer_id',
    'latitude': lat,
    'longitude': lon,
    'date': '2026-07-20',
    'crop': 'Paddy',
    'language': 'kn',
  }),
);
```
