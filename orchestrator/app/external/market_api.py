import asyncio
import httpx
from app.utils.config import get_settings
from app.utils.logger import logger
from app.utils.cache import cache_client

# --- Performance: Local process-level cache for when Redis is unavailable ---
_LOCAL_MARKET_CACHE = {}

# --- NFR: Concurrency throttle to respect Gov API rate limits ---
# Limits concurrent requests to 3 at a time to avoid 429 errors
_MARKET_SEMAPHORE = asyncio.Semaphore(3)


async def fetch_market_prices(
    crop: str,
    variety: str | None = None,
    district: str = "Udupi",
    state: str = "Karnataka",
    language: str = "en",
):
    """
    Fetches real-time market prices from the data.gov.in (OGD) Market Pricing API.
    Filters by State, District, and Commodity.
    Uses a semaphore to throttle concurrent requests and avoid 429 rate-limit errors.
    """
    settings = get_settings()
    if not settings.india_data_api_key:
        logger.warning(
            "INDIA_DATA_API_KEY not configured. Returning mock market prices."
        )
        return get_mock_market_prices(crop, language)

    params = {
        "api-key": settings.india_data_api_key,
        "format": "json",
        "filters[state]": state,
        "filters[district]": district,
        "filters[commodity]": crop,
    }
    if variety:
        params["filters[variety]"] = variety

    # 1. Local Memory Cache Check
    cache_key = f"market:{state}:{district}:{crop}:{variety or 'Common'}:{language}"
    if cache_key in _LOCAL_MARKET_CACHE:
        return _LOCAL_MARKET_CACHE[cache_key]

    # 2. Redis Cache Check
    cached_data = await cache_client.get_cached_advisory(cache_key)
    if cached_data:
        _LOCAL_MARKET_CACHE[cache_key] = cached_data  # Hydrate local
        return cached_data

    # 3. Discovery Optimization: Don't broaden search endlessly for discovery lists
    is_discovery = variety is None

    # Throttle concurrent requests to the Gov API
    async with _MARKET_SEMAPHORE:
        async with httpx.AsyncClient(
            timeout=settings.default_timeout_seconds
        ) as client:
            try:
                # Phase 1: Try with exact crop and variety
                response = await client.get(settings.market_api_url, params=params)

                if response.status_code == 429:
                    logger.warning(
                        f"Rate limit hit for {crop}. Falling back to mock data."
                    )
                    return get_mock_market_prices(crop, language)

                response.raise_for_status()
                records = response.json().get("records", [])

                # Phase 2: Broaden search if no records found
                if not records:
                    # NFR: If in discovery, only try one broaden variation to save speed
                    records = await _broaden_search(
                        client, params, crop, limit=1 if is_discovery else None
                    )

                if records:
                    formatted = _format_live_response(records[0], variety, language)
                    # Cache to both layers
                    _LOCAL_MARKET_CACHE[cache_key] = formatted
                    await cache_client.set_cached_advisory(cache_key, formatted, 3600)
                    return formatted
                else:
                    logger.warning(
                        f"No market records found for {crop} after broadening search."
                    )

            except httpx.TimeoutException:
                logger.warning(f"Timeout fetching market prices for {crop}.")
            except Exception as e:
                logger.error(f"Error fetching market prices for {crop}: {e}")

    return get_mock_market_prices(crop, language)


async def _broaden_search(
    client: httpx.AsyncClient, params: dict, crop: str, limit: int | None = None
) -> list:
    """Broadens the market search by removing variety filter and trying commodity name variations."""
    if "filters[variety]" in params:
        del params["filters[variety]"]

    settings = get_settings()
    crop_variations = [crop, f"{crop}(Common)", f"{crop}(Fine)", crop.capitalize()]

    # If limit is set, slice the variations (Discovery Speed Optimization)
    if limit:
        crop_variations = crop_variations[:limit]
    for var_crop in crop_variations:
        logger.info(f"Broadening market search for: {var_crop}")
        params["filters[commodity]"] = var_crop
        try:
            response = await client.get(settings.market_api_url, params=params)
            if response.status_code == 429:
                logger.warning(
                    f"Rate limit hit during broadened search for {var_crop}."
                )
                return []  # Stop trying, fall back to mock
            records = response.json().get("records", [])
            if records:
                return records
        except httpx.RequestError as e:
            logger.warning(f"Failed broadened request for {var_crop}: {e}")
            pass  # Continue to next variation
    return []


def _format_live_response(latest: dict, variety: str | None, language: str) -> dict:
    """Formats a raw OGD record into the standard market price response."""
    market_name = latest.get("Market", latest.get("market", "Local APMC"))
    min_p = latest.get("Min_Price", latest.get("min_price", "N/A"))
    max_p = latest.get("Max_Price", latest.get("max_price", "N/A"))
    modal_p = latest.get("Modal_Price", latest.get("modal_price", "N/A"))
    variety_found = latest.get("Variety", latest.get("variety", variety or "Standard"))

    # Localized APMC label
    apmc_label = f"{market_name} APMC" if "APMC" not in market_name else market_name

    if language == "kn":
        return {
            "status": "ಲೈವ್",
            "message": f"{apmc_label} ಮಾರುಕಟ್ಟೆಯಲ್ಲಿ ಇಂದಿನ ಬೆಲೆಗಳು.",
            "market_name": apmc_label,
            "min_price": f"₹{min_p}",
            "max_price": f"₹{max_p}",
            "modal_price": f"₹{modal_p}",
            "variety": variety_found,
            "source": "Agmarknet (Live)",
        }

    return {
        "status": "Live",
        "message": f"Today's prices at {apmc_label} market.",
        "market_name": apmc_label,
        "min_price": f"₹{min_p}",
        "max_price": f"₹{max_p}",
        "modal_price": f"₹{modal_p}",
        "variety": variety_found,
        "source": "Agmarknet (Live)",
    }


def get_mock_market_prices(crop: str, language: str = "en") -> dict:
    """Returns graceful fallback data when live prices are unavailable."""
    if language == "kn":
        return {
            "status": "ಶೀಘ್ರದಲ್ಲೇ ಬರಲಿದೆ",
            "message": "ಮಾರುಕಟ್ಟೆ ಬೆಲೆಗಳ ಮಾಹಿತಿ ಶೀಘ್ರದಲ್ಲೇ ಲಭ್ಯವಿರುತ್ತದೆ.",
            "market_name": "ಮಾಹಿತಿ ಲಭ್ಯವಿಲ್ಲ",
            "min_price": "N/A",
            "max_price": "N/A",
            "modal_price": "N/A",
            "variety": "N/A",
            "source": "ಸ್ಥಗಿತಗೊಳಿಸಲಾಗಿದೆ",
        }
    return {
        "status": "Coming Soon",
        "message": "Market price intelligence will be available soon.",
        "market_name": "Data Unavailable",
        "min_price": "N/A",
        "max_price": "N/A",
        "modal_price": "N/A",
        "variety": "N/A",
        "source": "Maintenance",
    }
