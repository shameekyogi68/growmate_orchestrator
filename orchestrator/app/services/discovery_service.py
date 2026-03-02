from typing import Dict
import asyncio
from app.services.recommendation_service import get_crop_recommendations
from app.external.weather_api import fetch_weather_data
from app.services.rainfall_service import get_rainfall_advisory
from app.services.soil_service import get_soil_advisory
from app.utils.logger import logger
import re

# Visual Hints (UI-only policies)
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


def _get_location_name(lat: float, lon: float) -> str:
    """
    Returns a human-readable location name for Udupi regions based on GPS.
    """
    if 13.8 <= lat <= 14.2:
        return "Byndoor, Udupi"
    if 13.6 <= lat < 13.8:
        return "Kundapur, Udupi"
    if 13.4 <= lat < 13.6:
        return "Brahmavar, Udupi"
    if 13.2 <= lat < 13.4:
        return "Udupi Town"
    if 13.0 <= lat < 13.2:
        return "Kaup, Udupi"
    return f"Coord: {lat:.2f}, {lon:.2f}"


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
        raw_data, weather, rainfall, soil = await asyncio.gather(
            get_crop_recommendations(latitude, longitude, request_date, language, lite=True),
            fetch_weather_data(latitude, longitude, language, request_date),
            get_rainfall_advisory(latitude, longitude, request_date, language),
            get_soil_advisory(latitude, longitude, language),
        )

        location_name = _get_location_name(latitude, longitude)

        # If raw_data is still unavailable (shouldn't happen with fallback), return empty but successful
        if not raw_data or raw_data == "unavailable":
            return {
                "status": "success",
                "location": location_name,
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
            "location": location_name,
            "date": request_date,
            "seasonal_groups": seasonal_groups,
            "render_hints": RENDER_HINTS
        }
    except Exception as e:
        logger.error(f"Error in Pure Dynamic Fusion: {e}")
        return {
            "status": "success",
            "location": _get_location_name(latitude, longitude),
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

        # Extract discovery metadata with API-first defaults
        meta = rec.get("discovery_metadata", {
            "icon": "eco",
            "difficulty": "Medium",
            "market_value": "Medium",
            "risk_level": "Medium",
            "water_requirement": "Medium"
        })

        # --- Financial Optimization ---
        market_info = rec.get("financial_intelligence", {})
        live_price = market_info.get("modal_price", "N/A")
        price_status = market_info.get("market_status", "Live")

        # --- Data-Driven Fusion Validation ---
        fusion_status = "Verified"
        reason_en = "Validated for current environment."
        reason_kn = "ಪ್ರಸ್ತುತ ಪರಿಸರಕ್ಕೆ ಪರಿಶೀಲಿಸಲಾಗಿದೆ."
        agro_suitability = rec.get("agro_climatic_suitability", {})
        
        # 1. Rainfall Logic
        rain_range_str = agro_suitability.get("suitable_rainfall_range", "")
        if rain_range_str and rainfall:
            rain_status = rainfall.get("intelligence", {}).get("rainfall_status", "Normal")
            try:
                nums = [float(n) for n in re.findall(r"[\d.]+", rain_range_str)]
                if len(nums) >= 2:
                    min_rain = nums[0]
                    if min_rain >= 1500 and any(k in rain_status for k in ["Stress", "Deficit", "Dry"]):
                        fusion_status = "Warning"
                        reason_en = f"Variety needs high water ({min_rain}mm+); {rain_status} detected."
                        reason_kn = f"ತಳಿಗೆ ಹೆಚ್ಚಿನ ನೀರಿನ ಅಗತ್ಯವಿದೆ ({min_rain}mm+); ಪ್ರಸ್ತುತ {rain_status} ಕಂಡುಬಂದಿದೆ."
            except Exception:
                pass

        # 2. Temperature Logic
        temp_range_str = agro_suitability.get("suitable_temperature_range", "")
        current_temp = weather.get("temperature", 30)
        if temp_range_str:
            try:
                nums = [float(n) for n in re.findall(r"[\d.]+", temp_range_str)]
                if len(nums) >= 2:
                    min_t, max_t = nums[0], nums[1]
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

        # 3. Soil pH Logic (Internal Validation)
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

        # --- Visual Intelligence Injection ---
        ui_meta = STATUS_UI_MAP.get(fusion_status, STATUS_UI_MAP["Verified"])

        crop_data = {
            "id": rec["crop_id"],
            "name": display_name,
            "name_en": display_name if language == "en" else rec.get("identity", {}).get("crop_name_en", display_name),
            "name_kn": display_name if language == "kn" else rec.get("identity", {}).get("crop_name_kn", display_name),
            "icon": meta.get("icon", "eco"),
            "variety_name": variety_name,
            "crop_category": rec.get("identity", {}).get("crop_category", "N/A"),
            "description": (reason_en if language == "en" else reason_kn),
            "status_color": ui_meta["color"],
            "status_icon": ui_meta["icon"],
            "status_label": ui_meta["label"] if language == "en" else ui_meta["label_kn"],
            "ui_tags": [
                {"text": meta.get("difficulty", "Medium"), "color": "#3B82F6" if meta.get("difficulty") != "High" else "#EF4444"},
                {"text": meta.get("market_value", "Medium"), "color": "#8B5CF6"},
                {"text": meta.get("risk_level", "Medium"), "color": "#10B981" if meta.get("risk_level") == "Low" else "#F59E0B"},
            ],
            "morphological_characteristics": rec.get("morphological_characteristics", {}),
            "seed_specifications": rec.get("seed_specifications", {}),
            "yield_potential": rec.get("yield_potential", {}),
            "sensitivity_profile": rec.get("sensitivity_profile", {}),
            "end_use_information": rec.get("end_use_information", {}),
            "market_intelligence": {
                "market_price": live_price,
                "price_status": price_status,
                "market_name": rec.get("financial_intelligence", {}).get("market_name", "Local APMC"),
            },
            "fusion_status": fusion_status,
            "is_pivot_alternative": meta.get("water_requirement") == "Low" or (isinstance(rec.get("duration_weeks"), int) and rec["duration_weeks"] < 12),
        }
        fused_crops.append(crop_data)
        seen_crops.add(crop_id_key)

    return fused_crops
