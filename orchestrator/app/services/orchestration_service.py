from datetime import datetime, timezone
from app.utils.logger import logger
from app.utils.cache import cache_client
from app.utils.parallel_executor import execute_parallel
from app.services.rainfall_service import get_rainfall_advisory
from app.services.soil_service import get_soil_advisory
from app.services.pest_service import get_pest_advisory
from app.services.calendar_service import get_calendar_advisory
from app.external.weather_api import fetch_weather_data
from app.external.market_api import fetch_market_prices
from app.services.schemes_service import get_udupi_schemes
from app.services.ndvi_service import get_ndvi_intelligence
from app.services.news_service import get_udupi_agri_news
from app.services.groundwater_service import get_udupi_groundwater_status
from app.services.mandi_tracker import get_mandi_arrivals
from app.services.seed_scanner_service import verify_seed_authenticity
from app.services.recommendation_service import get_crop_recommendations
from app.services.advisory_fusion_service import fuse_advisory
from app.services.notification_service import notify_user


async def orchestrate_farmer_advisory(req_data: dict):
    """
    Central orchestration logic (Business logic + Concurrency).
    """
    lat = req_data.get("latitude")
    lon = req_data.get("longitude")
    crop = req_data.get("crop", "Paddy")
    variety = req_data.get("variety", "General")
    sowing_date = req_data.get("sowing_date")
    language = req_data.get("language", "en")
    req_date = req_data.get("date")
    user_id = req_data.get("user_id")

    # 1. Transition Detection (if user_id provided)
    transition_view = None
    if str(user_id).isdigit():
        from app.utils.database import fetch_all

        all_crops = await fetch_all(
            "SELECT crop_name, sowing_date FROM user_crops WHERE user_id = $1",
            int(user_id),
        )
        if len(all_crops) > 1:
            now = datetime.now(timezone.utc)
            old_crops = [
                c for c in all_crops if (now.date() - c["sowing_date"]).days > 90
            ]
            new_crops = [
                c for c in all_crops if (now.date() - c["sowing_date"]).days < 30
            ]
            if old_crops and new_crops:
                transition_view = {
                    "is_active": True,
                    "outgoing_crop": old_crops[0]["crop_name"],
                    "incoming_crop": new_crops[0]["crop_name"],
                    "notice": (
                        "Transition Season Detected"
                        if language == "en"
                        else "ಬದಲಾಗುವ ಋತು ಪತ್ತೆಯಾಗಿದೆ"
                    ),
                }

    # 2. Season Detection
    try:
        dt = datetime.strptime(req_date, "%Y-%m-%d")
        month = dt.month
    except (ValueError, TypeError):
        month = datetime.now(timezone.utc).month

    season = (
        "kharif"
        if month in [6, 7, 8, 9, 10]
        else ("rabi" if month in [11, 12, 1, 2] else "summer")
    )

    # 3. Parallel Service Execution
    services = {
        "rainfall": get_rainfall_advisory(lat, lon, req_date, language),
        "soil": get_soil_advisory(lat, lon, language, crop, sowing_date),
        "pest": get_pest_advisory(
            crop, variety, sowing_date, language, request_date=req_date
        ),
        "calendar": get_calendar_advisory(season, crop, variety, language, sowing_date),
        "weather": fetch_weather_data(lat, lon, language, request_date=req_date),
        "market": fetch_market_prices(crop, variety, language=language),
        "schemes": get_udupi_schemes(language),
        "ndvi": get_ndvi_intelligence(lat, lon, language, request_date=req_date),
        "news": get_udupi_agri_news(language),
        "groundwater": get_udupi_groundwater_status(language),
        "mandi": get_mandi_arrivals(crop, language),
        "seed_check": verify_seed_authenticity("BATCH-2026-UDUPI", language),
        "recommendations": get_crop_recommendations(lat, lon, req_date, language),
    }

    raw_results = await execute_parallel(services, timeout=80.0)

    # 4. Partial Data & Cache Strategy
    partial_data = any(val == "unavailable" for val in raw_results.values())
    if partial_data:
        cached = await cache_client.get_cached_advisory(user_id)
        if cached:
            logger.info("Returning partially cached advisory")
            cached["partial_data"] = True
            return cached, True, raw_results

    # 5. Fusion
    fused = fuse_advisory(raw_results, language=language)
    fused["transition_view"] = transition_view

    # 6. Push Notification for High Priority Alerts (Async/Background)
    if str(user_id).isdigit():
        import asyncio

        for alert in fused.get("alerts", []):
            if alert.get("priority_level") == "HIGH" and alert.get("should_notify"):
                title = "GrowMate Alert" if language == "en" else "ಗ್ರೋಮೇಟ್ ಎಚ್ಚರಿಕೆ"
                body = alert.get("message", "High risk detected in your farm area.")
                asyncio.create_task(
                    notify_user(
                        int(user_id),
                        title,
                        body,
                        data={"alert_source": alert.get("source")},
                    )
                )
                break  # Only send one notification per advisory check

    # Cache successfully fused results
    await cache_client.set_cached_advisory(user_id, fused, ttl_seconds=600)

    return fused, partial_data, raw_results
