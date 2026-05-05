from typing import List, Dict, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, extract
from fastapi import HTTPException, status
from datetime import datetime, date, timezone, timedelta
from dateutil.relativedelta import relativedelta

from app.models.user import User, UserRole
from app.models.business import Business, BusinessPlan
from app.models.product import Product
from app.models.order import Order
from app.models.customer import Customer
from app.models.plan_limit import PlanLimit
from app.schemas.admin import (
    AdminBusinessListItem,
    AdminBusinessDetail,
    AdminUserListItem,
    PlatformStats,
    UpdateBusinessStatusRequest,
    UpdateBusinessPlanRequest,
    UpdateUserStatusRequest
)
from app.services.plan_limit_service import PlanLimitService


class AdminService:
    def __init__(self, db: Session):
        self.db = db
    
    def get_all_businesses(
        self,
        page: int = 1,
        page_size: int = 20,
        search: str = None,
        plan: str = None,
        is_active: bool = None
    ) -> Tuple[List[AdminBusinessListItem], Dict]:
        query = self.db.query(
            Business,
            User.full_name.label('owner_name')
        ).join(
            User, Business.owner_id == User.id
        ).filter(
            Business.deleted_at.is_(None)
        )
        
        if search:
            search_filter = f"%{search}%"
            query = query.filter(
                (Business.business_name.like(search_filter)) |
                (Business.phone.like(search_filter)) |
                (User.full_name.like(search_filter))
            )
        
        if plan:
            query = query.filter(Business.plan == plan)
        
        if is_active is not None:
            query = query.filter(Business.is_active == is_active)
        
        query = query.order_by(Business.created_at.desc())
        
        total_items = query.count()
        total_pages = (total_items + page_size - 1) // page_size
        
        offset = (page - 1) * page_size
        results = query.offset(offset).limit(page_size).all()
        
        business_list = []
        for business, owner_name in results:
            total_products = self.db.query(func.count(Product.id)).filter(
                Product.business_id == business.id,
                Product.deleted_at.is_(None)
            ).scalar() or 0
            
            total_orders = self.db.query(func.count(Order.id)).filter(
                Order.business_id == business.id,
                Order.deleted_at.is_(None)
            ).scalar() or 0
            
            total_revenue = self.db.query(func.sum(Order.total_amount)).filter(
                Order.business_id == business.id,
                Order.payment_status == "PAID",
                Order.deleted_at.is_(None)
            ).scalar() or 0.0
            
            business_list.append(AdminBusinessListItem(
                uuid=business.uuid,
                business_name=business.business_name,
                owner_name=owner_name,
                phone=business.phone,
                email=business.email,
                plan=business.plan.value,
                plan_expiry_date=business.plan_expiry_date,
                subscription_type=business.subscription_type,
                logo_url=business.logo_url,
                is_active=business.is_active,
                created_at=business.created_at,
                total_products=total_products,
                total_orders=total_orders,
                total_revenue=float(total_revenue)
            ))
        
        pagination = {
            "page": page,
            "page_size": page_size,
            "total_items": total_items,
            "total_pages": total_pages
        }
        
        return business_list, pagination
    
    def get_business_detail(self, business_uuid: str) -> AdminBusinessDetail:
        result = self.db.query(
            Business,
            User.uuid.label('owner_uuid'),
            User.full_name.label('owner_name'),
            User.phone.label('owner_phone'),
            User.email.label('owner_email')
        ).join(
            User, Business.owner_id == User.id
        ).filter(
            Business.uuid == business_uuid,
            Business.deleted_at.is_(None)
        ).first()
        
        if not result:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Business not found"
            )
        
        business = result[0]
        owner_uuid = result[1]
        owner_name = result[2]
        owner_phone = result[3]
        owner_email = result[4]
        
        total_products = self.db.query(func.count(Product.id)).filter(
            Product.business_id == business.id,
            Product.deleted_at.is_(None)
        ).scalar() or 0
        
        total_orders = self.db.query(func.count(Order.id)).filter(
            Order.business_id == business.id,
            Order.deleted_at.is_(None)
        ).scalar() or 0
        
        total_customers = self.db.query(func.count(Customer.id)).filter(
            Customer.business_id == business.id,
            Customer.deleted_at.is_(None)
        ).scalar() or 0
        
        total_revenue = self.db.query(func.sum(Order.total_amount)).filter(
            Order.business_id == business.id,
            Order.payment_status == "PAID",
            Order.deleted_at.is_(None)
        ).scalar() or 0.0
        
        return AdminBusinessDetail(
            uuid=business.uuid,
            business_name=business.business_name,
            business_type=business.business_type,
            phone=business.phone,
            email=business.email,
            address=business.address,
            city=business.city,
            state=business.state,
            pincode=business.pincode,
            gstin=business.gstin,
            logo_url=business.logo_url,
            plan=business.plan.value,
            plan_expiry_date=business.plan_expiry_date,
            is_active=business.is_active,
            created_at=business.created_at,
            updated_at=business.updated_at,
            owner_uuid=owner_uuid,
            owner_name=owner_name,
            owner_phone=owner_phone,
            owner_email=owner_email,
            total_products=total_products,
            total_orders=total_orders,
            total_customers=total_customers,
            total_revenue=float(total_revenue)
        )
    
    def update_business_status(self, business_uuid: str, data: UpdateBusinessStatusRequest) -> None:
        business = self.db.query(Business).filter(
            Business.uuid == business_uuid,
            Business.deleted_at.is_(None)
        ).first()
        
        if not business:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Business not found"
            )
        
        business.is_active = data.is_active
        self.db.commit()
    
    def update_business_plan(self, business_uuid: str, data: UpdateBusinessPlanRequest) -> None:
        business = self.db.query(Business).filter(
            Business.uuid == business_uuid,
            Business.deleted_at.is_(None)
        ).first()
        
        if not business:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Business not found"
            )
        
        old_plan = business.plan
        business.plan = BusinessPlan(data.plan.value)
        business.plan_expiry_date = data.plan_expiry_date

        if data.subscription_type is not None:
            business.subscription_type = data.subscription_type if data.plan.value == "PAID" else None
        elif data.plan.value == "FREE":
            business.subscription_type = None

        if old_plan != business.plan:
            PlanLimitService.update_plan_limits(self.db, business.id, business.plan)

        self.db.commit()
    
    def get_all_users(
        self,
        page: int = 1,
        page_size: int = 20,
        search: str = None,
        role: str = None,
        is_active: bool = None
    ) -> Tuple[List[AdminUserListItem], Dict]:
        query = self.db.query(User).filter(
            User.deleted_at.is_(None)
        )
        
        if search:
            search_filter = f"%{search}%"
            query = query.filter(
                (User.full_name.like(search_filter)) |
                (User.phone.like(search_filter)) |
                (User.email.like(search_filter))
            )
        
        if role:
            query = query.filter(User.role == role)
        
        if is_active is not None:
            query = query.filter(User.is_active == is_active)
        
        query = query.order_by(User.created_at.desc())
        
        total_items = query.count()
        total_pages = (total_items + page_size - 1) // page_size
        
        offset = (page - 1) * page_size
        users = query.offset(offset).limit(page_size).all()
        
        user_list = []
        for user in users:
            business_count = self.db.query(func.count(Business.id)).filter(
                Business.owner_id == user.id,
                Business.deleted_at.is_(None)
            ).scalar() or 0
            
            user_list.append(AdminUserListItem(
                uuid=user.uuid,
                full_name=user.full_name,
                phone=user.phone,
                email=user.email,
                role=user.role.value,
                is_active=user.is_active,
                is_verified=user.is_verified,
                last_login=user.last_login,
                created_at=user.created_at,
                business_count=business_count
            ))
        
        pagination = {
            "page": page,
            "page_size": page_size,
            "total_items": total_items,
            "total_pages": total_pages
        }
        
        return user_list, pagination
    
    def hard_delete_business(self, business_uuid: str) -> dict:
        """Permanently delete a business and its owner user (if no other businesses)."""
        business = self.db.query(Business).filter(
            Business.uuid == business_uuid
        ).first()

        if not business:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Business not found"
            )

        owner_id = business.owner_id
        business_name = business.business_name

        # Hard-delete the business — DB CASCADE handles products, orders,
        # customers, categories, affiliates, referrals, plan_limits, etc.
        self.db.delete(business)
        self.db.flush()

        # Delete the owner user only if they have no remaining businesses
        remaining = self.db.query(func.count(Business.id)).filter(
            Business.owner_id == owner_id
        ).scalar() or 0

        user_deleted = False
        if remaining == 0:
            user = self.db.query(User).filter(User.id == owner_id).first()
            if user and user.role != UserRole.SUPER_ADMIN:
                self.db.delete(user)
                user_deleted = True

        self.db.commit()
        return {"business_name": business_name, "user_deleted": user_deleted}

    def update_user_status(self, user_uuid: str, data: UpdateUserStatusRequest) -> None:
        user = self.db.query(User).filter(
            User.uuid == user_uuid,
            User.deleted_at.is_(None)
        ).first()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        if user.role == UserRole.SUPER_ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Cannot modify SUPER_ADMIN status"
            )
        
        user.is_active = data.is_active
        
        if not data.is_active:
            businesses = self.db.query(Business).filter(
                Business.owner_id == user.id,
                Business.deleted_at.is_(None)
            ).all()
            
            for business in businesses:
                business.is_active = False
        
        self.db.commit()
    
    def get_platform_statistics(self) -> PlatformStats:
        now = datetime.now(timezone.utc)
        month_start  = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        today_start  = now.replace(hour=0, minute=0, second=0, microsecond=0)
        week_start   = now - timedelta(days=7)
        month30_start = now - timedelta(days=30)

        # ── Business counts ───────────────────────────────────────────
        total_businesses = self.db.query(func.count(Business.id)).filter(
            Business.deleted_at.is_(None)
        ).scalar() or 0

        active_businesses = self.db.query(func.count(Business.id)).filter(
            Business.is_active == True,
            Business.deleted_at.is_(None)
        ).scalar() or 0

        free_plan_businesses = self.db.query(func.count(Business.id)).filter(
            Business.plan == BusinessPlan.FREE,
            Business.deleted_at.is_(None)
        ).scalar() or 0

        paid_plan_businesses = self.db.query(func.count(Business.id)).filter(
            Business.plan == BusinessPlan.PAID,
            Business.deleted_at.is_(None)
        ).scalar() or 0

        trial_plan_businesses = self.db.query(func.count(Business.id)).filter(
            Business.plan == BusinessPlan.PAID,
            Business.subscription_type == "trial",
            Business.deleted_at.is_(None)
        ).scalar() or 0

        # Businesses that have at least 1 order
        businesses_with_orders = self.db.query(
            func.count(func.distinct(Order.business_id))
        ).filter(Order.deleted_at.is_(None)).scalar() or 0

        new_businesses_this_month = self.db.query(func.count(Business.id)).filter(
            Business.created_at >= month_start,
            Business.deleted_at.is_(None)
        ).scalar() or 0

        # ── User counts ───────────────────────────────────────────────
        total_users = self.db.query(func.count(User.id)).filter(
            User.deleted_at.is_(None)
        ).scalar() or 0

        active_users = self.db.query(func.count(User.id)).filter(
            User.is_active == True,
            User.deleted_at.is_(None)
        ).scalar() or 0

        super_admins = self.db.query(func.count(User.id)).filter(
            User.role == UserRole.SUPER_ADMIN,
            User.deleted_at.is_(None)
        ).scalar() or 0

        business_owners = self.db.query(func.count(User.id)).filter(
            User.role == UserRole.BUSINESS_OWNER,
            User.deleted_at.is_(None)
        ).scalar() or 0

        new_users_this_month = self.db.query(func.count(User.id)).filter(
            User.created_at >= month_start,
            User.deleted_at.is_(None)
        ).scalar() or 0

        # ── Login activity (last_login tracking) ─────────────────────
        active_users_today = self.db.query(func.count(User.id)).filter(
            User.last_login >= today_start,
            User.deleted_at.is_(None)
        ).scalar() or 0

        active_users_week = self.db.query(func.count(User.id)).filter(
            User.last_login >= week_start,
            User.deleted_at.is_(None)
        ).scalar() or 0

        active_users_month = self.db.query(func.count(User.id)).filter(
            User.last_login >= month30_start,
            User.deleted_at.is_(None)
        ).scalar() or 0

        # ── Catalogue & transactions ──────────────────────────────────
        total_products = self.db.query(func.count(Product.id)).filter(
            Product.deleted_at.is_(None)
        ).scalar() or 0

        total_orders = self.db.query(func.count(Order.id)).filter(
            Order.deleted_at.is_(None)
        ).scalar() or 0

        total_customers = self.db.query(func.count(Customer.id)).filter(
            Customer.deleted_at.is_(None)
        ).scalar() or 0

        # ── Revenue metrics ───────────────────────────────────────────
        total_revenue = self.db.query(func.sum(Order.total_amount)).filter(
            Order.payment_status == "PAID",
            Order.deleted_at.is_(None)
        ).scalar() or 0.0

        revenue_this_month = self.db.query(func.sum(Order.total_amount)).filter(
            Order.payment_status == "PAID",
            Order.order_date >= month_start,
            Order.deleted_at.is_(None)
        ).scalar() or 0.0

        # ARPU = total revenue ÷ paid businesses (excluding trial — they haven't paid yet)
        real_paid = max(paid_plan_businesses - trial_plan_businesses, 0)
        arpu = float(total_revenue) / real_paid if real_paid > 0 else 0.0

        # Conversion rate = actually paid (excl trial) ÷ total businesses × 100
        conversion_rate = round((real_paid / total_businesses * 100), 1) if total_businesses > 0 else 0.0

        return PlatformStats(
            total_businesses=total_businesses,
            active_businesses=active_businesses,
            inactive_businesses=total_businesses - active_businesses,
            free_plan_businesses=free_plan_businesses,
            paid_plan_businesses=paid_plan_businesses,
            trial_plan_businesses=trial_plan_businesses,
            businesses_with_orders=businesses_with_orders,
            new_businesses_this_month=new_businesses_this_month,
            total_users=total_users,
            active_users=active_users,
            super_admins=super_admins,
            business_owners=business_owners,
            new_users_this_month=new_users_this_month,
            active_users_today=active_users_today,
            active_users_week=active_users_week,
            active_users_month=active_users_month,
            total_products=total_products,
            total_orders=total_orders,
            total_customers=total_customers,
            total_revenue=float(total_revenue),
            revenue_this_month=float(revenue_this_month),
            arpu=round(arpu, 2),
            conversion_rate=conversion_rate,
        )
