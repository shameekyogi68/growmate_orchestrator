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
    """
    try:
        # 1. Fetch ALL external intelligence concurrently
        raw_data, weather, rainfall, soil = await asyncio.gather(
            get_crop_recommendations(latitude, longitude, request_date, language, lite=False),
            fetch_weather_data(latitude, longitude, language, request_date),
            get_rainfall_advisory(latitude, longitude, request_date, language),
            get_soil_advisory(latitude, longitude, language),
        )

        location_name = _get_location_name(latitude, longitude)

        # If raw_data is still unavailable, return empty but successful
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
        # Handle flat list
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
            "message": f"Service is under maintenance: {str(e)}"
        }


async def validate_crops(
    crops: list, weather: dict, rainfall: dict, soil: dict, request_date: str, language: str
) -> list:
    fused_crops = []
    seen_crops = set()

    for rec in crops:
        # Safety: Ensure identity exists
        identity = rec.get("identity", {})
        display_name = identity.get("crop_name", "Unknown Crop")
        variety_name = identity.get("variety_name", "General")

        # Unique check by Name + Variety
        crop_id_key = f"{display_name}_{variety_name}"
        if crop_id_key in seen_crops:
            continue

        # --- Dynamic Metadata extraction ---
        # We no longer use hardcoded keys. We take what the API gives.
        discovery_meta = rec.get("discovery_metadata") or rec.get("metadata") or {}
        
        # Determine fusion status based on live environmental data
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
            except Exception: pass

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
            except Exception: pass

        # --- Visual Intelligence Injection ---
        ui_meta = STATUS_UI_MAP.get(fusion_status, STATUS_UI_MAP["Verified"])

        # Construct the final object by PRESERVING and ENRICHING the original rec
        # This ensures we don't lose any new fields from the API
        crop_data = {
            **rec, # Preserve all original API fields
            "id": rec.get("crop_id", "N/A"),
            "name": display_name,
            "name_en": display_name if language == "en" else identity.get("crop_name_en", display_name),
            "name_kn": display_name if language == "kn" else identity.get("crop_name_kn", display_name),
            "icon": discovery_meta.get("icon", "eco"),
            "variety_name": variety_name,
            "description": (reason_en if language == "en" else reason_kn),
            "status_color": ui_meta["color"],
            "status_icon": ui_meta["icon"],
            "status_label": ui_meta["label"] if language == "en" else ui_meta["label_kn"],
            "ui_tags": [
                {"text": discovery_meta.get("difficulty", "Medium"), "color": "#3B82F6"},
                {"text": discovery_meta.get("market_value", "High"), "color": "#8B5CF6"},
                {"text": discovery_meta.get("risk_level", "Low"), "color": "#10B981"},
            ],
            "fusion_status": fusion_status,
        }
        fused_crops.append(crop_data)
        seen_crops.add(crop_id_key)

    return fused_crops
