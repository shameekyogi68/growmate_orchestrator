import httpx
from app.utils.config import get_settings
from app.utils.logger import logger


async def get_soil_advisory(
    latitude: float,
    longitude: float,
    language: str = "en",
    crop: str = "Paddy",
    sowing_date: str | None = None,
):
    payload = {
        "lat": latitude,
        "lon": longitude,
        "crop": crop,
        "language": language,
        "sowing_date": sowing_date,
    }

    settings = get_settings()
    async with httpx.AsyncClient(timeout=settings.default_timeout_seconds) as client:
        try:
            response = await client.post(
                f"{settings.soil_api_url}/api/advisory", json=payload
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Error fetching live soil advisory: {e}")
            return get_mock_soil_advisory(language)


def get_mock_soil_advisory(language: str):
    from app.services.agronomy_knowledge import get_local_crop_advice

    local_soil = get_local_crop_advice("Paddy", "soil", language)

    return {
        "moisture": "adequate" if language == "en" else "ಪರ್ಯಾಪ್ತ",
        "ph": 5.4,
        "deficiency_report": (
            "Nitrogen and Phosphorus deficiency detected."
            if language == "en"
            else "ಸಾರಜನಕ ಮತ್ತು ರಂಜಕದ ಕೊರತೆ ಪತ್ತೆಯಾಗಿದೆ."
        ),
        "corrective_measures": local_soil.get("low_ph"),
        "recommendation": local_soil.get("deficiency_nitrogen"),
    }
