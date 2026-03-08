import redis.asyncio as redis
from app.utils.config import get_settings
from app.utils.logger import logger
import json


class RedisCache:
    """Lazy-initialized Redis cache client. Connects on first use, not on import."""

    def __init__(self):
        self._redis: redis.Redis | None = None

    def _get_client(self) -> redis.Redis:
        if self._redis is None:
            settings = get_settings()
            kwargs = {"decode_responses": True}

            # Required for Render Managed Redis connections using TLS (rediss://)
            if settings.redis_url.startswith("rediss://"):
                kwargs["ssl_cert_reqs"] = "none"

            self._redis = redis.from_url(settings.redis_url, **kwargs)
        return self._redis

    async def get_cached_advisory(self, key: str):
        try:
            data = await self._get_client().get(f"advisory:{key}")
            if data:
                return json.loads(data)
            return None
        except Exception as e:
            logger.error(f"Redis get error: {e}")
            return None

    async def set_cached_advisory(self, key: str, data: dict, ttl_seconds: int = 600):
        try:
            await self._get_client().set(
                f"advisory:{key}", json.dumps(data), ex=ttl_seconds
            )
        except Exception as e:
            logger.error(f"Redis set error: {e}")

    async def close(self):
        """Gracefully close the Redis connection."""
        if self._redis:
            await self._redis.aclose()
            self._redis = None


cache_client = RedisCache()
