import asyncio
import json
from datetime import datetime, timezone, timedelta
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.triggers.cron import CronTrigger
from app.utils.config import get_settings
from app.utils.logger import logger
from app.external.market_api import fetch_market_prices
from app.utils.cache import cache_client
from app.utils.database import fetch_all, execute

# Singleton scheduler instance
scheduler = AsyncIOScheduler()

# Top crops to pre-fetch prices for
TOP_CROPS = [
    ("Paddy", "Common"),
    ("Groundnut", "TMV-2"),
    ("Paddy", "Mahaveer"),
]

async def queue_scheduled_notification(user_id: int, title: str, body: str, scheduled_at: datetime, data: dict = None):
    """Utility to queue a future notification in the database."""
    await execute(
        "INSERT INTO scheduled_notifications (user_id, title, body, data, scheduled_at) VALUES ($1, $2, $3, $4, $5)",
        user_id, title, body, json.dumps(data or {}), scheduled_at
    )

async def process_scheduled_queue():
    """
    Industry Standard: Queue Processor.
    Checks for notifications that are due and sends them.
    Runs every 60 seconds.
    """
    from app.services.notification_service import send_push_notification
    
    now = datetime.now(timezone.utc)
    pending = await fetch_all(
        "SELECT s.*, u.fcm_token FROM scheduled_notifications s "
        "JOIN users u ON s.user_id = u.id "
        "WHERE s.status = 'pending' AND s.scheduled_at <= $1 AND u.fcm_token IS NOT NULL "
        "LIMIT 50", # Batch processing
        now
    )
    
    if not pending:
        return

    logger.info(f"[Scheduler] [Queue] Processing {len(pending)} due notifications...")
    
    for note in pending:
        try:
            success = await send_push_notification(
                note['fcm_token'],
                note['title'],
                note['body'],
                json.loads(note['data']) if note['data'] else {}
            )
            
            status = 'sent' if success else 'failed'
            await execute(
                "UPDATE scheduled_notifications SET status = $1, last_attempt = $2, attempts = attempts + 1 WHERE id = $3",
                status, now, note['id']
            )
        except Exception as e:
            logger.error(f"[Scheduler] [Queue] Failed to process notification {note['id']}: {e}")

async def generate_crop_lifecycle_notifications():
    """
    Industry Standard: Context-Aware Drip Campaign.
    Automatically queues notifications based on 'Days After Sowing' (DAS).
    Runs daily.
    """
    logger.info("[Scheduler] [Lifecycle] Running crop lifecycle check...")
    
    # Fetch users with active crops and valid tokens
    users = await fetch_all(
        "SELECT id, full_name, active_crop, active_sowing_date, language "
        "FROM users WHERE active_crop IS NOT NULL AND active_sowing_date IS NOT NULL "
        "AND fcm_token IS NOT NULL"
    )
    
    now = datetime.now(timezone.utc)
    
    for user in users:
        das = (now.date() - user['active_sowing_date']).days
        lang = user.get('language', 'kn')
        name = user.get('full_name', 'Farmer')
        crop = user['active_crop']
        
        # Industry Standard Strategy: Milestone Messaging
        milestones = {
            1: {
                "kn": ("ಬೆಳೆ ಕಾಳಜಿ 🌾", f"ನಮಸ್ಕಾರ {name}, ಸಸಿಗಳು ಮೊಳಕೆಯೊಡೆಯುತ್ತಿವೆ. ಈಗ ಕ್ಷೇತ್ರಕ್ಕೆ ಭೇಟಿ ನೀಡಿ ಕಳೆಗಳನ್ನು ಗಮನಿಸಿ."),
                "en": ("Crop Care 🌾", f"Hi {name}, seedlings are emerging. Visit your field today to check for weeds.")
            },
            15: {
                "kn": ("ಗೊಬ್ಬರ ನೀಡುವ ಸಮಯ 🚜", f"{name}, {crop} ಬೆಳೆಗೆ ಮೊದಲ ಸುತ್ತಿನ ಗೊಬ್ಬರ ಸೇರಿಸುವ ಸಮಯ ಬಂದಿದೆ."),
                "en": ("Fertilizer Alert 🚜", f"{name}, it's time for the first round of fertilizer for your {crop}.")
            },
            45: {
                "kn": ("ಕೀಟಗಳ ಎಚ್ಚರಿಕೆ 🐛", f"{name}, ನಿಮ್ಮ ಬೆಳೆಯನ್ನು ಕೀಟಬಾಧೆಯಿಂದ ರಕ್ಷಿಸಲು ಎಚ್ಚರದಿಂದಿರಿ."),
                "en": ("Pest Monitoring 🐛", f"{name}, keep an eye out for pests on your {crop} to ensure a healthy harvest.")
            }
        }
        
        if das in milestones:
            title, body = milestones[das].get(lang, milestones[das]['en'])
            # Queue for today at 6 PM (Localized evening briefing)
            scheduled_time = datetime.combine(now.date(), datetime.min.time(), tzinfo=timezone.utc) + timedelta(hours=18)
            
            # Avoid duplicate queuing for the same milestone
            exists = await fetch_all(
                "SELECT id FROM scheduled_notifications WHERE user_id = $1 AND title = $2 AND created_at >= $3",
                user['id'], title, now - timedelta(days=1)
            )
            
            if not exists:
                await queue_scheduled_notification(user['id'], title, body, scheduled_time, {"das": das, "crop": crop})
                logger.info(f"[Scheduler] [Lifecycle] Queued DAS {das} tip for user {user['id']}")

async def refresh_market_prices():
    """Pre-fetches market prices for top crops and caches them in Redis."""
    settings = get_settings()
    logger.info("[Scheduler] [Market] Starting market price refresh...")
    
    for crop, variety in TOP_CROPS:
        try:
            data = await fetch_market_prices(crop, variety, language="en")
            ttl = (settings.market_refresh_interval_minutes * 60) + 300
            await cache_client.set_cached_advisory(f"market:{crop}:{variety}", data, ttl_seconds=ttl)
            logger.info(f"[Scheduler] [Market] Updated {crop}/{variety}")
        except Exception as e:
            logger.error(f"[Scheduler] [Market] Error: {e}")

async def monitor_external_services():
    """Health monitor for ALL upstream microservices."""
    import httpx
    settings = get_settings()
    endpoints = {
        "Discovery": f"{settings.discovery_api_url}/health",
        "Recommendation": f"{settings.recommendation_api_url}/health",
        "Rainfall": f"{settings.rainfall_api_url}/health",
        "Weather API": f"https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/Udupi?key={settings.weather_api_key}",
        "Agro API": f"http://api.agromonitoring.com/agro/1.0/polygons?appid={settings.agro_api_key}"
    }
    
    async with httpx.AsyncClient(timeout=15.0) as client:
        for name, url in endpoints.items():
            try:
                resp = await client.get(url)
                status = "✅" if resp.status_code < 400 else f"⚠️ {resp.status_code}"
                logger.info(f"[Scheduler] [Health] {name}: {status}")
            except Exception as e:
                logger.info(f"[Scheduler] [Health] {name}: ❌")

async def start_scheduler():
    """Configure and start the background scheduler."""
    settings = get_settings()
    
    if scheduler.running:
        return

    # 1. Market Price Refresh (Every X minutes)
    scheduler.add_job(refresh_market_prices, trigger=IntervalTrigger(minutes=settings.market_refresh_interval_minutes), id="market_refresh", replace_existing=True, next_run_time=datetime.now())

    # 2. Health Monitoring (Every 15 minutes)
    scheduler.add_job(monitor_external_services, trigger=IntervalTrigger(minutes=15), id="health_monitor", replace_existing=True)

    # 3. Notification Queue Processor (Every 1 minute) - CRITICAL
    scheduler.add_job(process_scheduled_queue, trigger=IntervalTrigger(minutes=1), id="notif_queue_processor", replace_existing=True)

    # 4. Lifecycle Intelligence (Daily at 7 AM)
    scheduler.add_job(generate_crop_lifecycle_notifications, trigger=CronTrigger(hour=7, minute=0), id="lifecycle_intel", replace_existing=True)

    scheduler.start()
    logger.info("[Scheduler] Advanced Production Scheduler started.")

async def stop_scheduler():
    """Gracefully shutdown the scheduler."""
    if scheduler.running:
        scheduler.shutdown()
        logger.info("[Scheduler] APScheduler stopped.")
