from pydantic import BaseModel
from typing import List, Dict, Optional


class MainStatus(BaseModel):
    title: str
    message: str
    icon: str
    priority: str
    color: str


class RainfallNext7Days(BaseModel):
    amount_mm: float
    max_intensity: float
    category: str


class MonthlyPrediction(BaseModel):
    category: str
    confidence_percent: int


class RainfallDetail(BaseModel):
    next_7_days: RainfallNext7Days
    monthly_prediction: MonthlyPrediction


class Actions(BaseModel):
    immediate: List[str]
    this_week: Optional[List[str]] = []


class WhatToDo(BaseModel):
    title: str
    advisory_summary: str
    actions: Actions
    priority_level: str


class ConfidenceScores(BaseModel):
    Deficit: float
    Normal: float
    Excess: float


class TechnicalDetails(BaseModel):
    ml_prediction: str
    confidence_scores: ConfidenceScores


class WaterInsights(BaseModel):
    soil_moisture: str
    water_source: str


class LocationDetail(BaseModel):
    taluk: str
    district: str
    confidence: str


class MonthlyForecast(BaseModel):
    current_month_predicted: str
    current_month_estimated_mm: str
    rainfall_classification: str


class RainfallIntelligence(BaseModel):
    monthly_forecast: MonthlyForecast


class AdvisoryResponse(BaseModel):
    status: str
    main_status: MainStatus
    rainfall: RainfallDetail
    what_to_do: WhatToDo
    technical_details: Optional[TechnicalDetails] = None
    water_insights: Optional[WaterInsights] = None
    location: Optional[LocationDetail] = None
    rainfall_intelligence: Optional[RainfallIntelligence] = None


class PredictionDetail(BaseModel):
    category: str
    confidence: int
    risk_level: str
    risk_icon: str
    risk_description: str


class ForecastDay(BaseModel):
    date: str
    rain_mm: float
    temp_max: float
    temp_min: float


class TimeAction(BaseModel):
    time: str
    action: str
    why: str
    priority: str


class DailySchedule(BaseModel):
    day: str
    actions: List[TimeAction]


class CropAdviceDetail(BaseModel):
    name: str
    water_need: str
    actions: List[str]


class SoilMoistureDetail(BaseModel):
    status: str
    index: float


class EnhancedAdvisoryDetail(BaseModel):
    prediction: PredictionDetail
    forecast_7day: List[ForecastDay]
    daily_schedule: List[DailySchedule]
    crop_advice: Dict[str, CropAdviceDetail]
    soil_moisture: SoilMoistureDetail


class EnhancedAdvisoryResponse(BaseModel):
    status: str
    enhanced_advisory: EnhancedAdvisoryDetail


class ErrorDetail(BaseModel):
    type: str
    title: Dict[str, str]
    message: Dict[str, str]
    icon: str
    what_to_do: Dict[str, str]


class ErrorResponse(BaseModel):
    status: str
    error: ErrorDetail
