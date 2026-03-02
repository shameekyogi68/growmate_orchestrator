from pydantic_settings import BaseSettings
from pydantic import Field
from functools import lru_cache


class Settings(BaseSettings):
    """Centralized configuration for the GrowMate Orchestrator."""

    # --- App ---
    app_name: str = "GrowMate API"
    app_version: str = "2.1.0"
    environment: str = "development"
    debug: bool = False

    # --- Security ---
    jwt_secret_key: str = Field(
        default="growmate-dev-secret-key-1234", alias="JWT_SECRET_KEY"
    )
    jwt_algorithm: str = "HS256"
    jwt_expiry_minutes: int = 1440  # 24 hours

    # --- Database ---
    database_url: str | None = Field(default=None, alias="DATABASE_URL")

    # --- Redis ---
    redis_url: str = Field(default="redis://localhost:6379", alias="REDIS_URL")

    # --- External API Keys ---
    india_data_api_key: str | None = Field(default=None, alias="INDIA_DATA_API_KEY")
    agro_api_key: str | None = Field(default=None, alias="AGRO_API_KEY")
    weather_api_key: str | None = Field(default=None, alias="WEATHER_API_KEY")

    # --- External API Base URLs ---
    recommendation_api_url: str = 'https://crop-advisory-api.onrender.com'
    discovery_api_url: str = 'https://crop-discovery-api.onrender.com'
    soil_api_url: str = "https://soil-advisory-api.onrender.com"
    rainfall_api_url: str = "https://rainfall-advisory-api-1.onrender.com"
    calendar_api_url: str = "https://crop-calendar-api-tq0m.onrender.com"
    market_api_url: str = (
        "https://api.data.gov.in/resource/35985678-0d79-46b4-9ed6-6f13308a1d24"
    )
    ndvi_api_url: str = "http://api.agromonitoring.com/agro/1.0"
    weather_api_url: str = (
        "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline"
    )

    # --- Timeouts ---
    default_timeout_seconds: float = 30.0
    advisory_orchestration_timeout: float = 30.0
    market_max_concurrency: int = 3

    # --- Scheduler ---
    market_refresh_interval_minutes: int = 30
    health_check_interval_minutes: int = 5

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "extra": "ignore",
    }


@lru_cache()
def get_settings() -> Settings:
    """Returns a cached singleton of the application settings."""
    return Settings()
