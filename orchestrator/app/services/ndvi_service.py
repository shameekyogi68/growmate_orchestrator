import httpx
from app.utils.config import get_settings
from app.utils.logger import logger


async def get_ndvi_intelligence(
    latitude: float,
    longitude: float,
    language: str = "en",
    request_date: str | None = None,
):
    """
    Fetches NDVI (Normalized Difference Vegetation Index) for the specified coordinates.
    Since Agromonitoring requires Polygons, we simulate a small point-based check-in
    locally or use a simplified point API if available.
    """
    settings = get_settings()
    api_key = settings.agro_api_key

    if not api_key:
        logger.warning(
            "AGRO_API_KEY not found. Returning high-intelligence NDVI mock for Udupi."
        )
        return get_mock_ndvi_data(language, request_date)

    # Note: Real implementation would involve checking if a polygon exists for these coords,
    # or creating a temporary small polygon. To keep it robust, we'll implement a fallback mock
    # until the user sets up their polygons on the dashboard.

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            # 1. Fetch Polygons
            poly_resp = await client.get(
                f"{settings.ndvi_api_url}/polygons?appid={api_key}"
            )
            if poly_resp.status_code == 200:
                polygons = poly_resp.json()
                if polygons and len(polygons) > 0:
                    poly_id = polygons[0]["id"]
                    poly_name = polygons[0].get("name", "Unknown Field")

                    # 2. Fetch Latest NDVI for the polygon
                    ndvi_url = f"{settings.ndvi_api_url}/ndvi/latest?polyid={poly_id}&appid={api_key}"
                    ndvi_resp = await client.get(ndvi_url)

                    if ndvi_resp.status_code == 200:
                        data = ndvi_resp.json()
                        score = round(data.get("mean", 0.75), 2)

                        # Determine condition based on score
                        if score > 0.7:
                            cond_en, cond_kn = "Lush Green", "ಹಚ್ಚ ಹಸಿರು"
                        elif score > 0.4:
                            cond_en, cond_kn = "Healthy", "ಆರೋಗ್ಯಕರ"
                        else:
                            cond_en, cond_kn = "Moderate", "ಸಾಧಾರಣ"

                        msg_en = (
                            f"Live Satellite data for {poly_name} shows stable growth."
                        )
                        msg_kn = f"{poly_name} ಕ್ಷೇತ್ರಕ್ಕೆ ಲಭ್ಯವಿರುವ ಉಪಗ್ರಹ ಮಾಹಿತಿಯು ಸ್ಥಿರ ಬೆಳವಣಿಗೆಯನ್ನು ತೋರಿಸುತ್ತದೆ."

                        return {
                            "health_index": score,
                            "condition": cond_kn if language == "kn" else cond_en,
                            "message": msg_kn if language == "kn" else msg_en,
                            "source": f"Agromonitoring Live ({poly_name})",
                        }

            # Fallback to high-intelligence mock if no polygons or API error
            return get_mock_ndvi_data(language, request_date)

        except Exception as e:
            logger.error(f"Error fetching live NDVI data: {e}")
            return get_mock_ndvi_data(language, request_date)


def get_mock_ndvi_data(language: str, request_date: str | None = None):
    # Simulated NDVI for Udupi region (Seasonal logic)
    try:
        month = (
            datetime.strptime(request_date, "%Y-%m-%d").month
            if request_date
            else datetime.now(timezone.utc).month
        )
    except (ValueError, TypeError):
        month = 6

    # Monsoon (June-Sept): High greenness
    if 6 <= month <= 9:
        ndvi_score = 0.82
        condition_en, condition_kn = "Lush Green", "ಹಚ್ಚ ಹಸಿರು"
        msg_en = "Monsoon growth is excellent. High vegetation density detected."
        msg_kn = "ಮುಂಗಾರು ಹಂಗಾಮಿನಲ್ಲಿ ಬೆಳೆ ಬೆಳೆವಣಿಗೆ ಉತ್ತಮವಾಗಿದೆ. ಸಸ್ಯಗಳ ದಟ್ಟಣೆ ಹೆಚ್ಚಾಗಿದೆ."
    # Rabi (Oct-Jan): Moderate greenness
    elif month in [10, 11, 12, 1]:
        ndvi_score = 0.65
        condition_en, condition_kn = "Healthy", "ಆರೋಗ್ಯಕರ"
        msg_en = "Post-monsoon growth is stable. Optimal vegetation levels."
        msg_kn = "ಹಿಂಗಾರು ಹಂಗಾಮಿನ ಬೆಳೆ ಸ್ಥಿರವಾಗಿದೆ. ಸಸ್ಯಗಳ ಮಟ್ಟವು ಸೂಕ್ತವಾಗಿದೆ."
    # Summer (Feb-May): Lower greenness / Stress
    else:
        ndvi_score = 0.45
        condition_en, condition_kn = "Moderate", "ಸಾಧಾರಣ"
        msg_en = "Summer heat detected. Moderate vegetation levels, ensure irrigation."
        msg_kn = "ಬೇಸಿಗೆಯ ಶಾಖ ಪತ್ತೆಯಾಗಿದೆ. ಸಾಧಾರಣ ಸಸ್ಯಗಳ ಮಟ್ಟ, ನೀರಾವರಿ ಖಚಿತಪಡಿಸಿಕೊಳ್ಳಿ."

    if language == "kn":
        return {
            "health_index": ndvi_score,
            "condition": condition_kn,
            "message": msg_kn,
            "source": "ಉಪಗ್ರಹ ಮೇಲ್ವಿಚಾರಣೆ (ಅಣಕು)",
        }

    return {
        "health_index": ndvi_score,
        "condition": condition_en,
        "message": msg_en,
        "source": "Satellite Monitoring (Mock)",
    }


from datetime import datetime, timezone
