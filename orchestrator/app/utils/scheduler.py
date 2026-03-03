import asyncio
from app.utils.config import get_settings
from app.utils.logger import logger
from app.external.market_api import fetch_market_prices
from app.utils.cache import cache_client

# Background task handles for graceful shutdown
_tasks: list[asyncio.Task] = []

# Top crops to pre-fetch prices for
TOP_CROPS = [
    ("Paddy", "Common"),
    ("Groundnut", "TMV-2"),
    ("Paddy", "Mahaveer"),
]


async def _refresh_market_prices():
    """Pre-fetches market prices for top crops and caches them in Redis."""
    settings = get_settings()
    interval = settings.market_refresh_interval_minutes * 60

    while True:
        try:
            logger.info("[Scheduler] Refreshing market prices for top crops...")
            for crop, variety in TOP_CROPS:
                try:
                    data = await fetch_market_prices(
                        crop, variety, language="en"
                    )
                    await cache_client.set_cached_advisory(
                        f"market:{crop}:{variety}",
                        data,
                        ttl_seconds=interval + 300,
                    )
                    logger.info(
                        f"[Scheduler] Cached price for {crop}/{variety}: "
                        f"{data.get('modal_price', 'N/A')}"
                    )
                except Exception as e:
                    logger.warning(
                        f"[Scheduler] Failed to refresh {crop}/{variety}: {e}"
                    )

            logger.info(
                f"[Scheduler] Market price refresh complete. "
                f"Next in {settings.market_refresh_interval_minutes}m."
            )
        except Exception as e:
            logger.error(f"[Scheduler] Market refresh cycle error: {e}")

        await asyncio.sleep(interval)


async def _health_monitor():
    """Periodically pings external APIs and logs their status."""
    import httpx

    settings = get_settings()
    interval = settings.health_check_interval_minutes * 60

    endpoints = {
        "Recommendation API": f"{settings.recommendation_api_url}/docs",
        "Discovery API": f"{settings.discovery_api_url}/docs",
        "Soil API": f"{settings.soil_api_url}/docs",
        "Rainfall API": f"{settings.rainfall_api_url}/docs",
        "Calendar API": f"{settings.calendar_api_url}/docs",
    }

    while True:
        try:
            # Render cold starts might take > 5s; using 30s timeout here
            async with httpx.AsyncClient(timeout=30.0) as client:
                for name, url in endpoints.items():
                    try:
                        resp = await client.get(url)
                        status = (
                            "✅ UP"
                            if resp.status_code < 500
                            else f"⚠️ {resp.status_code}"
                        )
                    except Exception:
                        status = "❌ DOWN"
                    logger.info(f"[HealthMonitor] {name}: {status}")
        except Exception as e:
            logger.error(f"[HealthMonitor] Cycle error: {e}")

        await asyncio.sleep(interval)


async def start_scheduler():
    """Starts all background tasks and tracks their handles."""
    logger.info("[Scheduler] Starting background tasks...")
    _tasks.append(asyncio.create_task(_refresh_market_prices()))
    _tasks.append(asyncio.create_task(_health_monitor()))


async def stop_scheduler():
    """Cancels all tracked background tasks for graceful shutdown."""
    logger.info("[Scheduler] Cancelling background tasks...")
    for task in _tasks:
        task.cancel()
    await asyncio.gather(*_tasks, return_exceptions=True)
    _tasks.clear()
    logger.info("[Scheduler] Background tasks stopped.")
