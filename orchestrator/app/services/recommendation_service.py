import httpx
import asyncio
from app.utils.config import get_settings
from app.utils.logger import logger
from app.external.market_api import fetch_market_prices

def normalize_value(value_str: str) -> str:
    """Standardizes unit strings (e.g., 'quintal' -> 'Quintal') for UI consistency."""
    if not value_str or value_str == "N/A":
        return "N/A"
    return value_str.strip().capitalize()


async def get_crop_recommendations(
    latitude: float, longitude: float, date: str, language: str | None = None
):
    """
    Fetches zone-specific crop recommendations from the live Agronomic API.
    Transforms the live API response into the documented target schema.
    """
    payload = {"latitude": latitude, "longitude": longitude, "date": date}

    if language:
        payload["language"] = language

    settings = get_settings()
    async with httpx.AsyncClient(timeout=settings.default_timeout_seconds) as client:
        try:
            response = await client.post(
                f"{settings.recommendation_api_url}/recommend", json=payload
            )
            response.raise_for_status()
            data = response.json()
            raw_data = data.get("recommendations", [])

            # Handle empty response (trigger fallback)
            if not raw_data:
                logger.warning("Live API returned empty recommendations. Triggering fallback.")
                return await get_fallback_recommendations(language)

            # Handle dictionary of seasons (new format)
            if isinstance(raw_data, dict):
                mapped_output = {}
                for season, crops in raw_data.items():
                    # NFR: Pass lite=True for discovery flow to optimize market fetches
                    mapped_output[season] = await map_recommendations(crops, language, lite=True)
                return mapped_output

            # Handle flat list (fallback/legacy)
            return await map_recommendations(raw_data, language, lite=True)

        except Exception as e:
            logger.error(f"Error fetching live crop recommendations: {e}")
            return await get_fallback_recommendations(language)

async def get_fallback_recommendations(language: str) -> dict:
    """Provides a hardy, research-backed crop list if the external API is down."""
    logger.warning("Using Deep Seasonal Fallback for crop discovery.")
    # Local curated seed data (Representative of Udupi/Coastal region)
    seed_data = {
        "Summer": [
            {
                "crop_id": "O001-F",
                "identity": {"crop_name": "Groundnut", "variety_name": "TMV-2", "crop_category": "Oilseed"},
                "agro_climatic_suitability": {"suitable_temperature_range": "20°C - 35°C", "suitable_rainfall_range": "500mm - 1500mm"},
                "morphological_characteristics": {"plant_height_range": "45cm - 60cm", "growth_habit": "Spreading", "maturity_duration_range": "105 days"},
                "seed_specifications": {"seed_rate_per_acre": "5-10 kg", "germination_period": "4-7 days", "seed_viability_period": "6 months"},
                "yield_potential": {"average_yield_per_acre": "9.0 quintal", "yield_range_under_normal_conditions": "7.2 - 10.8 quintal"},
                "sensitivity_profile": {"drought_sensitivity_level": "Medium", "waterlogging_sensitivity_level": "High", "heat_tolerance_level": "Medium"},
                "end_use_information": {"main_use_type": "Commercial", "market_category": "Grade A"}
            }
        ],
        "Kharif": [
            {
                "crop_id": "C001-F",
                "identity": {"crop_name": "Paddy", "variety_name": "MO-4 (Bhadra)", "crop_category": "Cereal"},
                "agro_climatic_suitability": {"suitable_temperature_range": "22°C - 32°C", "suitable_rainfall_range": "1500mm - 4000mm"},
                "morphological_characteristics": {"plant_height_range": "90cm - 120cm", "growth_habit": "Erect", "maturity_duration_range": "125 days"},
                "seed_specifications": {"seed_rate_per_acre": "25-30 kg", "germination_period": "4-7 days", "seed_viability_period": "9 months"},
                "yield_potential": {"average_yield_per_acre": "20.0 quintal", "yield_range_under_normal_conditions": "16.0 - 24.0 quintal"},
                "sensitivity_profile": {"drought_sensitivity_level": "Medium", "waterlogging_sensitivity_level": "Low", "heat_tolerance_level": "Medium"},
                "end_use_information": {"main_use_type": "Food Grain", "market_category": "Grade A"}
            }
        ]
    }
    
    mapped_output = {}
    for season, crops in seed_data.items():
        mapped_output[season] = await map_recommendations(crops, language)
    return mapped_output


async def map_recommendations(crops: list, language: str, lite: bool = False) -> list:
    # 1. Prepare unique market price tasks to avoid redundant fetching
    unique_crops = {}
    for rec in crops:
        identity = rec.get("identity", {})
        crop_name = identity.get("crop_name", "N/A")
        # In lite mode (Discovery), we only fetch at the Crop level to save OGD hits
        variety_name = None if lite else identity.get("variety_name", "N/A")
        
        # Key by Crop + Variety
        key = (crop_name, variety_name)
        if key not in unique_crops:
            unique_crops[key] = fetch_market_prices(crop_name, variety_name, language=language)

    # 2. Fetch all unique prices concurrently
    keys = list(unique_crops.keys())
    market_results = await asyncio.gather(*unique_crops.values())
    market_map = dict(zip(keys, market_results))

    mapped_recs = []
    for rec in crops:
        identity = rec.get("identity", {})
        crop_name = identity.get("crop_name", "N/A")
        variety_name = None if lite else identity.get("variety_name", "N/A")
        market_info = market_map.get((crop_name, variety_name), {})

        agro = rec.get("agro_climatic_suitability", {})
        morph = rec.get("morphological_characteristics", {})
        seed = rec.get("seed_specifications", {})
        yield_pot = rec.get("yield_potential", {})
        sensitivity = rec.get("sensitivity_profile", {})
        end_use = rec.get("end_use_information", {})

        mapped = {
            "crop_id": rec.get("crop_id", "N/A"),
            "identity": {
                "crop_name": crop_name,
                "variety_name": variety_name,
                "crop_category": identity.get(
                    "crop_category", rec.get("crop_category", "N/A")
                ),
            },
            "financial_intelligence": {
                "modal_price": market_info.get("modal_price", "N/A"),
                "min_price": market_info.get("min_price", "N/A"),
                "max_price": market_info.get("max_price", "N/A"),
                "market_status": market_info.get("status", "Live"),
                "market_name": market_info.get("market_name", "Local APMC"),
                "source": market_info.get("source", "Agmarknet"),
            },
            "agro_climatic_suitability": {
                "suitable_temperature_range": agro.get(
                    "suitable_temperature_range", "20°C - 35°C"
                ),
                "suitable_rainfall_range": agro.get(
                    "suitable_rainfall_range", "1000mm - 4000mm"
                ),
                "suitable_soil_types": agro.get("suitable_soil_types", "N/A"),
                "suitable_soil_ph_range": agro.get(
                    "suitable_soil_ph_range", "4.0 - 7.0"
                ),
            },
            "morphological_characteristics": {
                "plant_height_range": morph.get("plant_height_range", "N/A"),
                "growth_habit": morph.get("growth_habit", "N/A"),
                "maturity_duration_range": normalize_value(morph.get("maturity_duration_range", "N/A")),
            },
            "seed_specifications": {
                "seed_rate_per_acre": normalize_value(seed.get("seed_rate_per_acre", "N/A")),
                "germination_period": normalize_value(seed.get("germination_period", "N/A")),
                "seed_viability_period": normalize_value(seed.get("seed_viability_period", "N/A")),
            },
            "yield_potential": {
                "average_yield_per_acre": normalize_value(yield_pot.get("average_yield_per_acre", "N/A")),
                "yield_range_under_normal_conditions": normalize_value(yield_pot.get("yield_range_under_normal_conditions", "N/A")),
            },
            "sensitivity_profile": {
                "drought_sensitivity_level": sensitivity.get(
                    "drought_sensitivity_level", "Medium"
                ),
                "waterlogging_sensitivity_level": sensitivity.get(
                    "waterlogging_sensitivity_level", "Low"
                ),
                "heat_tolerance_level": sensitivity.get(
                    "heat_tolerance_level", "Medium"
                ),
            },
            "end_use_information": {
                "main_use_type": end_use.get("main_use_type", "Food Grain"),
                "market_category": end_use.get("market_category", "Grade A"),
            },
            "raw_advisory": rec.get("advisory", "N/A"),
        }
        mapped_recs.append(mapped)
    return mapped_recs
