from typing import List, Tuple, Optional
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from fastapi import HTTPException, status, UploadFile
from app.models.product import Product
from app.models.category import Category
from app.schemas.product import ProductCreateRequest, ProductUpdateRequest
from app.services.plan_limit_service import PlanLimitService
from app.services.file_upload_service import FileUploadService


class ProductService:
    def __init__(self, db: Session):
        self.db = db
    
    def create_product(self, business_id: int, data: ProductCreateRequest) -> Product:
        current_count = self.db.query(func.count(Product.id)).filter(
            Product.business_id == business_id,
            Product.deleted_at.is_(None)
        ).scalar() or 0
        
        can_create, limit = PlanLimitService.check_limit(
            self.db, business_id, "products", current_count
        )
        
        if not can_create:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={
                    "code": "PRODUCT_LIMIT_EXCEEDED",
                    "message": f"Free plan allows only {limit} products. Upgrade to PAID plan.",
                    "current": current_count,
                    "limit": limit
                }
            )
        
        if data.category_id:
            category = self.db.query(Category).filter(
                Category.id == data.category_id,
                Category.business_id == business_id,
                Category.deleted_at.is_(None)
            ).first()

            if not category:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Category not found or does not belong to your business"
                )

            # Check per-category product limit
            cat_product_count = self.db.query(func.count(Product.id)).filter(
                Product.business_id == business_id,
                Product.category_id == data.category_id,
                Product.deleted_at.is_(None)
            ).scalar() or 0

            can_add, max_per_cat = PlanLimitService.check_products_per_category_limit(
                self.db, business_id, cat_product_count
            )
            if not can_add:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail={
                        "code": "CATEGORY_PRODUCT_LIMIT_EXCEEDED",
                        "message": f"Free plan allows only {max_per_cat} products per category. Upgrade to PRO for unlimited.",
                        "current": cat_product_count,
                        "limit": max_per_cat
                    }
                )
        
        if data.sku:
            existing = self.db.query(Product).filter(
                Product.business_id == business_id,
                Product.sku == data.sku,
                Product.deleted_at.is_(None)
            ).first()
            
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Product with SKU '{data.sku}' already exists"
                )
        
        product = Product(
            business_id=business_id,
            category_id=data.category_id,
            name=data.name,
            description=data.description,
            sku=data.sku,
            price=data.price,
            cost_price=data.cost_price,
            stock_quantity=data.stock_quantity,
            unit=data.unit,
            image_url=data.image_url,
            image_urls=data.image_urls or [],
            sizes=data.sizes or [],
            is_active=data.is_active
        )
        
        # Sync image_url if not provided but image_urls is
        if not product.image_url and product.image_urls:
            product.image_url = product.image_urls[0]
        
        self.db.add(product)
        self.db.commit()
        self.db.refresh(product)
        return product
    
    def get_products(
        self,
        business_id: int,
        page: int = 1,
        page_size: int = 50,
        category_id: Optional[int] = None,
        is_active: Optional[bool] = None,
        search: Optional[str] = None,
        low_stock: Optional[bool] = None
    ) -> Tuple[List[Product], int]:
        query = self.db.query(Product).filter(
            Product.business_id == business_id,
            Product.deleted_at.is_(None)
        )
        
        if category_id:
            query = query.filter(Product.category_id == category_id)
        
        if is_active is not None:
            query = query.filter(Product.is_active == is_active)
        
        if low_stock:
            query = query.filter(Product.stock_quantity < 10)
        
        if search:
            search_pattern = f"%{search}%"
            query = query.filter(
                or_(
                    Product.name.ilike(search_pattern),
                    Product.sku.ilike(search_pattern),
                    Product.description.ilike(search_pattern)
                )
            )
        
        total = query.count()
        
        products = query.order_by(Product.created_at.desc()).offset(
            (page - 1) * page_size
        ).limit(page_size).all()
        
        return products, total
    
    def get_product_by_uuid(self, business_id: int, product_uuid: str) -> Product:
        product = self.db.query(Product).filter(
            Product.uuid == product_uuid,
            Product.business_id == business_id,
            Product.deleted_at.is_(None)
        ).first()
        
        if not product:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Product not found"
            )
        
        return product
    
    def update_product(
        self,
        business_id: int,
        product_uuid: str,
        data: ProductUpdateRequest
    ) -> Product:
        product = self.get_product_by_uuid(business_id, product_uuid)
        
        update_data = data.model_dump(exclude_unset=True)
        
        if "category_id" in update_data and update_data["category_id"]:
            category = self.db.query(Category).filter(
                Category.id == update_data["category_id"],
                Category.business_id == business_id,
                Category.deleted_at.is_(None)
            ).first()
            
            if not category:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Category not found or does not belong to your business"
                )
        
        if "sku" in update_data and update_data["sku"] and update_data["sku"] != product.sku:
            existing = self.db.query(Product).filter(
                Product.business_id == business_id,
                Product.sku == update_data["sku"],
                Product.id != product.id,
                Product.deleted_at.is_(None)
            ).first()
            
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Product with SKU '{update_data['sku']}' already exists"
                )
        
        for key, value in update_data.items():
            setattr(product, key, value)
            
        # Sync image_url with first image in list if image_urls was updated
        if "image_urls" in update_data:
            if update_data["image_urls"] and len(update_data["image_urls"]) > 0:
                product.image_url = update_data["image_urls"][0]
            else:
                product.image_url = None
        
        self.db.commit()
        self.db.refresh(product)
        return product
    
    def delete_product(self, business_id: int, product_uuid: str) -> None:
        product = self.get_product_by_uuid(business_id, product_uuid)
        
        product.deleted_at = datetime.now(timezone.utc)
        self.db.commit()
    
    async def upload_product_image(
        self,
        business_id: int,
        product_uuid: str,
        file: UploadFile
    ) -> str:
        product = self.get_product_by_uuid(business_id, product_uuid)
        
        if product.image_url:
            old_image_path = product.image_url.replace("/uploads/", "")
            FileUploadService.delete_file(old_image_path)
        
        file_path, relative_path = await FileUploadService.save_image(
            file, 
            folder="product_images", 
            max_width=800
        )
        
        product.image_url = FileUploadService.get_file_url(relative_path)
        self.db.commit()
        self.db.refresh(product)
        
        return product.image_url
    
    def toggle_product_status(self, business_id: int, product_uuid: str) -> Product:
        product = self.get_product_by_uuid(business_id, product_uuid)
        
        product.is_active = not product.is_active
        self.db.commit()
        self.db.refresh(product)
        
        return product
    
    def update_stock(self, business_id: int, product_uuid: str, quantity_change: int) -> Product:
        product = self.get_product_by_uuid(business_id, product_uuid)
        
        new_quantity = product.stock_quantity + quantity_change
        
        if new_quantity < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock. Available: {product.stock_quantity}, Required: {abs(quantity_change)}"
            )
        
        product.stock_quantity = new_quantity
        self.db.commit()
        self.db.refresh(product)
        
        return product
