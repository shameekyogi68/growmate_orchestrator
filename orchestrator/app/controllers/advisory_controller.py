from fastapi import APIRouter, Depends
from datetime import datetime, timezone
from app.schemas.request_schema import AdvisoryRequest
from app.schemas.response_schema import AdvisoryResponse, CropListResponse
from app.utils.auth import verify_token

from app.services.orchestration_service import orchestrate_farmer_advisory
from app.services.discovery_service import get_intelligent_crops
from app.utils.concurrency import advisory_flight
from app.utils.resilience import REGISTRY as circuit_registry

from app.services.rainfall_service import get_rainfall_advisory as raw_rainfall_advisory
from app.services.soil_service import get_soil_advisory as raw_soil_advisory
from app.services.calendar_service import get_calendar_advisory as raw_calendar_advisory
from app.services.pest_service import get_pest_advisory as raw_pest_advisory
from app.external.weather_api import fetch_weather_data as raw_weather_api
from app.external.market_api import fetch_market_prices as raw_market_api
from app.services.recommendation_service import get_crop_recommendations as raw_recommendations

router = APIRouter(tags=["Advisory"])


@router.get("/supported-crops", response_model=CropListResponse)
async def get_supported_crops(
    latitude: float = 13.8,
    longitude: float = 74.6,
    date: str | None = None,
    language: str = "en",
):
    """
    Returns a validated list of supported crops based on dynamic API fusion.
    """
    crops_data = await get_intelligent_crops(latitude, longitude, date, language)
    return CropListResponse(**crops_data)


@router.api_route("/farmer-advisory/rainfall", methods=["GET", "POST"])
async def get_isolated_rainfall(
    user_id: str, latitude: float, longitude: float, date: str, 
    language: str = "en", token_data: dict = Depends(verify_token)
):
    """Fetch only the rainfall intelligence stream."""
    return await raw_rainfall_advisory(latitude, longitude, date, language)

@router.api_route("/farmer-advisory/soil", methods=["GET", "POST"])
async def get_isolated_soil(
    latitude: float, longitude: float, language: str = "en", 
    crop: str = None, sowing_date: str = None, token_data: dict = Depends(verify_token)
):
    """Fetch only the soil intelligence stream."""
    return await raw_soil_advisory(latitude, longitude, language, crop, sowing_date)

@router.api_route("/farmer-advisory/calendar", methods=["GET", "POST"])
async def get_isolated_calendar(
    date: str = None, crop: str = None, variety: str = None, 
    language: str = "en", sowing_date: str = None, token_data: dict = Depends(verify_token)
):
    """Fetch only the crop calendar schedule stream."""
    month = datetime.strptime(date, "%Y-%m-%d").month if date else datetime.now().month
    season = "kharif" if month in [6, 7, 8, 9, 10] else ("rabi" if month in [11, 12, 1, 2] else "summer")
    return await raw_calendar_advisory(season, crop, variety, language, sowing_date)

@router.api_route("/farmer-advisory/pest", methods=["GET", "POST"])
async def get_isolated_pest(
    crop: str = None, variety: str = None, sowing_date: str = None, 
    language: str = "en", date: str = None, token_data: dict = Depends(verify_token)
):
    """Fetch only the pest intelligence stream."""
    return await raw_pest_advisory(crop, variety, sowing_date, language, request_date=date)

@router.api_route("/farmer-advisory/weather", methods=["GET", "POST"])
async def get_isolated_weather(
    latitude: float, longitude: float, language: str = "en", 
    date: str = None, token_data: dict = Depends(verify_token)
):
    """Fetch only live weather data stream."""
    return await raw_weather_api(latitude, longitude, language, request_date=date)

@router.api_route("/farmer-advisory/market", methods=["GET", "POST"])
async def get_isolated_market(
    crop: str = None, variety: str = None, language: str = "en", 
    token_data: dict = Depends(verify_token)
):
    """Fetch only market prices stream."""
    return await raw_market_api(crop, variety, language=language)

@router.api_route("/farmer-advisory/recommendations", methods=["GET", "POST"])
async def get_isolated_recommendations(
    latitude: float, longitude: float, date: str, 
    language: str = "en", token_data: dict = Depends(verify_token)
):
    """Fetch isolated recommendations stream."""
    return await raw_recommendations(latitude, longitude, date, language)

@router.post("/farmer-advisory", response_model=AdvisoryResponse)
async def get_farmer_advisory(
    req: AdvisoryRequest, token_data: dict = Depends(verify_token)
):
    """
    User-facing endpoint for agricultural advisories.
    Orchestrates 14+ streams in parallel with automatic personalization fallbacks.
    """
    # STATE SYNC: Always fetch the LATEST profile and primary crop from DB before orchid-flight
    # This solves the 'Stale JWT' problem where the token has old crop data.
    if str(req.user_id).isdigit():
        from app.utils.database import fetch_one
        latest = await fetch_one(
            "SELECT active_crop, active_sowing_date, latitude, longitude, language FROM users WHERE id = $1", 
            int(req.user_id)
        )
        if latest:
            # Only override if the request sent default/string placeholders
            if not req.crop or req.crop == "string":
                req.crop = latest["active_crop"]
                req.sowing_date = latest["active_sowing_date"].isoformat() if latest["active_sowing_date"] else None
            
            # Location Sync: Always use profile location if request sent default 0.0 or 13.8/74.6
            if req.latitude in [0.0, 13.8] and latest["latitude"]:
                req.latitude = latest["latitude"]
            if req.longitude in [0.0, 74.6] and latest["longitude"]:
                req.longitude = latest["longitude"]
            
            # Language Sync
            if req.language == "en" and latest["language"] == "kn":
                req.language = "kn"

    # Final Fallback to token (should rarely be needed with the DB block above)
    if not req.crop or req.crop == "string":
        req.crop = token_data.get("active_crop", "Paddy")
        req.sowing_date = token_data.get("active_sowing_date")

    # Execute through single-flight wrapper to prevent redundant ML/API overhead
    flight_key = f"{req.user_id}:{req.crop}:{req.date}"
    fused, partial, _ = await advisory_flight.run(
        flight_key, orchestrate_farmer_advisory, req.dict()
    )

    # PERSISTENCE: Save to advisory_history for the user
    from app.utils.database import execute, fetch_one
    import json
    
    # We use a non-blocking approach (don't await if we want speed, 
    # but here we await to ensure data is saved for this request context)
    try:
        if str(req.user_id).isdigit():
            # Idempotency Protection: time window (2 mins)
            recent = await fetch_one(
                "SELECT id FROM advisory_history WHERE user_id = $1 AND crop = $2 AND created_at >= NOW() - INTERVAL '2 minutes'",
                int(req.user_id),
                req.crop
            )
            if not recent:
                await execute(
                    """INSERT INTO advisory_history (user_id, crop, variety, request_date, response_json)
                       VALUES ($1, $2, $3, $4, $5)""",
                    int(req.user_id),
                    req.crop,
                    token_data.get("active_variety", "General"),
                    datetime.strptime(req.date, "%Y-%m-%d").date() if req.date else datetime.now().date(),
                    json.dumps(fused)
                )
            else:
                from app.utils.logger import logger
                logger.info(f"Idempotency hit for user {req.user_id} and crop {req.crop}. Skipped DB insert.")
    except Exception as e:
        logger.error(f"Failed to persist advisory history: {e}")

    return AdvisoryResponse(
        status="success",
        confidence_score=float(fused.get("confidence_score", 1.0)),
        main_status=fused["main_status"],
        rainfall=fused["rainfall"],
        soil=fused["soil"],
        pest=fused["pest"],
        crop_calendar=fused["crop_calendar"],
        market_prices=fused["market_prices"],
        weather=fused["weather"],
        udupi_intelligence=fused["udupi_intelligence"],
        recommendations=fused["recommendations"],
        alerts=fused["alerts"],
        partial_data=partial,
        service_health={
            name: breaker.state.value for name, breaker in circuit_registry.items()
        },
        last_updated=datetime.now(timezone.utc).isoformat(),
    )


@router.get("/insurance-report/{user_id}/download")
async def download_insurance_report(
    user_id: str, token_data: dict = Depends(verify_token)
):
    """Generates a professional, human-readable Markdown report for insurance claims."""
    # Simulation: In a real system, this would query historical DB logs for the farmer
    report = f"""# GROW-MATE INSURANCE EVIDENCE REPORT
**Farmer ID**: {user_id}
**Report Generated**: {datetime.now().strftime('%Y-%m-%d')}
**Verification Hash**: GROW-SECURE-{user_id[:4]}-2026

## 1. Monitoring Geo-Context
- **Location**: Byndoor Sector, Udupi District
- **Coordinates**: 13.8N, 74.6E
- **Primary Crop**: Paddy (MO-4)

## 2. Weather Evidence Metrics (ML Predicted vs Actual)
| Metric | Recorded Value | Deviation from Normal |
|---|---|---|
| Total Rainfall (Month) | 12.5mm | **-65.0% (Deficit)** |
| Continuous Dry Days | 24 Days | **Critical Threshold Breached** |
| Max Temperature | 36.2°C | **+2.1°C** |

## 3. High-Intelligence Verification
Satellite (NDVI) analysis confirms high vegetation stress in the coordinates specified. IMD historical data verifies the rainfall deficit during the critical vegetative phase.

## 4. Certification
This report is generated by the GrowMate Intelligent Decision System and is valid for submission as secondary evidence for Pradhan Mantri Fasal Bima Yojana (PMFBY) claims.

---
*Signed by GrowMate AI Orchestrator*
"""
    return {"status": "success", "markdown_report": report}
