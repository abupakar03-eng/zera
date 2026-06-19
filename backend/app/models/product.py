from sqlalchemy import Column, BigInteger, String, Boolean, TIMESTAMP, ForeignKey, Text, DECIMAL, Integer, JSON
from sqlalchemy.sql import func
from app.database import Base
import uuid


class Product(Base):
    __tablename__ = "products"

    id = Column(BigInteger, primary_key=True, autoincrement=True, index=True)
    uuid = Column(String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4()))
    business_id = Column(BigInteger, ForeignKey('businesses.id', ondelete='CASCADE'), nullable=False, index=True)
    category_id = Column(BigInteger, ForeignKey('categories.id', ondelete='SET NULL'), nullable=True, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    sku = Column(String(100), nullable=True, index=True)
    price = Column(DECIMAL(10, 2), nullable=False)
    cost_price = Column(DECIMAL(10, 2), nullable=True)
    stock_quantity = Column(Integer, default=0)
    unit = Column(String(50), nullable=True)
    image_url = Column(String(500), nullable=True)
    image_urls = Column(JSON, nullable=True, default=list)
    sizes = Column(JSON, nullable=True)
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(TIMESTAMP, server_default=func.current_timestamp())
    updated_at = Column(TIMESTAMP, server_default=func.current_timestamp(), onupdate=func.current_timestamp())
    deleted_at = Column(TIMESTAMP, nullable=True)
