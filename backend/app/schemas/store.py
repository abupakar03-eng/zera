from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import datetime, timezone
import re


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


# ── Public store info ────────────────────────────────────────────────────────

class StoreInfoResponse(BaseModel):
    uuid: str
    business_name: str
    phone: str
    logo_url: Optional[str] = None
    profile_image_urls: Optional[List[str]] = None
    banner_url: Optional[str] = None
    upi_id: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    average_rating: float = 0.0
    review_count: int = 0

    class Config:
        from_attributes = True


# ── Public category ──────────────────────────────────────────────────────────

class StoreCategoryResponse(BaseModel):
    uuid: str
    name: str

    class Config:
        from_attributes = True


# ── Public product ───────────────────────────────────────────────────────────

class StoreProductResponse(BaseModel):
    uuid: str
    name: str
    description: Optional[str] = None
    price: float
    unit: Optional[str] = None
    image_url: Optional[str] = None
    image_urls: List[str] = []
    sizes: Optional[List[str]] = None
    stock_quantity: int
    category_name: Optional[str] = None
    is_available: bool

    class Config:
        from_attributes = True


# ── Place order (guest) ───────────────────────────────────────────────────────

class StoreOrderItem(BaseModel):
    product_uuid: str
    quantity: int = Field(ge=1)
    selected_size: Optional[str] = None


class StoreOrderCreate(BaseModel):
    customer_name: str = Field(min_length=2, max_length=255)
    customer_phone: str = Field(min_length=10, max_length=15)
    items: List[StoreOrderItem] = Field(min_length=1)
    payment_method: str = Field(default="COD")  # "UPI" or "COD"
    notes: Optional[str] = None

    @field_validator('customer_phone')
    @classmethod
    def validate_phone(cls, v: str) -> str:
        digits = re.sub(r'\D', '', v)
        if len(digits) < 10:
            raise ValueError('Phone number must be at least 10 digits')
        return digits[-10:]  # keep last 10 digits

    @field_validator('payment_method')
    @classmethod
    def validate_payment(cls, v: str) -> str:
        allowed = {'UPI', 'COD'}
        v = v.upper()
        if v not in allowed:
            raise ValueError(f"payment_method must be one of {allowed}")
        return v


# ── Order item in response ────────────────────────────────────────────────────

class StoreOrderItemResponse(BaseModel):
    product_name: str
    product_sku: Optional[str] = None
    quantity: int
    unit_price: float
    total_price: float

    class Config:
        from_attributes = True


# ── Order response (after placing) ───────────────────────────────────────────

class StoreOrderResponse(BaseModel):
    success: bool = True
    message: str = "Order placed successfully"
    order_number: str
    status: str
    payment_status: str
    payment_method: str
    subtotal: float
    total_amount: float
    items: List[StoreOrderItemResponse]
    payment_proof_url: Optional[str] = None
    created_at: datetime
    timestamp: datetime = Field(default_factory=_utc_now)


# ── Order status check ────────────────────────────────────────────────────────

class StoreOrderStatusResponse(BaseModel):
    order_number: str
    status: str
    payment_status: str
    payment_method: str
    subtotal: float
    total_amount: float
    items: List[StoreOrderItemResponse]
    payment_proof_url: Optional[str] = None
    created_at: datetime
    notes: Optional[str] = None

# -- Reviews ------------------------------------------------------------------

class StoreReviewCreate(BaseModel):
    customer_name: str = Field(min_length=2, max_length=255)
    rating: int = Field(ge=1, le=5)
    comment: Optional[str] = None
    order_number: Optional[str] = None
