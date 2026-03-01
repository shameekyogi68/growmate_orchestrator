import httpx
from app.utils.config import get_settings
from app.utils.logger import logger


async def fetch_weather_data(
    latitude: float,
    longitude: float,
    language: str = "en",
    request_date: str | None = None,
):
    settings = get_settings()
    api_key = settings.weather_api_key

    if not api_key:
        logger.warning("WEATHER_API_KEY not found. Returning mock weather data.")
        return get_mock_weather_data(language, request_date)

    # Fetching today's summary
    params = {
        "unitGroup": "metric",
        "include": "current",
        "key": api_key,
        "contentType": "json",
    }

    url = f"{settings.weather_api_url}/{latitude},{longitude}/today"

    async with httpx.AsyncClient(timeout=settings.default_timeout_seconds) as client:
        try:
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            current = data.get("currentConditions", {})
            condition_en = current.get("conditions", "Sunny")

            return {
                "temperature": current.get("temp", 30),
                "humidity": current.get("humidity", 50),
                "condition": translate_condition(condition_en, language),
                "wind_speed": current.get("windspeed", 10),
                "uv_index": current.get("uvindex", 5),
                "source": "Visual Crossing",
            }
        except Exception as e:
            logger.error(f"Error fetching live weather data: {e}")
            return get_mock_weather_data(language)


def translate_condition(condition: str, language: str):
    if language != "kn":
        return condition

    # Simple mapping for common conditions
    mapping = {
        "Sunny": "ಬಿಸಿಲು",
        "Clear": "ಶುಭ್ರ ಆಕಾಶ",
        "Partly cloudy": "ಭಾಗಶಃ ಮೋಡ",
        "Cloudy": "ಮೋಡ ಮುಸುಕಿದ ವಾತಾವರಣ",
        "Overcast": "ಮೋಡ ಕವಿದ",
        "Rain": "ಮಳೆ",
        "Rain, Overcast": "ಮಳೆ, ಮೋಡ ಕವಿದ",
        "Rain, Partly cloudy": "ಮಳೆ, ಭಾಗಶಃ ಮೋಡ",
    }
    return mapping.get(condition, condition)


def get_mock_weather_data(language: str, request_date: str | None = None):
    from datetime import datetime, timezone

    try:
        month = (
            datetime.strptime(request_date, "%Y-%m-%d").month
            if request_date
            else datetime.now(timezone.utc).month
        )
    except (ValueError, TypeError):
        month = 6

    # Monsoon (June-Sept)
    if 6 <= month <= 9:
        temp, cond_en, cond_kn, hum = 27, "Heavy Rain", "ಭಾರಿ ಮಳೆ", 85
    # Winter/Rabi (Nov-Feb)
    elif month in [11, 12, 1, 2]:
        temp, cond_en, cond_kn, hum = 29, "Clear Sky", "ಶುಭ್ರ ಆಕಾಶ", 60
    # Summer (March-May)
    else:
        temp, cond_en, cond_kn, hum = 34, "Hot and Humid", "ಬಿಸಿಲು ಮತ್ತು ತೇವಾಂಶ", 75

    if language == "kn":
        return {
            "temperature": temp,
            "condition": cond_kn,
            "humidity": hum,
            "source": "Udupi Seasonal Forecast (Mock)",
        }
    return {
        "temperature": temp,
        "condition": cond_en,
        "humidity": hum,
        "source": "Udupi Seasonal Forecast (Mock)",
    }
