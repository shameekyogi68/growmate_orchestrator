from typing import Dict
import asyncio
from app.services.recommendation_service import get_crop_recommendations
from app.external.weather_api import fetch_weather_data
from app.services.rainfall_service import get_rainfall_advisory
from app.services.soil_service import get_soil_advisory
from app.utils.logger import logger
import re

# Decision Metadata Shell
DECISION_METADATA = {
    "Paddy": {
        "icon": "agriculture",
        "difficulty": "Medium",
        "market_value": "Medium",
        "water_requirement": "High",
        "investment_cost": "Medium",
        "labor_intensity": "High",
        "primary_use": "Food",
        "risk_level": "Medium",
    },
    "Groundnut": {
        "icon": "eco",
        "difficulty": "Easy",
        "market_value": "High",
        "water_requirement": "Low",
        "investment_cost": "Low",
        "labor_intensity": "Medium",
        "primary_use": "Commercial",
        "risk_level": "Low",
    },
    "Green Gram": {
        "icon": "grain",
        "difficulty": "Easy",
        "market_value": "Medium",
        "water_requirement": "Low",
        "investment_cost": "Low",
        "labor_intensity": "Low",
        "primary_use": "Dual",
        "risk_level": "Low",
    },
    "Black Gram": {
        "icon": "grain",
        "difficulty": "Easy",
        "market_value": "Medium",
        "water_requirement": "Low",
        "investment_cost": "Low",
        "labor_intensity": "Low",
        "primary_use": "Dual",
        "risk_level": "Low",
    },
    "Vegetables": {
        "icon": "shopping_basket",
        "difficulty": "Medium",
        "market_value": "High",
        "water_requirement": "Medium",
        "investment_cost": "Medium",
        "labor_intensity": "High",
        "primary_use": "Commercial",
        "risk_level": "Medium",
    },
}

DEFAULT_METADATA = {
    "icon": "eco",
    "difficulty": "Medium",
    "market_value": "Medium",
    "water_requirement": "Medium",
    "investment_cost": "Medium",
    "labor_intensity": "Medium",
    "primary_use": "Agriculture",
    "risk_level": "Medium",
}

# --- Visual Engineering Tokens (Flutter Ready) ---
STATUS_UI_MAP = {
    "Verified": {"color": "#10B981", "icon": "check_circle", "label": "Ideal", "label_kn": "ಸೂಕ್ತ"},
    "Warning": {"color": "#F59E0B", "icon": "warning", "label": "Caution", "label_kn": "ಎಚ್ಚರಿಕೆ"},
    "Critical": {"color": "#EF4444", "icon": "report_problem", "label": "Risk", "label_kn": "ಅಪಾಯ"},
}

RENDER_HINTS = {
    "layout": "grid",
    "card_style": "premium_glass",
    "animations": ["fade_in", "slide_up"],
    "primary_gradient": ["#3B82F6", "#1D4ED8"]
}


def get_crop_key(crop_name: str) -> str:
    name = crop_name.lower()
    if any(k in name for k in ["paddy", "ಭತ್ತ"]):
        return "Paddy"
    if any(k in name for k in ["groundnut", "ನೆಲಗಡಲೆ"]):
        return "Groundnut"
    if any(k in name for k in ["green gram", "ಹೆಸರು"]):
        return "Green Gram"
    if any(k in name for k in ["black gram", "ಉದ್ದಿನ"]):
        return "Black Gram"
    if any(
        k in name
        for k in [
            "vegetable",
            "ತರಕಾರಿ",
            "brinjal",
            "chilli",
            "watermelon",
            "cucumber",
            "okra",
        ]
    ):
        return "Vegetables"
    return "Default"


async def get_intelligent_crops(
    latitude: float = 13.8,
    longitude: float = 74.6,
    request_date: str | None = None,
    language: str = "en",
) -> Dict:
    """
    Pure Dynamic Fusion: Fetches seasonally grouped crops and validates each against live fusion services.
    NFR: All 3 external calls run in parallel via asyncio.gather.
    """
    try:
        # 1. Fetch ALL external intelligence concurrently (Triple-Fusion 2.0)
        # NFR: Still fast due to parallel gather, but now includes internal Soil AI.
        raw_data, weather, rainfall, soil = await asyncio.gather(
            get_crop_recommendations(latitude, longitude, request_date, language),
            fetch_weather_data(latitude, longitude, language, request_date),
            get_rainfall_advisory(latitude, longitude, request_date, language),
            get_soil_advisory(latitude, longitude, language),
        )

        # If raw_data is still unavailable (shouldn't happen with fallback), return empty but successful
        if not raw_data or raw_data == "unavailable":
            return {
                "status": "success",
                "location": "Byndoor, Udupi",
                "date": request_date,
                "seasonal_groups": [],
            }

        seasonal_groups = []

        # Handle dictionary of seasons
        if isinstance(raw_data, dict):
            for season, crops in raw_data.items():
                fused_crops = await validate_crops(
                    crops, weather, rainfall, soil, request_date, language
                )
                if fused_crops:
                    seasonal_groups.append({"category": season, "crops": fused_crops})
        # Handle flat list (fallback)
        elif isinstance(raw_data, list):
            fused_crops = await validate_crops(
                raw_data, weather, rainfall, soil, request_date, language
            )
            if fused_crops:
                seasonal_groups.append(
                    {"category": "Recommended", "crops": fused_crops}
                )

        return {
            "status": "success",
            "location": "Byndoor, Udupi",
            "date": request_date,
            "seasonal_groups": seasonal_groups,
            "render_hints": RENDER_HINTS
        }
    except Exception as e:
        logger.error(f"Error in Pure Dynamic Fusion: {e}")
        # Catastrophic Fallback: Return a valid response structure to prevent 500s
        return {
            "status": "success",
            "location": "Byndoor, Udupi",
            "date": request_date,
            "seasonal_groups": [],
            "message": "Service is under maintenance. Fallback enabled."
        }


async def validate_crops(
    crops: list, weather: dict, rainfall: dict, soil: dict, request_date: str, language: str
) -> list:
    fused_crops = []
    seen_crops = set()

    for rec in crops:
        display_name = rec["identity"]["crop_name"]
        variety_name = rec["identity"]["variety_name"]

        # Unique check by Name + Variety
        crop_id_key = f"{display_name}_{variety_name}"
        if crop_id_key in seen_crops:
            continue

        meta_key = get_crop_key(display_name)
        meta = DECISION_METADATA.get(meta_key, DEFAULT_METADATA)

        # --- Financial Optimization ---
        market_info = rec.get("financial_intelligence", {})
        live_price = market_info.get("modal_price", "N/A")
        price_status = market_info.get("market_status", "Live")

        # --- Data-Driven Fusion Validation (Optimized for necessary warnings) ---
        fusion_status = "Verified"
        reason_en = "Validated for current environment."
        reason_kn = "ಪ್ರಸ್ತುತ ಪರಿಸರಕ್ಕೆ ಪರಿಶೀಲಿಸಲಾಗಿದೆ."
        agro_suitability = rec.get("agro_climatic_suitability", {})
        
        # 1. Rainfall Logic: Dynamic Range Validation
        rain_range_str = agro_suitability.get("suitable_rainfall_range", "")
        if rain_range_str and rainfall:
            rain_status = rainfall.get("intelligence", {}).get("rainfall_status", "Normal")
            try:
                # Extract numbers from range (e.g., "1000mm - 4000mm" -> [1000.0, 4000.0])
                nums = [float(n) for n in re.findall(r"[\d.]+", rain_range_str)]
                if len(nums) >= 2:
                    min_rain, max_rain = nums[0], nums[1]
                    # Warn if high-water crop (>1500mm) is in Stress/Deficit
                    if min_rain >= 1500 and any(k in rain_status for k in ["Stress", "Deficit", "Dry"]):
                        fusion_status = "Warning"
                        reason_en = f"Variety needs high water ({min_rain}mm+); {rain_status} detected."
                        reason_kn = f"ತಳಿಗೆ ಹೆಚ್ಚಿನ ನೀರಿನ ಅಗತ್ಯವಿದೆ ({min_rain}mm+); ಪ್ರಸ್ತುತ {rain_status} ಕಂಡುಬಂದಿದೆ."
            except Exception:
                pass

        # 2. Temperature Logic: Intelligent Thresholds
        temp_range_str = agro_suitability.get("suitable_temperature_range", "")
        current_temp = weather.get("temperature", 30)
        if temp_range_str:
            try:
                nums = [float(n) for n in re.findall(r"[\d.]+", temp_range_str)]
                if len(nums) >= 2:
                    min_t, max_t = nums[0], nums[1]
                    # Verify if current temp is within range (with 2 degree buffer)
                    if current_temp > (max_t + 2):
                        fusion_status = "Warning"
                        reason_en = f"Current temp ({current_temp}°C) exceeds variety limit ({max_t}°C)."
                        reason_kn = f"ಪ್ರಸ್ತುತ ತಾಪಮಾನವು ({current_temp}°C) ತಳಿಯ ಮಿತಿಯನ್ನು ({max_t}°C) ಮೀರಿದೆ."
                    elif current_temp < (min_t - 2):
                        fusion_status = "Warning"
                        reason_en = f"Current temp ({current_temp}°C) is below variety limit ({min_t}°C)."
                        reason_kn = f"ಪ್ರಸ್ತುತ ತಾಪಮಾನವು ({current_temp}°C) ತಳಿಯ ಮಿತಿಗಿಂತ ({min_t}°C) ಕಡಿಮೆಯಿದೆ."
            except Exception:
                pass

        # Critical heat check for heat-sensitive crops
        if current_temp > 38 and rec.get("sensitivity_profile", {}).get("heat_tolerance_level") == "Low":
            fusion_status = "Critical"
            reason_en = "Extreme heat warning: high risk of crop failure."
            reason_kn = "ವಿಪರೀತ ಶಾಖದ ಎಚ್ಚರಿಕೆ: ಬೆಳೆ ಹಾನಿಯಾಗುವ ಸಾಧ್ಯತೆ ಹೆಚ್ಚು."

        # 3. Soil pH Logic: INTERNAL VALIDATION ONLY (No data overload)
        # Even though we don't show pH to the farmer, we use it for Accuracy.
        ph_range_str = agro_suitability.get("suitable_soil_ph_range", "")
        if ph_range_str and soil:
            live_ph = soil.get("ph", 6.0)
            try:
                nums = re.findall(r"[\d.]+", ph_range_str)
                if len(nums) >= 2:
                    min_ph, max_ph = float(nums[0]), float(nums[1])
                    if live_ph < (min_ph - 0.5) or live_ph > (max_ph + 0.5):
                        fusion_status = "Warning"
                        reason_en = f"Soil condition (pH {live_ph}) is not ideal for this variety."
                        reason_kn = f"ಮಣ್ಣಿನ ಸ್ಥಿತಿ (pH {live_ph}) ಈ ತಳಿಗೆ ಸೂಕ್ತವಲ್ಲ."
            except Exception:
                pass

        # 4. Soil Moisture Logic: Stress Detection
        if soil and soil.get("moisture") == "low":
            if rec.get("sensitivity_profile", {}).get("drought_sensitivity_level") == "High":
                fusion_status = "Warning"
                reason_en = "Low soil moisture; high drought risk for this variety."
                reason_kn = "ಕಡಿಮೆ ಮಣ್ಣಿನ ತೇವಾಂಶ; ಈ ತಳಿಗೆ ಬರಗಾಲದ ಅಪಾಯ ಹೆಚ್ಚು."

        # --- Visual Intelligence Injection ---
        ui_meta = STATUS_UI_MAP.get(fusion_status, STATUS_UI_MAP["Verified"])

        # Construct the final high-fidelity object (Filtered for Farmer Clarity)
        crop_data = {
            "id": rec["crop_id"],
            "name": display_name,
            "name_en": display_name if language == "en" else rec.get("identity", {}).get("crop_name_en", display_name),
            "name_kn": display_name if language == "kn" else rec.get("identity", {}).get("crop_name_kn", display_name),
            "icon": meta["icon"],
            "variety_name": variety_name,
            "crop_category": rec.get("identity", {}).get("crop_category", "N/A"),
            "description": (
                reason_en if language == "en" else reason_kn
            ),
            # --- Enriched Visual Metadata ---
            "status_color": ui_meta["color"],
            "status_icon": ui_meta["icon"],
            "status_label": ui_meta["label"] if language == "en" else ui_meta["label_kn"],
            "ui_tags": [
                {"text": meta["difficulty"], "color": "#3B82F6" if meta["difficulty"] != "High" else "#EF4444"},
                {"text": meta["market_value"], "color": "#8B5CF6"},
                {"text": meta["risk_level"], "color": "#10B981" if meta["risk_level"] == "Low" else "#F59E0B"},
            ],
            # --- Enriched Farmer-Centric Metadata (Requested Fields Only) ---
            "morphological_characteristics": rec.get("morphological_characteristics", {}),
            "seed_specifications": rec.get("seed_specifications", {}),
            "yield_potential": rec.get("yield_potential", {}),
            "sensitivity_profile": rec.get("sensitivity_profile", {}),
            "end_use_information": rec.get("end_use_information", {}),
            # --- Orchestrated Market Additions ---
            "market_intelligence": {
                "market_price": live_price,
                "price_status": price_status,
                "market_name": rec.get("financial_intelligence", {}).get("market_name", "Local APMC"),
            },
            "fusion_status": fusion_status,
            "is_pivot_alternative": meta.get("water_requirement") == "Low"
            or (
                isinstance(rec.get("duration_weeks"), int)
                and rec["duration_weeks"] < 12
            ),
        }
        fused_crops.append(crop_data)
        seen_crops.add(crop_id_key)

    return fused_crops
