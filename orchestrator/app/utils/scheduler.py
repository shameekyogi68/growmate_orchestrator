import asyncio
from datetime import datetime
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.triggers.cron import CronTrigger
from app.utils.config import get_settings
from app.utils.logger import logger
from app.external.market_api import fetch_market_prices
from app.utils.cache import cache_client
from app.utils.database import fetch_all

# Singleton scheduler instance
scheduler = AsyncIOScheduler()

# Top crops to pre-fetch prices for
TOP_CROPS = [
    ("Paddy", "Common"),
    ("Groundnut", "TMV-2"),
    ("Paddy", "Mahaveer"),
]

async def refresh_market_prices():
    """Pre-fetches market prices for top crops and caches them in Redis."""
    settings = get_settings()
    logger.info("[Scheduler] [Market] Starting market price refresh...")
    
    for crop, variety in TOP_CROPS:
        try:
            data = await fetch_market_prices(crop, variety, language="en")
            # TTL: interval + 5 minutes buffer
            ttl = (settings.market_refresh_interval_minutes * 60) + 300
            await cache_client.set_cached_advisory(
                f"market:{crop}:{variety}",
                data,
                ttl_seconds=ttl,
            )
            logger.info(f"[Scheduler] [Market] Updated {crop}/{variety}: {data.get('modal_price', 'N/A')}")
        except Exception as e:
            logger.error(f"[Scheduler] [Market] Error refreshing {crop}/{variety}: {e}")

async def monitor_external_services():
    """Health monitor for ALL upstream microservices and third-party APIs."""
    import httpx
    settings = get_settings()
    endpoints = {
        "Discovery": f"{settings.discovery_api_url}/health",
        "Recommendation": f"{settings.recommendation_api_url}/health",
        "Rainfall": f"{settings.rainfall_api_url}/health",
        "Soil": f"{settings.soil_api_url}/health",
        "Calendar": f"{settings.calendar_api_url}/health",
        "Weather API": f"https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/Udupi?key={settings.weather_api_key}",
        "Agro API": f"http://api.agromonitoring.com/agro/1.0/polygons?appid={settings.agro_api_key}"
    }
    
    async with httpx.AsyncClient(timeout=15.0) as client:
        for name, url in endpoints.items():
            try:
                # Some local services might use /health instead of /docs
                resp = await client.get(url)
                # Success for external APIs might be 200, for internal it depends
                status = "✅" if resp.status_code < 400 else f"⚠️ {resp.status_code}"
            except Exception as e:
                status = f"❌ Error: {str(e)[:20]}"
            logger.info(f"[Scheduler] [Health] {name} Service: {status}")

async def localized_engagement_broadcast():
    """
    Broadcasts localized farming tips.
    Runs daily or on interval to keep users engaged.
    """
    from app.services.notification_service import notify_user
    
    logger.info("[Scheduler] [Notify] Generating personalized engagement broadcast...")
    try:
        users = await fetch_all(
            "SELECT id, full_name, language, active_crop FROM users WHERE fcm_token IS NOT NULL"
        )
        
        for user in users:
            uid = user['id']
            lang = user.get('language', 'kn') # Default to Kannada given the context
            name = user.get('full_name', 'Farming Partner')
            crop = user.get('active_crop', 'crops') or "crops"
            
            if lang == 'kn':
                title = "ಗ್ರೋಮೇಟ್ ಕೃಷಿ ಸಲಹೆ 🌾"
                # The user's specific request: "ಇದ್ರೆ ಅವನಮ್ಮನ್ ನೆಮ್ಮದಿ ಆಗಿರಬೇಕು!" 
                # Integrating it as a "Peace of mind" message for farmers
                body = f"ನಮಸ್ಕಾರ {name}, {crop} ಬೆಳೆಗೆ ಸರಿಯಾದ ಸಮಯಕ್ಕೆ ನೀರು ಹಾಯಿಸಿ. ಕೃಷಿ ನೆಮ್ಮದಿಯಿಂದಿರಲಿ!"
            else:
                title = "GrowMate Farming Tip 🌾"
                body = f"Hi {name}, ensure timely irrigation for your {crop}. Stay productive!"

            # Async notification
            asyncio.create_task(notify_user(uid, title, body, {"type": "daily_engagement"}))
            
        logger.info(f"[Scheduler] [Notify] Broadcast queued for {len(users)} users.")
    except Exception as e:
        logger.error(f"[Scheduler] [Notify] Broadcast failed: {e}")

async def start_scheduler():
    """Configure and start the background scheduler."""
    settings = get_settings()
    
    if scheduler.running:
        logger.warning("[Scheduler] Scheduler is already running.")
        return

    # 1. Market Price Refresh (Every X minutes)
    scheduler.add_job(
        refresh_market_prices,
        trigger=IntervalTrigger(minutes=settings.market_refresh_interval_minutes),
        id="market_refresh",
        replace_existing=True,
        next_run_time=datetime.now() # Run immediately on startup
    )

    # 2. Health Monitoring (Every 15 minutes)
    scheduler.add_job(
        monitor_external_services,
        trigger=IntervalTrigger(minutes=15),
        id="health_monitor",
        replace_existing=True
    )

    # 3. Daily Broadcast (Every Morning at 8 AM)
    scheduler.add_job(
        localized_engagement_broadcast,
        trigger=CronTrigger(hour=8, minute=0),
        id="daily_engagement",
        replace_existing=True
    )

    scheduler.start()
    logger.info("[Scheduler] APScheduler started successfully.")

async def stop_scheduler():
    """Gracefully shutdown the scheduler."""
    if scheduler.running:
        scheduler.shutdown()
        logger.info("[Scheduler] APScheduler stopped.")
