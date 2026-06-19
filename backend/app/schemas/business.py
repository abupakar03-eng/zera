from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import datetime, date, timezone
import re


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class BusinessProfileResponse(BaseModel):
    uuid: str
    store_slug: Optional[str] = None
    business_name: str
    business_type: Optional[str]
    phone: str
    email: Optional[str]
    address: Optional[str]
    city: Optional[str]
    state: Optional[str]
    pincode: Optional[str]
    gstin: Optional[str]
    upi_id: Optional[str] = None
    logo_url: Optional[str]
    banner_url: Optional[str]
    profile_image_urls: Optional[List[str]] = []
    plan: str
    plan_expiry_date: Optional[date]
    is_active: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class BusinessUpdateRequest(BaseModel):
    business_name: Optional[str] = Field(None, min_length=2, max_length=255)
    business_type: Optional[str] = Field(None, max_length=100)
    phone: Optional[str] = Field(None, min_length=10, max_length=15)
    email: Optional[str] = Field(None, max_length=255)
    address: Optional[str] = None
    city: Optional[str] = Field(None, max_length=100)
    state: Optional[str] = Field(None, max_length=100)
    pincode: Optional[str] = Field(None, max_length=10)
    gstin: Optional[str] = Field(None, max_length=15)
    upi_id: Optional[str] = Field(None, max_length=100)
    profile_image_urls: Optional[List[str]] = None
    
    @field_validator('phone')
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        phone = re.sub(r'\D', '', v)
        if len(phone) < 10:
            raise ValueError('Phone number must be at least 10 digits')
        if not phone.startswith(('6', '7', '8', '9')):
            raise ValueError('Invalid Indian phone number')
        return phone
    
    @field_validator('email')
    @classmethod
    def validate_email(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == "":
            return None
        email_regex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(email_regex, v):
            raise ValueError('Invalid email format')
        return v.lower()
    
    @field_validator('gstin')
    @classmethod
    def validate_gstin(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == "":
            return None
        gstin = v.upper().strip()
        gstin_regex = r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$'
        if not re.match(gstin_regex, gstin):
            raise ValueError('Invalid GSTIN format')
        return gstin
    
    @field_validator('pincode')
    @classmethod
    def validate_pincode(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == "":
            return None
        pincode = re.sub(r'\D', '', v)
        if len(pincode) != 6:
            raise ValueError('Pincode must be 6 digits')
        return pincode


class BusinessStatsResponse(BaseModel):
    total_products: int
    active_products: int
    total_orders: int
    total_customers: int
    total_revenue: float
    plan: str
    plan_limits: dict


class LogoUploadResponse(BaseModel):
    success: bool = True
    message: str
    logo_url: str
    timestamp: datetime = Field(default_factory=_utc_now)


class BusinessResponse(BaseModel):
    success: bool = True
    message: str
    data: BusinessProfileResponse
    timestamp: datetime = Field(default_factory=_utc_now)
