from sqlalchemy import Column, BigInteger, String, TIMESTAMP, ForeignKey, Text, DECIMAL, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
import enum
import uuid


class OrderStatus(str, enum.Enum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    PROCESSING = "PROCESSING"
    SHIPPED = "SHIPPED"
    DELIVERED = "DELIVERED"
    CANCELLED = "CANCELLED"


class PaymentStatus(str, enum.Enum):
    PENDING = "PENDING"
    PAID = "PAID"
    FAILED = "FAILED"
    REFUNDED = "REFUNDED"


class Order(Base):
    __tablename__ = "orders"

    id = Column(BigInteger, primary_key=True, autoincrement=True, index=True)
    uuid = Column(String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4()), index=True)
    order_number = Column(String(50), unique=True, nullable=False)
    business_id = Column(BigInteger, ForeignKey('businesses.id', ondelete='CASCADE'), nullable=False, index=True)
    customer_id = Column(BigInteger, ForeignKey('customers.id', ondelete='SET NULL'), nullable=True, index=True)
    order_date = Column(TIMESTAMP, server_default=func.current_timestamp(), index=True)
    status = Column(Enum(OrderStatus), default=OrderStatus.PENDING, index=True)
    subtotal = Column(DECIMAL(10, 2), nullable=False)
    tax_amount = Column(DECIMAL(10, 2), default=0.00)
    discount_amount = Column(DECIMAL(10, 2), default=0.00)
    total_amount = Column(DECIMAL(10, 2), nullable=False)
    payment_method = Column(String(50), nullable=True)
    payment_status = Column(Enum(PaymentStatus), default=PaymentStatus.PENDING)
    notes = Column(Text, nullable=True)
    payment_proof_url = Column(String(500), nullable=True)
    created_at = Column(TIMESTAMP, server_default=func.current_timestamp())
    updated_at = Column(TIMESTAMP, server_default=func.current_timestamp(), onupdate=func.current_timestamp())
    deleted_at = Column(TIMESTAMP, nullable=True)

    items = relationship("OrderItem", backref="order", lazy="select")


class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(BigInteger, primary_key=True, autoincrement=True, index=True)
    order_id = Column(BigInteger, ForeignKey('orders.id', ondelete='CASCADE'), nullable=False, index=True)
    product_id = Column(BigInteger, ForeignKey('products.id', ondelete='SET NULL'), nullable=True, index=True)
    product_name = Column(String(255), nullable=False)
    product_sku = Column(String(100), nullable=True)
    quantity = Column(BigInteger, nullable=False)
    unit_price = Column(DECIMAL(10, 2), nullable=False)
    total_price = Column(DECIMAL(10, 2), nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.current_timestamp())
