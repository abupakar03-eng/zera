from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Optional, List
from datetime import datetime, timezone
from decimal import Decimal


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class ProductCreateRequest(BaseModel):
    category_id: Optional[int] = None
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    sku: Optional[str] = Field(None, max_length=100)
    price: Decimal = Field(..., gt=0)
    cost_price: Optional[Decimal] = Field(None, ge=0)
    stock_quantity: int = Field(default=0, ge=0)
    unit: Optional[str] = Field(None, max_length=50)
    image_url: Optional[str] = None
    image_urls: List[str] = []
    sizes: Optional[List[str]] = None
    is_active: bool = True


class ProductUpdateRequest(BaseModel):
    category_id: Optional[int] = None
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    sku: Optional[str] = Field(None, max_length=100)
    price: Optional[Decimal] = Field(None, gt=0)
    cost_price: Optional[Decimal] = Field(None, ge=0)
    stock_quantity: Optional[int] = Field(None, ge=0)
    unit: Optional[str] = Field(None, max_length=50)
    image_url: Optional[str] = None
    image_urls: Optional[List[str]] = None
    sizes: Optional[List[str]] = None
    is_active: Optional[bool] = None


class ProductResponse(BaseModel):
    uuid: str
    business_id: int
    category_id: Optional[int]
    name: str
    description: Optional[str]
    sku: Optional[str]
    price: Decimal
    cost_price: Optional[Decimal]
    stock_quantity: int
    unit: Optional[str]
    image_url: Optional[str]
    image_urls: List[str] = []
    sizes: Optional[List[str]] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @model_validator(mode='after')
    def sync_image_url_from_list(self) -> 'ProductResponse':
        """Ensure image_url is always set if image_urls has items."""
        if not self.image_url and self.image_urls:
            self.image_url = self.image_urls[0]
        return self


class ProductListResponse(BaseModel):
    success: bool = True
    message: str
    data: List[ProductResponse]
    total: int
    page: int
    page_size: int
    timestamp: datetime = Field(default_factory=_utc_now)


class ProductSingleResponse(BaseModel):
    success: bool = True
    message: str
    data: ProductResponse
    timestamp: datetime = Field(default_factory=_utc_now)


class ProductDeleteResponse(BaseModel):
    success: bool = True
    message: str
    timestamp: datetime = Field(default_factory=_utc_now)


class ProductImageUploadResponse(BaseModel):
    success: bool = True
    message: str
    image_url: str
    timestamp: datetime = Field(default_factory=_utc_now)


class ProductToggleResponse(BaseModel):
    success: bool = True
    message: str
    is_active: bool
    timestamp: datetime = Field(default_factory=_utc_now)
