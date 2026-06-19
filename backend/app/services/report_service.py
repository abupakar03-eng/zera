from typing import Optional
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, case
from datetime import datetime, date
from decimal import Decimal
from app.models.order import Order, OrderItem, PaymentStatus, OrderStatus
from app.models.product import Product
from app.models.customer import Customer
from app.models.category import Category
from app.models.business import Business
from app.schemas.report import (
    SalesReportResponse,
    SalesReportItem,
    ProductReportResponse,
    ProductReportItem,
    CustomerReportResponse,
    CustomerReportItem
)


class ReportService:
    def __init__(self, db: Session):
        self.db = db
    
    def _parse_date(self, date_str: Optional[str]) -> Optional[date]:
        if not date_str:
            return None
        try:
            return datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            return None
    
    def _format_date(self, dt) -> str:
        if isinstance(dt, datetime):
            return dt.strftime("%Y-%m-%d %H:%M:%S")
        elif isinstance(dt, date):
            return dt.strftime("%Y-%m-%d")
        return str(dt) if dt else ""
    
    def get_sales_report(
        self,
        business_id: int,
        from_date: Optional[str] = None,
        to_date: Optional[str] = None
    ) -> SalesReportResponse:
        business = self.db.query(Business).filter(Business.id == business_id).first()
        business_name = business.business_name if business else "Unknown"
        
        query = self.db.query(Order).filter(
            Order.business_id == business_id,
            Order.deleted_at.is_(None)
        )
        
        start_date = self._parse_date(from_date)
        end_date = self._parse_date(to_date)
        
        if start_date:
            query = query.filter(func.date(Order.order_date) >= start_date)
        if end_date:
            query = query.filter(func.date(Order.order_date) <= end_date)
        
        orders = query.order_by(Order.order_date.desc()).all()
        
        total_revenue = Decimal("0.00")
        total_profit = Decimal("0.00")
        total_tax = Decimal("0.00")
        total_discount = Decimal("0.00")
        sales_items = []

        for order in orders:
            customer = None
            if order.customer_id:
                customer = self.db.query(Customer).filter(Customer.id == order.customer_id).first()

            if order.payment_status == PaymentStatus.PAID:
                total_revenue += order.total_amount
                # Profit = (unit_price - cost_price) * qty for each item
                for item in order.items:
                    product = self.db.query(Product).filter(Product.id == item.product_id).first() if item.product_id else None
                    cost = Decimal(str(product.cost_price)) if product and product.cost_price else Decimal("0.00")
                    unit_price = Decimal(str(item.unit_price))
                    qty = Decimal(str(item.quantity))
                    total_profit += (unit_price - cost) * qty

            total_tax += order.tax_amount
            total_discount += order.discount_amount

            sales_items.append(SalesReportItem(
                order_number=order.order_number,
                customer_name=customer.name if customer else None,
                order_date=self._format_date(order.order_date),
                status=order.status.value,
                payment_status=order.payment_status.value,
                subtotal=order.subtotal,
                tax_amount=order.tax_amount,
                discount_amount=order.discount_amount,
                total_amount=order.total_amount
            ))

        return SalesReportResponse(
            business_name=business_name,
            from_date=from_date,
            to_date=to_date,
            total_orders=len(orders),
            total_revenue=total_revenue,
            total_profit=total_profit,
            total_tax=total_tax,
            total_discount=total_discount,
            orders=sales_items
        )
    
    def get_product_report(
        self,
        business_id: int,
        from_date: Optional[str] = None,
        to_date: Optional[str] = None
    ) -> ProductReportResponse:
        business = self.db.query(Business).filter(Business.id == business_id).first()
        business_name = business.business_name if business else "Unknown"

        start_date = self._parse_date(from_date)
        end_date = self._parse_date(to_date)

        # Build order-item sales stats for the date range
        sales_q = self.db.query(
            OrderItem.product_id,
            func.sum(OrderItem.quantity).label('total_quantity'),
            func.sum(OrderItem.total_price).label('total_revenue'),
            func.count(func.distinct(OrderItem.order_id)).label('orders_count')
        ).join(Order, OrderItem.order_id == Order.id).filter(
            Order.business_id == business_id,
            Order.deleted_at.is_(None)
        )
        if start_date:
            sales_q = sales_q.filter(func.date(Order.order_date) >= start_date)
        if end_date:
            sales_q = sales_q.filter(func.date(Order.order_date) <= end_date)
        sales_q = sales_q.group_by(OrderItem.product_id)
        sales_by_product = {r.product_id: r for r in sales_q.all()}

        # Fetch all active products for this business
        all_products = self.db.query(Product).filter(
            Product.business_id == business_id,
            Product.deleted_at.is_(None)
        ).order_by(Product.name).all()

        product_items = []
        total_revenue = Decimal("0.00")
        total_profit = Decimal("0.00")
        total_sold = 0

        for product in all_products:
            stats = sales_by_product.get(product.id)
            revenue = Decimal(str(stats.total_revenue)) if stats and stats.total_revenue else Decimal("0.00")
            qty = int(stats.total_quantity) if stats and stats.total_quantity else 0
            orders_count = int(stats.orders_count) if stats and stats.orders_count else 0
            total_revenue += revenue
            if qty > 0:
                total_sold += 1

            # Profit = (selling_price - cost_price) * qty_sold
            cost = Decimal(str(product.cost_price)) if product.cost_price else Decimal("0.00")
            selling = Decimal(str(product.price)) if product.price else Decimal("0.00")
            product_profit = (selling - cost) * qty
            total_profit += product_profit

            category_name = None
            if product.category_id:
                category = self.db.query(Category).filter(Category.id == product.category_id).first()
                if category:
                    category_name = category.name

            product_items.append(ProductReportItem(
                product_name=product.name,
                product_sku=product.sku,
                category_name=category_name,
                total_quantity_sold=qty,
                total_revenue=revenue,
                total_profit=product_profit,
                orders_count=orders_count
            ))

        # Sort: products with sales first (by revenue desc), then unsold alphabetically
        product_items.sort(key=lambda x: (-float(x.total_revenue), x.product_name))

        return ProductReportResponse(
            business_name=business_name,
            from_date=from_date,
            to_date=to_date,
            total_products_sold=total_sold,
            total_revenue=total_revenue,
            total_profit=total_profit,
            products=product_items
        )
    
    def get_customer_report(
        self,
        business_id: int,
        from_date: Optional[str] = None,
        to_date: Optional[str] = None
    ) -> CustomerReportResponse:
        business = self.db.query(Business).filter(Business.id == business_id).first()
        business_name = business.business_name if business else "Unknown"

        start_date = self._parse_date(from_date)
        end_date = self._parse_date(to_date)

        # Build order stats per customer for the date range
        stats_q = self.db.query(
            Order.customer_id,
            func.count(Order.id).label('total_orders'),
            func.sum(
                case((Order.payment_status == PaymentStatus.PAID, Order.total_amount), else_=0)
            ).label('total_spent'),
            func.max(Order.order_date).label('last_order_date')
        ).filter(
            Order.business_id == business_id,
            Order.deleted_at.is_(None),
            Order.customer_id.isnot(None)
        )
        if start_date:
            stats_q = stats_q.filter(func.date(Order.order_date) >= start_date)
        if end_date:
            stats_q = stats_q.filter(func.date(Order.order_date) <= end_date)
        stats_q = stats_q.group_by(Order.customer_id)
        stats_by_customer = {r.customer_id: r for r in stats_q.all()}

        # Fetch all active customers for this business
        all_customers = self.db.query(Customer).filter(
            Customer.business_id == business_id,
            Customer.deleted_at.is_(None)
        ).order_by(Customer.name).all()

        customer_items = []
        total_revenue = Decimal("0.00")
        total_profit = Decimal("0.00")

        for customer in all_customers:
            stats = stats_by_customer.get(customer.id)
            spent = Decimal(str(stats.total_spent)) if stats and stats.total_spent else Decimal("0.00")
            total_revenue += spent

            # Calculate profit for this customer's orders
            customer_orders = self.db.query(Order).filter(
                Order.business_id == business_id,
                Order.customer_id == customer.id,
                Order.payment_status == PaymentStatus.PAID,
                Order.deleted_at.is_(None)
            )
            if start_date:
                customer_orders = customer_orders.filter(func.date(Order.order_date) >= start_date)
            if end_date:
                customer_orders = customer_orders.filter(func.date(Order.order_date) <= end_date)

            for order in customer_orders.all():
                for item in order.items:
                    product = self.db.query(Product).filter(Product.id == item.product_id).first() if item.product_id else None
                    cost = Decimal(str(product.cost_price)) if product and product.cost_price else Decimal("0.00")
                    unit_price = Decimal(str(item.unit_price))
                    qty = Decimal(str(item.quantity))
                    total_profit += (unit_price - cost) * qty

            customer_items.append(CustomerReportItem(
                customer_name=customer.name,
                customer_phone=customer.phone,
                customer_email=customer.email,
                total_orders=int(stats.total_orders) if stats and stats.total_orders else 0,
                total_spent=spent,
                last_order_date=self._format_date(stats.last_order_date) if stats and stats.last_order_date else None
            ))

        # Sort: customers with most spending first, then by name
        customer_items.sort(key=lambda x: (-float(x.total_spent), x.customer_name))

        return CustomerReportResponse(
            business_name=business_name,
            from_date=from_date,
            to_date=to_date,
            total_customers=len(customer_items),
            total_revenue=total_revenue,
            total_profit=total_profit,
            customers=customer_items
        )
