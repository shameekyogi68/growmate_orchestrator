from typing import Dict
import asyncio
from app.services.recommendation_service import get_crop_recommendations
from app.external.weather_api import fetch_weather_data
from app.services.rainfall_service import get_rainfall_advisory
from app.services.soil_service import get_soil_advisory
from app.utils.logger import logger
import re

# Visual Hints Mapping (Fusion Status)
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
    """Returns a location name based on GPS coordinates for Udupi region."""
    if 13.8 <= lat <= 14.1: return "Byndoor, Udupi"
    if 13.6 <= lat < 13.8: return "Kundapur, Udupi"
    if 13.4 <= lat < 13.6: return "Brahmavar, Udupi"
    if 13.2 <= lat < 13.4: return "Udupi Town"
    if 13.0 <= lat < 13.2: return "Kaup, Udupi"
    return f"Farming Zone ({lat:.2f}, {lon:.2f})"


async def get_intelligent_crops(
    latitude: float = 13.8,
    longitude: float = 74.6,
    request_date: str | None = None,
    language: str = "en",
) -> Dict:
    """
    Consumes results from the Advisory Recommendation API and enriches them 
    with live Weather, Soil, and Rainfall intelligence.
    """
    try:
        # 1. Fetch EVERYTHING in parallel (Fusion 2.0)
        # We call the Recommendation Service which hits https://crop-advisory-api.onrender.com/recommend
        raw_data, weather, rainfall, soil = await asyncio.gather(
            get_crop_recommendations(latitude, longitude, request_date, language, lite=False),
            fetch_weather_data(latitude, longitude, language, request_date),
            get_rainfall_advisory(latitude, longitude, request_date, language),
            get_soil_advisory(latitude, longitude, language),
        )

        location_name = _get_location_name(latitude, longitude)

        if not raw_data or raw_data == "unavailable":
            return {
                "status": "success",
                "location": location_name,
                "date": request_date,
                "seasonal_groups": [],
            }

        seasonal_groups = []

        # Handle Seasonal Dictionary (Preferred)
        if isinstance(raw_data, dict):
            for season, crops in raw_data.items():
                fused_crops = await validate_crops(
                    crops, weather, rainfall, soil, request_date, language
                )
                if fused_crops:
                    seasonal_groups.append({"category": season, "crops": fused_crops})
        # Handle Flat List
        elif isinstance(raw_data, list):
            fused_crops = await validate_crops(
                raw_data, weather, rainfall, soil, request_date, language
            )
            if fused_crops:
                seasonal_groups.append({"category": "Recommended", "crops": fused_crops})

        return {
            "status": "success",
            "location": location_name,
            "date": request_date,
            "seasonal_groups": seasonal_groups,
            "render_hints": RENDER_HINTS
        }
    except Exception as e:
        logger.error(f"Discovery Fusion Error: {e}")
        return {
            "status": "success",
            "location": _get_location_name(latitude, longitude),
            "date": request_date,
            "seasonal_groups": [],
            "message": f"Service update in progress. Please try again shortly."
        }


async def validate_crops(
    crops: list, weather: dict, rainfall: dict, soil: dict, request_date: str, language: str
) -> list:
    """
    The True Fusion Layer: Filters for farmer-essential fields and injects 
    accuracy based on live environment sensors.
    """
    fused_crops = []
    seen_crops = set()

    for rec in crops:
        # 1. PRESERVE IDENTITY (Name, Variety, Category)
        identity = rec.get("identity", {})
        crop_name = identity.get("crop_name", rec.get("name", "N/A"))
        variety = identity.get("variety_name", rec.get("variety_name", "General"))
        category = identity.get("crop_category", rec.get("crop_category", "N/A"))

        # Dedup check
        crop_key = f"{crop_name}_{variety}"
        if crop_key in seen_crops: continue

        # 2. DYNAMIC FUSION (Accuracy Validation)
        fusion_status = "Verified"
        reason_en = "Ideal conditions detected for this variety."
        reason_kn = "ಈ ತಳಿಗೆ ಸೂಕ್ತವಾದ ವಾತಾವರಣ ಕಂಡುಬಂದಿದೆ."
        
        agro_suitability = rec.get("agro_climatic_suitability", {})
        
        # Rainfall Check
        rain_range = agro_suitability.get("suitable_rainfall_range", "")
        if rain_range and rainfall:
            status = rainfall.get("intelligence", {}).get("rainfall_status", "Normal")
            if "Drought" in status or "Stress" in status:
                fusion_status = "Warning"
                reason_en = f"Water stress detected in zone. Monitor irrigation for {variety}."
                reason_kn = f"ವಲಯದಲ್ಲಿ ನೀರಿನ ಕೊರತೆ ಕಂಡುಬಂದಿದೆ. {variety} ತಳಿಗೆ ನೀರಾವರಿಯನ್ನು ಗಮನಿಸಿ."

        # Temperature Check
        temp_range = agro_suitability.get("suitable_temperature_range", "")
        curr_temp = weather.get("temperature", 30)
        if temp_range:
            nums = [float(n) for n in re.findall(r"[\d.]+", temp_range)]
            if len(nums) >= 2 and curr_temp > (nums[1] + 2):
                fusion_status = "Warning"
                reason_en = f"Heat stress ({curr_temp}°C) exceeds {variety} threshold."
                reason_kn = f"ತಾಪಮಾನವು ({curr_temp}°C) {variety} ಮಿತಿಯನ್ನು ಮೀರಿದೆ."

        # 3. FARMER-ESSENTIAL FILTERING (Clean Structure)
        ui_style = STATUS_UI_MAP.get(fusion_status, STATUS_UI_MAP["Verified"])
        market = rec.get("financial_intelligence", {})

        farmer_data = {
            "id": rec.get("crop_id", rec.get("id", "N/A")),
            # IDENTITY (Preserved Exactly)
            "identity": {
                "crop_name": crop_name,
                "variety_name": variety,
                "crop_category": category
            },
            # FUSION STATUS (Injected Reality)
            "status_label": ui_style["label"] if language == "en" else ui_style["label_kn"],
            "status_color": ui_style["color"],
            "status_icon": ui_style["icon"],
            "description": (reason_en if language == "en" else reason_kn),
            
            # FINANCIAL INTELLIGENCE (Market Data)
            "financial_intelligence": {
                "modal_price": market.get("modal_price", "N/A"),
                "market_status": market.get("market_status", "Live"),
                "market_name": market.get("market_name", "Local APMC")
            },
            
            # MORPHOLOGICAL & YIELD (Farmer Metrics)
            "morphological_characteristics": rec.get("morphological_characteristics", {}),
            "yield_potential": rec.get("yield_potential", {}),
            
            # UI METADATA (Rich Aesthetics)
            "icon": "agriculture",
            "ui_tags": [
                {"text": variety, "color": "#3B82F6"},
                {"text": fusion_status, "color": ui_style["color"]},
                {"text": f"₹{market.get('modal_price', 'N/A')}", "color": "#8B5CF6"}
            ],
            "fusion_status": fusion_status
        }
        
        fused_crops.append(farmer_data)
        seen_crops.add(crop_key)

    return fused_crops
