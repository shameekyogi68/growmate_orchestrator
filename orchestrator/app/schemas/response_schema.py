from pydantic import BaseModel
from typing import Dict, Any, List, Optional


class MainStatus(BaseModel):
    risk_level: str
    message: str
    icon: str = "check_circle"
    color_code: str = "#10B981"
    status_label: Optional[str] = "Normal"


class AlertSchema(BaseModel):
    priority_level: str
    should_notify: bool
    source: str
    message: str
    icon: str = "warning"
    color_code: str = "#F59E0B"
    action_text: Optional[str] = None


class CropListResponse(BaseModel):
    status: str
    location: Optional[str] = None
    date: Optional[str] = None
    seasonal_groups: List[Dict[str, Any]] = []
    render_hints: Optional[Dict[str, Any]] = {
        "layout": "grid",
        "theme": "premium_glass",
        "animations": True,
    }


class AdvisoryResponse(BaseModel):
    status: str
    confidence_score: float = 1.0
    main_status: Dict[str, Any]
    rainfall: Dict[str, Any]
    soil: Dict[str, Any]
    pest: Dict[str, Any]
    crop_calendar: Dict[str, Any]
    market_prices: Dict[str, Any]
    weather: Dict[str, Any]
    udupi_intelligence: Dict[str, Any]
    recommendations: List[Dict[str, Any]]
    alerts: List[Dict[str, Any]]
    partial_data: bool
    service_health: Dict[str, str]
    last_updated: str
    ui_config: Optional[Dict[str, Any]] = {
        "header_blur": True,
        "primary_gradient": ["#3B82F6", "#1D4ED8"],
    }
