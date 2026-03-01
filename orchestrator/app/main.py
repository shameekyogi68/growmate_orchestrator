from fastapi import FastAPI, Request
import uuid
import contextvars
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from starlette.middleware.gzip import GZipMiddleware
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.controllers import advisory_controller, user_controller, rainfall_controller
from app.utils.logger import logger
from app.utils.config import get_settings
from app.utils.database import init_db, close_db, get_pool
from app.utils.cache import cache_client
from app.utils.scheduler import start_scheduler, stop_scheduler

from app.utils.logger import logger, request_id_ctx


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle: startup and shutdown hooks."""
    settings = get_settings()
    logger.info(
        f"Starting {settings.app_name} v{settings.app_version} "
        f"({settings.environment})"
    )

    # Startup
    await init_db()
    await start_scheduler()
    logger.info("Application startup complete.")

    yield

    # Shutdown
    await stop_scheduler()
    await cache_client.close()
    await close_db()
    logger.info("Application shutdown complete.")


settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    description="Unified Backend API for GrowMate — Intelligent Farming Platform",
    version=settings.app_version,
    lifespan=lifespan,
)

# NFR: Compress responses > 500 bytes for mobile bandwidth savings
app.add_middleware(GZipMiddleware, minimum_size=500)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:8080",
        "https://growmate-web.vercel.app",
        "https://growmate.shameekyogi.com"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    ip = request.client.host if request.client else "unknown"
    client = cache_client._get_client()
    
    if client:
        try:
            # IP Rate Limiting (100 per minute)
            ip_key = f"rl:ip:{ip}"
            ip_count = await client.incr(ip_key)
            if ip_count == 1:
                await client.expire(ip_key, 60)
            elif ip_count > 100:
                return JSONResponse(status_code=429, content={"detail": "Too many requests per IP"})
                
            # User/Token Rate Limiting (30 per minute)
            auth_header = request.headers.get("Authorization")
            if auth_header and auth_header.startswith("Bearer "):
                token = auth_header.split(" ")[1]
                user_key = f"rl:user:{token[-30:]}"
                user_count = await client.incr(user_key)
                if user_count == 1:
                    await client.expire(user_key, 60)
                elif user_count > 30:
                    return JSONResponse(status_code=429, content={"detail": "Too many requests per user"})
        except Exception as e:
            logger.error(f"Rate limiter error (failing open): {e}")
            pass
            
    response = await call_next(request)
    return response


@app.middleware("http")
async def add_request_id(request: Request, call_next):
    """Injects a unique request ID per-request using contextvars."""
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    token = request_id_ctx.set(request_id)
    try:
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response
    finally:
        request_id_ctx.reset(token)


app.include_router(advisory_controller.router)
app.include_router(user_controller.router)
app.include_router(rainfall_controller.router)


@app.get("/health")
async def health_check():
    """Health check with database and environment status."""
    from app.utils.resilience import REGISTRY

    db_status = "connected" if get_pool() else "disconnected (DB-less mode)"
    return {
        "status": "healthy",
        "version": settings.app_version,
        "environment": settings.environment,
        "database": db_status,
        "circuit_breakers": {
            name: breaker.state.value for name, breaker in REGISTRY.items()
        },
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
