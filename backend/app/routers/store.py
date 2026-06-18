"""
Public storefront API — no authentication required.
All endpoints are scoped to a business via its public UUID.
"""
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status, UploadFile, File
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from sqlalchemy import func
from decimal import Decimal

from app.database import get_db
from app.models.business import Business
from app.models.review import BusinessReview
from app.models.product import Product
from app.models.category import Category
from app.models.customer import Customer
from app.models.order import Order, OrderItem, OrderStatus, PaymentStatus
from app.schemas.store import (
    StoreInfoResponse,
    StoreCategoryResponse,
    StoreProductResponse,
    StoreOrderCreate,
    StoreOrderResponse,
    StoreOrderItemResponse,
    StoreOrderStatusResponse,
    StoreReviewCreate,
)
from app.core.websocket_manager import manager as _ws_manager
from app.utils.logger import logger
import asyncio
import json

router = APIRouter(prefix="/store", tags=["storefront"])


# ── Helpers ──────────────────────────────────────────────────────────────────

def _get_active_business(identifier: str, db: Session) -> Business:
    """Lookup business by UUID or store_slug."""
    business = db.query(Business).filter(
        Business.is_active == True,
        Business.deleted_at.is_(None),
    ).filter(
        (Business.uuid == identifier) | (Business.store_slug == identifier)
    ).first()
    if not business:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Store not found")
    return business


def _emit(event: str, data: dict, business_id: int) -> None:
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            asyncio.run_coroutine_threadsafe(
                _ws_manager.broadcast(business_id, event, data), loop
            )
    except Exception as e:
        logger.warning(f"WebSocket broadcast failed for business {business_id}: {e}")


def _order_to_response(order: Order, items: List[OrderItem]) -> StoreOrderResponse:
    return StoreOrderResponse(
        order_number=order.order_number,
        status=order.status.value,
        payment_status=order.payment_status.value,
        payment_method=order.payment_method or "COD",
        subtotal=float(order.subtotal),
        total_amount=float(order.total_amount),
        payment_proof_url=order.payment_proof_url,
        items=[
            StoreOrderItemResponse(
                product_name=i.product_name,
                product_sku=i.product_sku,
                quantity=i.quantity,
                unit_price=float(i.unit_price),
                total_price=float(i.total_price),
            )
            for i in items
        ],
        created_at=order.created_at,
    )


def _wa_number(phone: Optional[str]) -> str:
    if not phone:
        return ""
    digits = "".join(c for c in phone if c.isdigit())
    if len(digits) == 10:
        digits = "91" + digits
    return digits


# ── GET /store/{business_uuid} ────────────────────────────────────────────────

@router.get("/{business_uuid}", response_model=StoreInfoResponse)
def get_store_info(business_uuid: str, db: Session = Depends(get_db)):
    business = _get_active_business(business_uuid, db)
    # Calculate rating
    reviews = db.query(BusinessReview).filter(BusinessReview.business_id == business.id).all()
    avg = sum(r.rating for r in reviews) / len(reviews) if reviews else 0.0
    
    return StoreInfoResponse(
        uuid=business.uuid,
        business_name=business.business_name,
        phone=business.phone,
        logo_url=business.profile_image_urls[0] if business.profile_image_urls and len(business.profile_image_urls) > 0 else None,
        profile_image_urls=business.profile_image_urls or [],
        banner_url=business.banner_url,
        upi_id=business.upi_id,
        address=business.address,
        city=business.city,
        state=business.state,
        average_rating=round(avg, 1),
        review_count=len(reviews),
    )


# ── GET /store/{business_uuid}/categories ────────────────────────────────────

@router.get("/{business_uuid}/categories", response_model=List[StoreCategoryResponse])
def get_store_categories(business_uuid: str, db: Session = Depends(get_db)):
    business = _get_active_business(business_uuid, db)
    categories = db.query(Category).filter(
        Category.business_id == business.id,
        Category.is_active == True,
        Category.deleted_at.is_(None),
    ).order_by(Category.name).all()
    return [StoreCategoryResponse(uuid=c.uuid, name=c.name) for c in categories]


# ── GET /store/{business_uuid}/products ──────────────────────────────────────

@router.get("/{business_uuid}/products", response_model=List[StoreProductResponse])
def get_store_products(
    business_uuid: str,
    db: Session = Depends(get_db),
    search: Optional[str] = Query(None, max_length=100),
    category_uuid: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    business = _get_active_business(business_uuid, db)

    query = db.query(Product, Category).outerjoin(
        Category, Category.id == Product.category_id
    ).filter(
        Product.business_id == business.id,
        Product.is_active == True,
        Product.deleted_at.is_(None),
    )

    if search:
        query = query.filter(Product.name.ilike(f"%{search}%"))

    if category_uuid:
        cat = db.query(Category).filter(
            Category.uuid == category_uuid,
            Category.business_id == business.id,
        ).first()
        if cat:
            query = query.filter(Product.category_id == cat.id)

    offset = (page - 1) * page_size
    rows = query.order_by(Product.name).offset(offset).limit(page_size).all()

    return [
        StoreProductResponse(
            uuid=p.uuid,
            name=p.name,
            description=p.description,
            price=float(p.price),
            unit=p.unit,
            image_url=p.image_urls[0] if (p.image_urls and len(p.image_urls) > 0) else p.image_url,
            image_urls=p.image_urls or [],
            sizes=p.sizes or [],
            stock_quantity=p.stock_quantity,
            category_name=c.name if c else None,
            is_available=p.stock_quantity > 0,
        )
        for p, c in rows
    ]


# ── POST /store/{business_uuid}/orders ───────────────────────────────────────

@router.post("/{business_uuid}/orders", response_model=StoreOrderResponse, status_code=201)
def place_store_order(
    business_uuid: str,
    data: StoreOrderCreate,
    db: Session = Depends(get_db),
):
    business = _get_active_business(business_uuid, db)

    # Upsert guest customer
    customer = db.query(Customer).filter(
        Customer.business_id == business.id,
        Customer.phone == data.customer_phone,
        Customer.deleted_at.is_(None),
    ).first()

    if not customer:
        customer = Customer(
            business_id=business.id,
            name=data.customer_name,
            phone=data.customer_phone,
        )
        db.add(customer)
        db.flush()
    else:
        customer.name = data.customer_name

    order_items_data = []
    subtotal = Decimal("0.00")

    for item_req in data.items:
        product = db.query(Product).filter(
            Product.uuid == item_req.product_uuid,
            Product.business_id == business.id,
            Product.is_active == True,
            Product.deleted_at.is_(None),
        ).first()

        if not product:
            raise HTTPException(status_code=400, detail="Product not found")

        if product.stock_quantity < item_req.quantity:
            raise HTTPException(status_code=400, detail=f"'{product.name}' stock low")

        product.stock_quantity -= item_req.quantity
        item_total = product.price * item_req.quantity
        subtotal += item_total

        # Append selected size to SKU: e.g. "SHIRT-001-L"
        sku = product.sku or ""
        if item_req.selected_size:
            sku = f"{sku}-{item_req.selected_size}" if sku else item_req.selected_size

        order_items_data.append({
            "product_id": product.id,
            "product_name": product.name,
            "product_sku": sku or None,
            "quantity": item_req.quantity,
            "unit_price": product.price,
            "total_price": item_total,
        })

    from datetime import datetime, timezone
    import random
    utc_now = datetime.now(timezone.utc)
    utc_today = utc_now.date()
    today = utc_now.strftime("%Y%m%d")
    count = db.query(func.count(Order.id)).filter(
        Order.business_id == business.id,
        func.date(Order.order_date) == utc_today,
    ).scalar() or 0
    # Add a small random suffix to prevent race-condition collisions
    rand_suffix = random.randint(0, 9)
    order_number = f"ORD{today}B{business.id:04d}{count + 1:04d}{rand_suffix}"

    order = Order(
        business_id=business.id,
        customer_id=customer.id,
        order_number=order_number,
        status=OrderStatus.PENDING,
        payment_status=PaymentStatus.PENDING,
        subtotal=subtotal,
        total_amount=subtotal,
        payment_method=data.payment_method,
        notes=data.notes,
    )
    db.add(order)
    db.flush()

    items: List[OrderItem] = []
    for item_data in order_items_data:
        oi = OrderItem(order_id=order.id, **item_data)
        db.add(oi)
        items.append(oi)

    db.commit()
    db.refresh(order)

    _emit("order.created", {
        "order_uuid": str(order.uuid),
        "order_number": order.order_number,
        "status": order.status.value,
        "total_amount": float(order.total_amount),
        "source": "storefront",
    }, business.id)

    return _order_to_response(order, items)


# ── GET /store/{business_uuid}/orders/{order_number} ─────────────────────────

@router.get("/{business_uuid}/orders/{order_number}", response_model=StoreOrderStatusResponse)
def get_order_status(
    business_uuid: str,
    order_number: str,
    db: Session = Depends(get_db),
):
    business = _get_active_business(business_uuid, db)
    order = db.query(Order).filter(Order.order_number == order_number, Order.business_id == business.id).first()
    if not order: raise HTTPException(status_code=404, detail="Order not found")
    items = db.query(OrderItem).filter(OrderItem.order_id == order.id).all()
    return StoreOrderStatusResponse(
        order_number=order.order_number,
        status=order.status.value,
        payment_status=order.payment_status.value,
        payment_method=order.payment_method or "COD",
        subtotal=float(order.subtotal),
        total_amount=float(order.total_amount),
        items=[StoreOrderItemResponse(product_name=i.product_name, quantity=i.quantity, unit_price=float(i.unit_price), total_price=float(i.total_price)) for i in items],
        payment_proof_url=order.payment_proof_url,
        created_at=order.created_at,
        notes=order.notes,
    )


@router.post("/{business_uuid}/orders/{order_number}/payment-proof", response_model=StoreOrderStatusResponse)
async def upload_payment_proof(
    business_uuid: str,
    order_number: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    business = _get_active_business(business_uuid, db)
    order = db.query(Order).filter(
        Order.order_number == order_number, 
        Order.business_id == business.id
    ).first()
    
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    from app.services.file_upload_service import FileUploadService
    
    # Save the screenshot
    _, relative_path = await FileUploadService.save_image(
        file, 
        folder="payment_proofs", 
        max_width=1200
    )
    
    order.payment_proof_url = FileUploadService.get_file_url(relative_path)
    db.commit()
    db.refresh(order)

    # Emit event to notify the seller app
    _emit("order.updated", {
        "order_uuid": str(order.uuid),
        "order_number": order.order_number,
        "payment_status": order.payment_status.value,
        "has_proof": True,
    }, business.id)

    items = db.query(OrderItem).filter(OrderItem.order_id == order.id).all()
    return StoreOrderStatusResponse(
        order_number=order.order_number,
        status=order.status.value,
        payment_status=order.payment_status.value,
        payment_method=order.payment_method or "COD",
        subtotal=float(order.subtotal),
        total_amount=float(order.total_amount),
        items=[StoreOrderItemResponse(product_name=i.product_name, quantity=i.quantity, unit_price=float(i.unit_price), total_price=float(i.total_price)) for i in items],
        payment_proof_url=order.payment_proof_url,
        created_at=order.created_at,
        notes=order.notes,
    )


@router.post("/{business_uuid}/reviews", status_code=201)
def submit_store_review(
    business_uuid: str,
    data: StoreReviewCreate,
    db: Session = Depends(get_db),
):
    business = _get_active_business(business_uuid, db)
    
    order_id = None
    if data.order_number:
        order = db.query(Order).filter(Order.order_number == data.order_number, Order.business_id == business.id).first()
        if order: order_id = order.id

    review = BusinessReview(
        business_id=business.id,
        order_id=order_id,
        customer_name=data.customer_name,
        rating=data.rating,
        comment=data.comment
    )
    db.add(review)
    db.commit()
    
    _emit("business.review_received", {
        "rating": data.rating,
        "customer": data.customer_name,
    }, business.id)
    
    return {"success": True, "message": "Review submitted"}


# ── GET /store/{business_uuid}/web (Premium HTML Storefront) ─────────────────

@router.get("/{business_uuid}/web", response_class=HTMLResponse)
def get_store_web(business_uuid: str, request: Request, db: Session = Depends(get_db)):
    """Mobile-optimized premium PWA storefront."""
    business = _get_active_business(business_uuid, db)

    # Reviews computation
    reviews_all = db.query(BusinessReview).filter(BusinessReview.business_id == business.id).order_by(BusinessReview.created_at.desc()).all()
    avg_rating = sum(r.rating for r in reviews_all) / len(reviews_all) if reviews_all else 0.0
    recent_reviews = [{"name": r.customer_name, "rating": r.rating, "comment": r.comment} for r in reviews_all[:5]]


    products_raw = db.query(Product, Category).outerjoin(
        Category, Category.id == Product.category_id
    ).filter(
        Product.business_id == business.id,
        Product.is_active == True,
        Product.deleted_at.is_(None),
    ).order_by(Product.name).all()

    categories_raw = db.query(Category).filter(
        Category.business_id == business.id,
        Category.is_active == True,
        Category.deleted_at.is_(None),
    ).order_by(Category.name).all()

    base_url = str(request.base_url).rstrip("/")
    
    products_js = []
    for p, c in products_raw:
        img = p.image_url if p.image_url and p.image_url.startswith("http") else f"{base_url}{p.image_url}" if p.image_url else None
        products_js.append({
            "uuid": p.uuid,
            "name": p.name,
            "price": float(p.price),
            "img": img,
            "cat": c.name if c else "General",
        })

    categories_js = [{"uuid": c.uuid, "name": c.name} for c in categories_raw]
    city_state = ", ".join(filter(None, [business.city, business.state]))
    
    logo_url = business.logo_url if business.logo_url and business.logo_url.startswith("http") else f"{base_url}{business.logo_url}" if business.logo_url else None
    banner_url = business.banner_url if business.banner_url and business.banner_url.startswith("http") else f"{base_url}{business.banner_url}" if business.banner_url else None
    
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0">
    <title>{business.business_name} | StoreLink</title>
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap" rel="stylesheet">
    <style>
        :root {{ --bg: #09090E; --card: #16161F; --accent: #00E5FF; --text: #FFFFFF; --text-dim: #888; }}
        body {{ background: var(--bg); color: var(--text); font-family: 'Outfit', sans-serif; margin: 0; padding: 0; overflow-x: hidden; }}
        
        .hero {{ position: relative; height: 180px; width: 100%; overflow: hidden; }}
        .hero-banner {{ width: 100%; height: 100%; object-fit: cover; filter: brightness(0.6); }}
        .hero-overlay {{ position: absolute; inset: 0; background: linear-gradient(180deg, transparent 0%, rgba(9,9,14,0.8) 100%); }}
        
        header {{ position: relative; margin-top: -40px; padding: 0 20px 20px; display: flex; align-items: flex-end; gap: 16px; z-index: 2; }}
        .logo {{ width: 80px; height: 80px; border-radius: 20px; background: #16161F; border: 4px solid var(--bg); overflow: hidden; display: flex; align-items: center; justify-content: center; box-shadow: 0 10px 20px rgba(0,0,0,0.3); }}
        .logo img {{ width: 100%; height: 100%; object-fit: cover; }}
        
        .biz-info {{ margin-bottom: 8px; }}
        .biz-name {{ font-size: 24px; font-weight: 800; margin: 0; letter-spacing: -0.5px; text-shadow: 0 2px 4px rgba(0,0,0,0.5); }}
        .biz-sub {{ font-size: 13px; color: #888; margin: 4px 0 0; display: flex; align-items: center; gap: 6px; }}
        .status-dot {{ width: 6px; height: 6px; background: #00E676; border-radius: 50%; box-shadow: 0 0 10px #00E676; }}

        .search-area {{ padding: 10px 20px; position: sticky; top: 0; background: var(--bg); z-index: 10; border-bottom: 1px solid #ffffff05; }}
        .search-box {{ background: #ffffff08; border-radius: 12px; padding: 12px; border: 1px solid #ffffff10; display: flex; align-items: center; gap: 10px; }}
        .search-box input {{ background: transparent; border: none; color: white; width: 100%; font-size: 15px; outline: none; }}
        
        .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 12px; padding: 20px; padding-bottom: 120px; }}
        .p-card {{ background: var(--card); border-radius: 20px; overflow: hidden; border: 1px solid #ffffff08; position: relative; transition: transform 0.2s; }}
        .p-card:active {{ transform: scale(0.97); }}
        .p-img {{ width: 100%; aspect-ratio: 1; object-fit: cover; background: #111; }}
        .p-info {{ padding: 12px; }}
        .p-name {{ font-size: 13px; font-weight: 600; margin-bottom: 4px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }}
        .p-price {{ font-size: 15px; font-weight: 800; color: var(--accent); }}
        .buy-btn {{ background: var(--accent); color: black; border: none; width: 100%; padding: 10px; border-radius: 10px; font-weight: 800; font-size: 11px; margin-top: 8px; cursor: pointer; }}
        
        .cart-bar {{ position: fixed; bottom: 20px; left: 20px; right: 20px; background: var(--accent); color: black; padding: 16px 24px; border-radius: 20px; display: flex; justify-content: space-between; align-items: center; font-weight: 800; z-index: 100; box-shadow: 0 15px 35px rgba(0,229,255,0.4); border: none; cursor: pointer; }}
        
        .overlay {{ position: fixed; inset: 0; background: #000000dd; backdrop-filter: blur(10px); z-index: 1000; display: flex; align-items: flex-end; }}
        .sheet {{ background: #111; width: 100%; padding: 30px 24px calc(env(safe-area-inset-bottom) + 20px); border-radius: 24px 24px 0 0; border-top: 1px solid #ffffff11; max-height: 90vh; overflow-y: auto; }}
        .input {{ width: 100%; background: #ffffff08; border: 1px solid #ffffff11; border-radius: 12px; padding: 14px; color: white; margin-bottom: 12px; font-family: inherit; font-size: 15px; outline: none; box-sizing: border-box; }}
        .confirm-btn {{ background: var(--accent); color: black; border: none; width: 100%; padding: 16px; border-radius: 14px; font-weight: 900; font-size: 15px; margin-top: 10px; cursor: pointer; }}
        
        .cat-tag {{ font-size: 9px; text-transform: uppercase; color: var(--accent); font-weight: 800; letter-spacing: 0.5px; opacity: 0.7; }}
        .payment-methods {{ display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 20px; }}
        .p-method {{ background: #ffffff08; border: 1px solid #ffffff11; border-radius: 12px; padding: 12px; text-align: center; cursor: pointer; }}
        .p-method.active {{ border-color: var(--accent); background: #00E5FF11; }}
        .upi-section {{ background: #ffffff05; border-radius: 16px; padding: 20px; text-align: center; border: 1px dashed #ffffff22; margin: 20px 0; }}
        .upi-id {{ font-size: 18px; font-weight: 900; color: var(--accent); margin: 10px 0; }}
        .step {{ font-size: 13px; color: #888; margin-top: 10px; }}
        #proof-input {{ display: none; }}
        .success-badge {{ background: #00C853; color: white; padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 800; }}
        
        .tos-link {{ color: #555; text-decoration: underline; cursor: pointer; font-size: 11px; font-weight: 600; }}
        .tos-link:hover {{ color: var(--accent); }}
        .tos-overlay {{ position: fixed; inset: 0; background: rgba(0,0,0,0.9); backdrop-filter: blur(5px); z-index: 2000; display: flex; align-items: center; justify-content: center; padding: 20px; }}
        .tos-modal {{ background: #1a1a24; border-radius: 20px; padding: 30px; border: 1px solid #ffffff11; max-width: 400px; }}

        .rating-chip {{ background: #FFD60022; color: #FFD600; padding: 4px 10px; border-radius: 12px; font-size: 12px; font-weight: 800; display: inline-flex; align-items: center; gap: 4px; border: 1px solid #FFD60044; }}
        .star-rating {{ display: flex; gap: 8px; font-size: 30px; margin: 15px 0; justify-content: center; }}
        .star {{ cursor: pointer; color: #333; }}
        .star.active {{ color: #FFD600; text-shadow: 0 0 15px rgba(255,214,0,0.4); }}
    </style>
</head>
<body>
    <div id="app">
        <div class="hero">
            <img v-if="bannerUrl" :src="bannerUrl" class="hero-banner">
            <div v-else class="hero-banner" style="background: linear-gradient(45deg, #12121e, #1a1a2e);"></div>
            <div class="hero-overlay"></div>
        </div>

        <header>
            <div class="logo">
                <img v-if="logoUrl" :src="logoUrl">
                <span v-else style="font-size: 30px;">🏪</span>
            </div>
            <div class="biz-info">
                <h1 class="biz-name">{{{{ businessName }}}}</h1>
                <div class="biz-sub">
                    <div class="status-dot"></div>
                    <span>{{{{ location || 'Online Premium Store' }}}}</span>
                </div>
                <div v-if="avgRating > 0" class="rating-chip" style="margin-top: 4px;">
                   <span>⭐</span> <span>{{{{ avgRating.toFixed(1) }}}}</span> <span style="opacity: 0.5; font-size: 10px;">({{{{ reviewCount }}}})</span>
                </div>
            </div>
        </header>

        <div class="search-area">
            <div class="search-box">
                <span>🔍</span>
                <input v-model="q" placeholder="Search products...">
            </div>
        </div>

        <div class="grid" v-if="filtered.length">
            <div v-for="p in filtered" :key="p.uuid" class="p-card" @click="add(p)">
                <img :src="p.img || 'https://via.placeholder.com/300/111/444'" class="p-img">
                <div class="p-info">
                    <div class="cat-tag">{{{{ p.cat }}}}</div>
                    <div class="p-name">{{{{ p.name }}}}</div>
                    <div class="p-price">₹{{{{ p.price.toLocaleString('en-IN') }}}}</div>
                    <button class="buy-btn">{{{{ cart[p.uuid] ? 'Added (' + cart[p.uuid] + ')' : 'Add to Bag +' }}}}</button>
                </div>
            </div>
        </div>
        <div v-else style="text-align: center; padding: 100px 20px; color: #444;">No products found in this store.</div>

        <div v-if="recentReviews.length > 0" style="padding: 20px;">
            <label style="font-size: 11px; font-weight: 800; color: var(--accent); display: block; margin-bottom: 20px; letter-spacing: 1px;">WHAT CUSTOMERS SAY</label>
            <div style="display: flex; gap: 12px; overflow-x: auto; padding-bottom: 10px; scrollbar-width: none;">
                <div v-for="r in recentReviews" :key="r.name" style="background: #16161F; padding: 16px; border-radius: 20px; border: 1px solid #ffffff08; min-width: 250px;">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                        <div style="font-size: 13px; font-weight: 800;">{{{{ r.name }}}}</div>
                        <div style="color: #FFD600; font-size: 12px;">{{{{ '★'.repeat(r.rating) }}}}</div>
                    </div>
                    <div style="font-size: 12px; color: #888; line-height: 1.5;">{{{{ r.comment || 'Beautiful products and great service!' }}}}</div>
                </div>
            </div>
        </div>

        <div style="padding: 40px 20px; border-top: 1px solid #ffffff05; background: #00000022; text-align: center;">
            <label style="font-size: 10px; font-weight: 800; color: var(--accent); letter-spacing: 2px; display: block; margin-bottom: 20px;">PLATFORM DISCLAIMER</label>
            <p style="font-size: 12px; color: #666; line-height: 1.6; max-width: 500px; margin: 0 auto;">
                StoreLink is an MSME platform that connects buyers and sellers. All transactions, product quality, and payments are directly between the buyer and the seller. Hantas AI (the platform developer) is NOT party to these transactions and is not responsible for any disputes or losses.
            </p>
        </div>

        <div style="text-align: center; padding: 40px 20px 80px;">
            <div style="margin-bottom: 24px;">
                <button class="buy-btn" @click="sheet = true; orderComplete = null; cart = {{}};" style="width: auto; padding: 12px 30px; background: #ffffff08; color: white; border: 1px solid #ffffff11;"> Share Seller Feedback 🎖️</button>
            </div>
            <span class="tos-link" @click="tos = true">Terms & Service</span>
        </div>

        <div class="cart-bar" v-if="count > 0" @click="sheet = true">
            <div style="display: flex; align-items: center; gap: 12px;">
                <span style="background: black; color: var(--accent); border-radius: 8px; padding: 4px 10px; font-size: 13px;">{{{{ count }}}}</span>
                <span>Checkout Now</span>
            </div>
            <span>₹{{{{ total.toLocaleString('en-IN') }}}}</span>
        </div>

        <div class="overlay" v-if="sheet" @click.self="sheet = false">
            <div class="sheet">
                <h2 style="margin-top: 0; font-size: 26px; font-weight: 800; letter-spacing: -0.5px;">Your Bag</h2>
                <div v-for="item in cartItems" :key="item.uuid" style="display: flex; justify-content: space-between; margin-bottom: 12px; align-items: center;">
                    <div>
                        <div style="font-size: 15px; font-weight: 600;">{{{{ item.name }}}}</div>
                        <div style="font-size: 12px; color: #888;">Qty: {{{{ item.qty }}}}</div>
                    </div>
                    <div style="font-weight: 800; color: var(--accent);">₹{{{{ (item.price * item.qty).toLocaleString('en-IN') }}}}</div>
                </div>
                <hr style="border: none; border-top: 1px solid #ffffff11; margin: 20px 0;">
                
                <div v-if="!orderComplete">
                    <label style="font-size: 11px; font-weight: 800; color: var(--accent); margin-bottom: 12px; display: block; letter-spacing: 1px;">CHOOSE PAYMENT</label>
                    <div class="payment-methods">
                        <div class="p-method" :class="{{active: payMethod === 'COD'}}" @click="payMethod = 'COD'">
                            <div style="font-size: 20px;">💵</div>
                            <div style="font-size: 12px; font-weight: 600; margin-top: 4px;">COD</div>
                        </div>
                        <div class="p-method" :class="{{active: payMethod === 'UPI'}}" @click="payMethod = 'UPI'">
                            <div style="font-size: 20px;">📱</div>
                            <div style="font-size: 12px; font-weight: 600; margin-top: 4px;">UPI</div>
                        </div>
                    </div>

                    <label style="font-size: 11px; font-weight: 800; color: var(--accent); margin-bottom: 8px; display: block; letter-spacing: 1px;">DELIVERY ADDRESS</label>
                    <input v-model="name" class="input" placeholder="Full Name">
                    <input v-model="phone" class="input" placeholder="Mobile Number" type="tel">
                    <textarea v-model="addr" class="input" placeholder="Full Address with Pincode" rows="3"></textarea>
                    
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 20px; margin-bottom: 10px;">
                        <span style="color: #888; font-weight: 600;">Total Payable</span>
                        <span style="color: var(--accent); font-weight: 900; font-size: 28px;">₹{{{{ total.toLocaleString('en-IN') }}}}</span>
                    </div>
                    <button class="confirm-btn" @click="placeOrder" :disabled="loading">
                        {{{{ loading ? 'Securing Order...' : (payMethod === 'COD' ? 'Place COD Order ⚡' : 'Pay & Confirm ⚡') }}}}
                    </button>
                    <p style="text-align: center; font-size: 11px; color: #555; margin-top: 16px;">
                        Powered by StoreLink • <span class="tos-link" @click="tos = true">Terms & Service</span>
                    </p>
                </div>

                <div v-else>
                    <div style="text-align: center; margin-bottom: 20px;">
                        <div style="font-size: 50px; margin-bottom: 10px;">🔥</div>
                        <h3 style="margin: 0; font-size: 22px; font-weight: 800;">Order Received!</h3>
                        <p style="color: var(--accent); font-size: 14px; font-weight: 600; margin-top: 6px;">{{{{ orderComplete.order_number }}}}</p>
                    </div>

                    <div v-if="payMethod === 'UPI'" class="upi-section">
                        <label style="font-size: 10px; font-weight: 800; color: var(--accent); letter-spacing: 1px;">UPI PAYMENT DETAILS</label>
                        <div class="upi-id">{business.upi_id or 'merchant@upi'}</div>
                        <div class="step">Pay ₹{{{{ total.toLocaleString('en-IN') }}}} via any UPI app</div>
                        <div class="step">Take a screenshot & upload below</div>
                        
                        <input type="file" id="proof-input" accept="image/*" @change="uploadProof">
                        <button class="upload-btn" onclick="document.getElementById('proof-input').click()" :disabled="uploading">
                            <span>{{{{ uploading ? 'Processing...' : 'Upload Payment Screenshot 📷' }}}}</span>
                            <div v-if="proofUploaded" class="success-badge">DONE</div>
                        </button>
                        <div v-if="proofUploaded" style="font-size: 11px; color: #00C853; margin-top: 8px; font-weight: 600;">✅ Proof submitted successfully!</div>
                    </div>

                    <button class="confirm-btn" @click="finalWA">
                        Finish on WhatsApp 💬
                    </button>
                    
                    <div v-if="!reviewSubmitted" style="margin-top: 30px; padding-top: 30px; border-top: 1px solid #ffffff11;">
                        <label style="font-size: 11px; font-weight: 800; color: var(--accent); display: block; text-align: center; letter-spacing: 1px;">RATE YOUR EXPERIENCE</label>
                        <div class="star-rating">
                            <span v-for="s in 5" :key="s" class="star" :class="{{active: s <= feedbackRating}}" @click="feedbackRating = s">★</span>
                        </div>
                        <input v-model="feedbackComment" class="input" placeholder="Any feedback for the seller? (Optional)">
                        <button class="upload-btn" @click="submitReview" :disabled="loading">
                           {{{{ loading ? 'Submitting...' : 'Submit Seller Feedback 🎖️' }}}}
                        </button>
                    </div>
                    <div v-else style="text-align: center; margin-top: 20px; color: #00C853; font-weight: 600; font-size: 13px;">
                        🎖️ Thank you for your feedback!
                    </div>
                </div>
            </div>
        </div>

        <!-- TOS Overlay -->
        <div class="tos-overlay" v-if="tos" @click.self="tos = false">
            <div class="tos-modal">
                <h3 style="margin-top: 0; color: var(--accent);">Terms & Service</h3>
                <div style="font-size: 13px; line-height: 1.6; color: #bbb;">
                    <p><strong>Disclaimer:</strong> StoreLink is an MSME platform that connects buyers and sellers. All transactions, product quality, and deliveries are directly between the buyer and the seller.</p>
                    <p><strong>Company Notice:</strong> Hantas AI (the platform developer) is NOT party to any transactions on this store. Users are responsible for verifying the identity and credentials of each other before making payments.</p>
                </div>
                <button class="confirm-btn" @click="tos = false" style="margin-top: 20px; padding: 12px;">I Understand</button>
            </div>
        </div>
    </div>

    <script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
    <script>
        const {{{{ createApp }}}} = Vue;
        createApp({{
            data() {{
                return {{
                    businessUuid: '{business_uuid}',
                    businessName: '{business.business_name}',
                    location: '{city_state}',
                    logoUrl: '{logo_url or ""}',
                    bannerUrl: '{banner_url or ""}',
                    products: {json.dumps(products_js)},
                    cart: {{}}, q: '', sheet: false, name: '', phone: '', addr: '', loading: false,
                    payMethod: 'COD', orderComplete: null, proofUploaded: false, uploading: false,
                    tos: false, avgRating: {avg_rating}, reviewCount: {len(reviews_all)},
                    feedbackRating: 5, feedbackComment: '', reviewSubmitted: false,
                    recentReviews: {json.dumps(recent_reviews)}
                }}
            }},
            computed: {{
                filtered() {{ return this.products.filter(p => p.name.toLowerCase().includes(this.q.toLowerCase())) }},
                total() {{ return Object.keys(this.cart).reduce((s, id) => s + (this.products.find(p => p.uuid === id).price * this.cart[id]), 0) }},
                count() {{ return Object.values(this.cart).reduce((a, b) => a + b, 0) }},
                cartItems() {{ return Object.keys(this.cart).map(id => ({{ ...this.products.find(p => p.uuid === id), qty: this.cart[id] }})) }}
            }},
            methods: {{
                add(p) {{ this.cart[p.uuid] = (this.cart[p.uuid] || 0) + 1 }},
                async placeOrder() {{
                    if(!this.name || !this.phone || !this.addr) return alert('Please fill in delivery details.');
                    this.loading = true;
                    try {{
                        const cartItems = Object.keys(this.cart).map(id => ({{ product_uuid: id, quantity: this.cart[id] }}));
                        const res = await fetch(`/v1/store/${{this.businessUuid}}/orders`, {{
                            method: 'POST',
                            headers: {{ 'Content-Type': 'application/json' }},
                            body: JSON.stringify({{ 
                                customer_name: this.name, 
                                customer_phone: this.phone, 
                                notes: this.addr, 
                                payment_method: this.payMethod, 
                                items: cartItems 
                            }})
                        }});
                        if(!res.ok) throw 1;
                        this.orderComplete = await res.json();
                        if(this.payMethod === 'COD') this.finalWA();
                    }} catch(e) {{ alert('Checkout error. Try again.') }}
                    finally {{ this.loading = false }}
                }},
                async uploadProof(e) {{
                    const file = e.target.files[0];
                    if(!file) return;
                    this.uploading = true;
                    try {{
                        const fd = new FormData();
                        fd.append('file', file);
                        const res = await fetch(`/v1/store/${{this.businessUuid}}/orders/${{this.orderComplete.order_number}}/payment-proof`, {{
                            method: 'POST',
                            body: fd
                        }});
                        if(!res.ok) throw 1;
                        this.proofUploaded = true;
                    }} catch(e) {{ alert('Proof upload failed.') }}
                    finally {{ this.uploading = false }}
                }},
                finalWA() {{
                    const itemsTxt = this.cartItems.map(i => ` • ${{i.name}} x${{i.qty}}`).join('\\n');
                    const payStatus = this.payMethod === 'UPI' ? (this.proofUploaded ? '✅ Paid (Proof Sent)' : '⏳ UPI Payment Pending') : '💵 Cash on Delivery';
                    const msg = `🛍️ *Order Confirmed!*\\nOrder No: *${{this.orderComplete.order_number}}*\\nTotal: *₹${{this.orderComplete.total_amount.toLocaleString()}}*\\n\\n*Payment:* ${{payStatus}}\\n\\n*Items:*\\n${{itemsTxt}}\\n\\n*Delivery to:* ${{this.name}}\\n${{this.phone}}\\n${{this.addr}}`;
                    window.location.href = `https://wa.me/{_wa_number(business.phone)}?text=${{encodeURIComponent(msg)}}`;
                }},
                async submitReview() {{
                    if(!this.feedbackRating) return alert('Please select a star rating.');
                    this.loading = true;
                    try {{
                        const res = await fetch(`/v1/store/${{this.businessUuid}}/reviews`, {{
                            method: 'POST',
                            headers: {{ 'Content-Type': 'application/json' }},
                            body: JSON.stringify({{ 
                                customer_name: this.name, 
                                rating: this.feedbackRating, 
                                comment: this.feedbackComment,
                                order_number: this.orderComplete?.order_number
                            }})
                        }});
                        if(!res.ok) throw 1;
                        this.reviewSubmitted = true;
                        // Update UI rating mockly
                        const oldSum = this.avgRating * this.reviewCount;
                        this.reviewCount++;
                        this.avgRating = (oldSum + this.feedbackRating) / this.reviewCount;
                    }} catch(e) {{ alert('Feedback failed.') }}
                    finally {{ this.loading = false }}
                }}
            }}
        }}).mount('#app');
    </script>
</body>
</html>"""
    return HTMLResponse(content=html)
