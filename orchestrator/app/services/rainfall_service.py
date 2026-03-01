import httpx
from app.utils.config import get_settings
from app.utils.logger import logger


async def get_rainfall_advisory(
    latitude: float,
    longitude: float,
    date: str,
    language: str = "en",
    intelligence_only: bool = False,
):
    payload = {
        "user_id": "growmate_internal",
        "latitude": latitude,
        "longitude": longitude,
        "date": date,
        "language": language,
        "intelligence_only": intelligence_only,
    }

    settings = get_settings()
    async with httpx.AsyncClient(timeout=settings.default_timeout_seconds) as client:
        try:
            response = await client.post(
                f"{settings.rainfall_api_url}/get-advisory", json=payload
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Error fetching live rainfall advisory: {e}")
            return {
                "status": "DEGRADED",
                "message": "Rainfall data unavailable",
                "confidence_score": 0.5,
                "source": "rainfall"
            }


async def get_enhanced_rainfall_advisory(
    latitude: float, longitude: float, date: str, language: str = "en"
):
    payload = {
        "user_id": "growmate_internal",
        "latitude": latitude,
        "longitude": longitude,
        "date": date,
        "language": language,
    }

    settings = get_settings()
    async with httpx.AsyncClient(timeout=settings.default_timeout_seconds) as client:
        try:
            response = await client.post(
                f"{settings.rainfall_api_url}/get-enhanced-advisory", json=payload
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Error fetching live enhanced rainfall advisory: {e}")
            return None
