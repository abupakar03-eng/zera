from typing import Optional, Dict
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import func
from fastapi import HTTPException, status, UploadFile
from app.models.business import Business
from app.models.product import Product
from app.models.order import Order, PaymentStatus
from app.models.customer import Customer
from app.schemas.business import BusinessUpdateRequest
from app.services.plan_limit_service import PlanLimitService
from app.services.file_upload_service import FileUploadService
from app.utils.slug import generate_slug, unique_slug


class BusinessService:
    def __init__(self, db: Session):
        self.db = db
    
    def get_business_by_id(self, business_id: int) -> Business:
        business = self.db.query(Business).filter(
            Business.id == business_id,
            Business.deleted_at.is_(None)
        ).first()
        
        if not business:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Business not found"
            )
        
        return business
    
    def get_business_by_uuid(self, business_uuid: str) -> Business:
        business = self.db.query(Business).filter(
            Business.uuid == business_uuid,
            Business.deleted_at.is_(None)
        ).first()
        
        if not business:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Business not found"
            )
        
        return business
    
    def update_business_profile(self, business_id: int, data: BusinessUpdateRequest) -> Business:
        business = self.get_business_by_id(business_id)
        
        update_data = data.model_dump(exclude_unset=True)
        
        if "phone" in update_data and update_data["phone"] != business.phone:
            existing = self.db.query(Business).filter(
                Business.phone == update_data["phone"],
                Business.id != business_id,
                Business.deleted_at.is_(None)
            ).first()
            
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Phone number already in use by another business"
                )
        
        if "email" in update_data and update_data["email"]:
            existing = self.db.query(Business).filter(
                Business.email == update_data["email"],
                Business.id != business_id,
                Business.deleted_at.is_(None)
            ).first()
            
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email already in use by another business"
                )
        
        for key, value in update_data.items():
            setattr(business, key, value)

        # Auto-update slug when business_name changes
        if "business_name" in update_data:
            base = generate_slug(update_data["business_name"])
            business.store_slug = unique_slug(base, self.db, exclude_id=business_id)

        # Auto-generate slug if missing
        if not business.store_slug:
            base = generate_slug(business.business_name)
            business.store_slug = unique_slug(base, self.db, exclude_id=business_id)

        # Sync logo_url with first profile image if changed
        if "profile_image_urls" in update_data and update_data["profile_image_urls"]:
            business.logo_url = update_data["profile_image_urls"][0]
        elif "profile_image_urls" in update_data and not update_data["profile_image_urls"]:
            business.logo_url = None
        
        self.db.commit()
        self.db.refresh(business)
        return business
    
    async def upload_logo(self, business_id: int, file: UploadFile) -> Business:
        business = self.get_business_by_id(business_id)

        if business.logo_url:
            old_path = business.logo_url.replace("/uploads/", "")
            FileUploadService.delete_file(old_path)

        _, relative_path = await FileUploadService.save_image(file, folder="logos", max_width=500)
        business.logo_url = FileUploadService.get_file_url(relative_path)

        self.db.commit()
        self.db.refresh(business)
        return business

    async def upload_banner(self, business_id: int, file: UploadFile) -> Business:
        business = self.get_business_by_id(business_id)

        if business.banner_url:
            old_path = business.banner_url.replace("/uploads/", "")
            FileUploadService.delete_file(old_path)

        _, relative_path = await FileUploadService.save_image(file, folder="banners", max_width=1200)
        business.banner_url = FileUploadService.get_file_url(relative_path)

        self.db.commit()
        self.db.refresh(business)
        return business

    async def upload_images(self, business_id: int, files: list) -> Business:
        business = self.get_business_by_id(business_id)

        if len(files) > 10:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Maximum 10 images allowed per upload"
            )

        new_urls = []
        for file in files:
            _, relative_path = await FileUploadService.save_image(
                file, folder="profile_images", max_width=800
            )
            new_urls.append(FileUploadService.get_file_url(relative_path))

        current = list(business.profile_image_urls or [])
        current.extend(new_urls)
        business.profile_image_urls = current[:10]

        if not business.logo_url and business.profile_image_urls:
            business.logo_url = business.profile_image_urls[0]

        self.db.commit()
        self.db.refresh(business)
        return business
    
    def delete_business(self, business_id: int, user) -> None:
        business = self.get_business_by_id(business_id)
        self.db.delete(business)
        self.db.delete(user)
        self.db.commit()

    def get_business_stats(self, business_id: int) -> Dict:
        business = self.get_business_by_id(business_id)
        
        total_products = self.db.query(func.count(Product.id)).filter(
            Product.business_id == business_id,
            Product.deleted_at.is_(None)
        ).scalar() or 0
        
        active_products = self.db.query(func.count(Product.id)).filter(
            Product.business_id == business_id,
            Product.is_active == True,
            Product.deleted_at.is_(None)
        ).scalar() or 0
        
        total_orders = self.db.query(func.count(Order.id)).filter(
            Order.business_id == business_id,
            Order.deleted_at.is_(None)
        ).scalar() or 0
        
        total_customers = self.db.query(func.count(Customer.id)).filter(
            Customer.business_id == business_id,
            Customer.deleted_at.is_(None)
        ).scalar() or 0
        
        total_revenue = self.db.query(func.sum(Order.total_amount)).filter(
            Order.business_id == business_id,
            Order.payment_status == PaymentStatus.PAID,
            Order.deleted_at.is_(None)
        ).scalar() or 0.0
        
        plan_limits = PlanLimitService.get_plan_limits_dict(self.db, business_id)
        
        return {
            "total_products": total_products,
            "active_products": active_products,
            "total_orders": total_orders,
            "total_customers": total_customers,
            "total_revenue": float(total_revenue),
            "plan": business.plan.value,
            "plan_limits": plan_limits
        }
