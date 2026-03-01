from pydantic import BaseModel
from typing import Optional


class AdvisoryRequest(BaseModel):
    user_id: str
    latitude: float
    longitude: float
    date: str
    crop: Optional[str] = None
    language: str = "en"
    intelligence_only: bool = False
    variety: Optional[str] = None
    sowing_date: Optional[str] = None
