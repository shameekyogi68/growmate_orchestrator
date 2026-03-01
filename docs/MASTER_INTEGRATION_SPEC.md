# GrowMate Master Integration Specification (v3.0)

**Project**: GrowMate Mobile  
**Role**: Integration Engineering Guide  
**Status**: DEFINITIVE (Single Source of Truth)

---

## 0. The Orchestration Pipeline (How Data is Processed)
The backend follows a strict **Raw-First** pipeline to ensure data fidelity:

1.  **Raw Acquisition**: Fetches **100% of the raw JSON** from the Agronomic API.
2.  **Triple-Fusion 3.1 (The Performance & Accuracy Layer)**: 
    - **Lightning Speed (<1.5s)**: Uses **Commodity-Level Pricing** and **Dual-Layer Caching** (Redis + In-Memory) to eliminate OGD latency.
    - **Scientific Validation**: Parses technical climate ranges (mm/°C) against live data for "Perfect Accuracy."
    - **Internal Soil Intelligence**: Includes **Soil pH** and **Moisture Stress** validation without data overload in the UI.
3.  **Prescriptive Analysis**: Generates the "WHY" (description) based on the background fusion.
4.  **Market Injection & Localization**: Injects live prices and bilingual names.

---

## 1. The Global State Machine
The frontend MUST maintain a state based on the presence of an `active_crop`.

| User State | Dashboard Display | Required Action |
| :--- | :--- | :--- |
| **Guest** | Login / Register | Call `POST /user/register` or `POST /user/login` |
| **New User** | "Add your first crop" | Navigate to **Discover** tab |
| **Active Farmer** | Intelligence Dashboard | Call `POST /farmer-advisory` |

---

## 2. Authentication & Persistence
### Registration (`POST /user/register`)
Farmers can register with just a **Phone Number** and a **4-digit PIN** (quick_pin).
- **Body**:
```json
{
  "phone_number": "9876543210",
  "quick_pin": "1234",
  "full_name": "Shameek",
  "language": "kn",
  "latitude": 13.8,
  "longitude": 74.6
}
```
### Persistence Check (`GET /user/crops`)
Always call this on app startup. If the list is empty, force the user to the **Discovery View**.

---

## 3. High-Intelligence Discovery (`GET /supported-crops`)
**Issue**: Frontend showing "No data available".  
**Fix**: Ensure all parameters are passed exactly. Avoid "string" placeholders.

- **Endpoint**: `/supported-crops?latitude=13.8&longitude=74.6&language=kn&date=2026-02-28`
- **Response Structure (Seasonal Groups)**:
```json
{
  "status": "success",
  "seasonal_groups": [
    {
      "category": "Summer",
      "crops": [
        {
          "id": "O001",
          "name": "Groundnut",
          "name_en": "Groundnut",
          "name_kn": "ನೆಲಗಡಲೆ",
          "icon": "eco",
          "variety_name": "TMV-2",
          "crop_category": "Oilseed",
          "description": "Validated for current environment.",
          "morphological_characteristics": {
            "plant_height_range": "45cm - 60cm",
            "growth_habit": "Spreading",
            "maturity_duration_range": "105 Days"
          },
          "seed_specifications": {
            "seed_rate_per_acre": "5-10 kg",
            "germination_period": "4 - 7 Days",
            "seed_viability_period": "6 - 9 Months"
          },
          "yield_potential": {
            "average_yield_per_acre": "9.0 quintal",
            "yield_range_under_normal_conditions": "7.2 - 10.8 quintal"
          },
          "sensitivity_profile": {
            "drought_sensitivity_level": "Medium",
            "waterlogging_sensitivity_level": "High",
            "heat_tolerance_level": "Medium"
          },
          "end_use_information": {
            "main_use_type": "Commercial",
            "market_category": "Grade A"
          },
          "market_intelligence": {
            "market_price": "6800",
            "price_status": "Live",
            "market_name": "Byndoor APMC"
          },
          "fusion_status": "Verified"
,
          "is_pivot_alternative": true
        }
      ]
    }
  ]
}
```
**Integration Rule**: Do NOT flatten the list. The UI MUST use Category headers.

---

## 4. Activating a Crop (`POST /user/crops`)
When a user selects a crop from Discover, you MUST persist it to the DB.
- **Body**:
```json
{
  "crop_name": "Paddy",
  "variety": "MO-4",
  "sowing_date": "2026-02-28",
  "latitude": 13.8,
  "longitude": 74.6,
  "is_primary": true
}
```

---

## 5. Main Dashboard (`POST /farmer-advisory`)
Fetch this every time the user opens the Dashboard.
- **Request**:
```json
{
  "user_id": 3,
  "crop": "Paddy",
  "latitude": 13.8,
  "longitude": 74.6,
  "date": "2026-02-28",
  "language": "kn"
}
```
- **Rendering Guide**: 
  - `main_status`: Large hero card.
  - `alerts`: List of urgent cards. Use `color_code` for borders.
  - `crop_calendar`: Render as a timeline/stepper.

---

## 6. Visual Engineering (The "WOW" Factor)
### Glassmorphism
Apply this to all "Insurance" and "Advisory" cards.
```dart
BoxDecoration(
  color: Colors.white.withOpacity(0.1),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: Colors.white.withOpacity(0.2)),
)
```
### Dynamic Icons
The backend sends Material Icon strings. Use this mapper:
```dart
IconData mapIcon(String iconName) {
  return {
    'agriculture': Icons.agriculture,
    'eco': Icons.eco,
    'grain': Icons.grass,
    'warning': Icons.warning,
    'report_problem': Icons.report_problem
  }[iconName] ?? Icons.info;
}
```

---

## 7. Insurance Evidence (`GET /insurance-report/{id}/download`)
Fetch this in the "Insurance" tab. Render the `markdown_report` field using a Markdown package. **Do not modify the text**.

---
*Authorized for GrowMate Deployment 2026*
