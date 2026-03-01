from typing import List
from pydantic import BaseModel


class CropMeta(BaseModel):
    id: str
    name: str  # Dynamically localized from source API
    icon: str = "agriculture"
    varieties: List[str] = ["Standard"]
    description: str = "Dynamically localized description"
    duration_weeks: int = 12
    expected_yield: str = "N/A"
    difficulty: str = "Medium"
    market_value: str = "Medium"
    water_requirement: str = "Medium"
    investment_cost: str = "Medium"
    labor_intensity: str = "Medium"
    primary_use: str = "Food"
    risk_level: str = "Low"
    market_price: str = "N/A"
    price_status: str = "Live"  # Live, Coming Soon
    fusion_status: str = "Verified"  # Verified, Warning, Critical


class SeasonalGroup(BaseModel):
    category: str
    crops: List[CropMeta]


class CropListResponse(BaseModel):
    status: str
    location: str  # e.g., "Byndoor, Udupi"
    date: str
    seasonal_groups: List[SeasonalGroup]
