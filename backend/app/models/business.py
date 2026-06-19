from sqlalchemy import Column, BigInteger, String, Boolean, TIMESTAMP, Enum, Date, ForeignKey, Text, JSON
from sqlalchemy.sql import func
from app.database import Base
import enum
import uuid


class BusinessPlan(str, enum.Enum):
    FREE = "FREE"
    PAID = "PAID"


class Business(Base):
    __tablename__ = "businesses"

    id = Column(BigInteger, primary_key=True, autoincrement=True, index=True)
    uuid = Column(String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4()), index=True)
    store_slug = Column(String(100), unique=True, nullable=True, index=True)
    owner_id = Column(BigInteger, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    business_name = Column(String(255), nullable=False)
    business_type = Column(String(100), nullable=True)
    phone = Column(String(15), nullable=False)
    email = Column(String(255), nullable=True)
    address = Column(Text, nullable=True)
    city = Column(String(100), nullable=True)
    state = Column(String(100), nullable=True)
    pincode = Column(String(10), nullable=True)
    gstin = Column(String(15), nullable=True)
    upi_id = Column(String(100), nullable=True)
    logo_url = Column(String(500), nullable=True)
    banner_url = Column(String(500), nullable=True)
    profile_image_urls = Column(JSON, nullable=True, default=list)
    plan = Column(Enum(BusinessPlan), default=BusinessPlan.FREE, index=True)
    plan_expiry_date = Column(Date, nullable=True)
    subscription_type = Column(String(10), nullable=True)  # "monthly" | "yearly"
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(TIMESTAMP, server_default=func.current_timestamp())
    updated_at = Column(TIMESTAMP, server_default=func.current_timestamp(), onupdate=func.current_timestamp())
    deleted_at = Column(TIMESTAMP, nullable=True)
