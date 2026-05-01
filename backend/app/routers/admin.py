from fastapi import APIRouter, Depends, Query, HTTPException, status, Header
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session
from typing import Optional

from app.database import get_db
from app.models.user import User
from app.core.rbac import require_super_admin
from app.config import settings
from app.schemas.admin import (
    AdminBusinessListResponse,
    AdminBusinessDetailResponse,
    AdminUserListResponse,
    AdminStatsResponse,
    AdminStatusUpdateResponse,
    UpdateBusinessStatusRequest,
    UpdateBusinessPlanRequest,
    UpdateUserStatusRequest,
    UpdateAdminKeyRequest
)
from app.services.admin_service import AdminService

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.get("/businesses", response_model=AdminBusinessListResponse)
async def list_all_businesses(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    search: Optional[str] = Query(None, description="Search by business name, phone, or owner name"),
    plan: Optional[str] = Query(None, description="Filter by plan (FREE or PAID)"),
    is_active: Optional[bool] = Query(None, description="Filter by active status"),
    current_user: User = Depends(require_super_admin),
    db: Session = Depends(get_db)
):
    admin_service = AdminService(db)
    businesses, pagination = admin_service.get_all_businesses(
        page=page,
        page_size=page_size,
        search=search,
        plan=plan,
        is_active=is_active
    )
    
    return AdminBusinessListResponse(
        success=True,
        message="Businesses retrieved successfully",
        data={
            "items": [business.model_dump() for business in businesses],
            "pagination": pagination
        }
    )


@router.get("/businesses/{uuid}", response_model=AdminBusinessDetailResponse)
async def get_business_detail(
    uuid: str,
    current_user: User = Depends(require_super_admin),
    db: Session = Depends(get_db)
):
    admin_service = AdminService(db)
    business_detail = admin_service.get_business_detail(uuid)
    
    return AdminBusinessDetailResponse(
        success=True,
        message="Business details retrieved successfully",
        data=business_detail
    )


@router.patch("/businesses/{uuid}/status", response_model=AdminStatusUpdateResponse)
async def update_business_status(
    uuid: str,
    data: UpdateBusinessStatusRequest,
    current_user: User = Depends(require_super_admin),
    db: Session = Depends(get_db)
):
    admin_service = AdminService(db)
    admin_service.update_business_status(uuid, data)
    
    status_text = "activated" if data.is_active else "deactivated"
    return AdminStatusUpdateResponse(
        success=True,
        message=f"Business {status_text} successfully"
    )


@router.patch("/businesses/{uuid}/plan", response_model=AdminStatusUpdateResponse)
async def update_business_plan(
    uuid: str,
    data: UpdateBusinessPlanRequest,
    current_user: User = Depends(require_super_admin),
    db: Session = Depends(get_db)
):
    admin_service = AdminService(db)
    admin_service.update_business_plan(uuid, data)
    
    return AdminStatusUpdateResponse(
        success=True,
        message=f"Business plan updated to {data.plan.value} successfully"
    )


@router.get("/users", response_model=AdminUserListResponse)
async def list_all_users(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    search: Optional[str] = Query(None, description="Search by name, phone, or email"),
    role: Optional[str] = Query(None, description="Filter by role (SUPER_ADMIN or BUSINESS_OWNER)"),
    is_active: Optional[bool] = Query(None, description="Filter by active status"),
    current_user: User = Depends(require_super_admin),
    db: Session = Depends(get_db)
):
    admin_service = AdminService(db)
    users, pagination = admin_service.get_all_users(
        page=page,
        page_size=page_size,
        search=search,
        role=role,
        is_active=is_active
    )
    
    return AdminUserListResponse(
        success=True,
        message="Users retrieved successfully",
        data={
            "items": [user.model_dump() for user in users],
            "pagination": pagination
        }
    )


@router.patch("/users/{uuid}/status", response_model=AdminStatusUpdateResponse)
async def update_user_status(
    uuid: str,
    data: UpdateUserStatusRequest,
    current_user: User = Depends(require_super_admin),
    db: Session = Depends(get_db)
):
    admin_service = AdminService(db)
    admin_service.update_user_status(uuid, data)
    
    status_text = "activated" if data.is_active else "deactivated"
    return AdminStatusUpdateResponse(
        success=True,
        message=f"User {status_text} successfully"
    )


@router.get("/stats", response_model=AdminStatsResponse)
async def get_platform_statistics(
    current_user: User = Depends(require_super_admin),
    db: Session = Depends(get_db)
):
    admin_service = AdminService(db)
    stats = admin_service.get_platform_statistics()

    return AdminStatsResponse(
        success=True,
        message="Platform statistics retrieved successfully",
        data=stats
    )


@router.get("/dashboard-data")
async def get_dashboard_data(
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    plan_filter: Optional[str] = Query(None, alias="plan"),
    is_active: Optional[bool] = Query(None),
    db: Session = Depends(get_db)
):
    """API-key-protected endpoint for the standalone admin HTML dashboard."""
    if not x_admin_key or x_admin_key != settings.ADMIN_DASHBOARD_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing admin key")

    admin_service = AdminService(db)
    stats = admin_service.get_platform_statistics()
    businesses, pagination = admin_service.get_all_businesses(
        page=page,
        page_size=page_size,
        search=search,
        plan=plan_filter,
        is_active=is_active,
    )
    recent_users, _ = admin_service.get_all_users(page=1, page_size=10)

    return JSONResponse(jsonable_encoder({
        "stats": stats.model_dump(),
        "businesses": [b.model_dump() for b in businesses],
        "pagination": pagination,
        "recent_users": [u.model_dump() for u in recent_users],
    }))


@router.get("/dashboard-users")
async def get_dashboard_users(
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    role: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    db: Session = Depends(get_db)
):
    """Admin-key-protected paginated user listing."""
    if not x_admin_key or x_admin_key != settings.ADMIN_DASHBOARD_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing admin key")

    admin_service = AdminService(db)
    users, pagination = admin_service.get_all_users(
        page=page,
        page_size=page_size,
        search=search,
        role=role,
        is_active=is_active,
    )
    return JSONResponse(jsonable_encoder({
        "users": [u.model_dump() for u in users],
        "pagination": pagination,
    }))


@router.patch("/dashboard-businesses/{uuid}/status")
async def dashboard_update_business_status(
    uuid: str,
    body: UpdateBusinessStatusRequest,
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    db: Session = Depends(get_db)
):
    """Admin-key-protected business activate / deactivate."""
    if not x_admin_key or x_admin_key != settings.ADMIN_DASHBOARD_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing admin key")

    admin_service = AdminService(db)
    admin_service.update_business_status(uuid, body)
    status_text = "activated" if body.is_active else "deactivated"
    return {"success": True, "message": f"Business {status_text}"}


@router.patch("/dashboard-businesses/{uuid}/plan")
async def dashboard_update_business_plan(
    uuid: str,
    body: UpdateBusinessPlanRequest,
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    db: Session = Depends(get_db)
):
    """Admin-key-protected business plan update (plan + expiry + subscription_type)."""
    if not x_admin_key or x_admin_key != settings.ADMIN_DASHBOARD_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing admin key")

    admin_service = AdminService(db)
    admin_service.update_business_plan(uuid, body)
    return {"success": True, "message": f"Plan updated to {body.plan.value}"}


@router.patch("/dashboard-users/{uuid}/status")
async def dashboard_update_user_status(
    uuid: str,
    body: UpdateUserStatusRequest,
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    db: Session = Depends(get_db)
):
    """Admin-key-protected user activate / deactivate."""
    if not x_admin_key or x_admin_key != settings.ADMIN_DASHBOARD_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing admin key")

    admin_service = AdminService(db)
    admin_service.update_user_status(uuid, body)
    status_text = "activated" if body.is_active else "deactivated"
    return {"success": True, "message": f"User {status_text}"}


@router.delete("/dashboard-businesses/{uuid}")
async def dashboard_hard_delete_business(
    uuid: str,
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
    db: Session = Depends(get_db)
):
    """Admin-key-protected hard-delete of a business and its owner user."""
    if not x_admin_key or x_admin_key != settings.ADMIN_DASHBOARD_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing admin key")

    admin_service = AdminService(db)
    result = admin_service.hard_delete_business(uuid)
    msg = f'"{result["business_name"]}" permanently deleted'
    if result["user_deleted"]:
        msg += " (owner account also removed)"
    return {"success": True, "message": msg}


_ADMIN_KEY_FILE = "/var/log/storelink/admin_key.txt"


@router.patch("/dashboard-settings/admin-key")
async def update_admin_key(
    body: UpdateAdminKeyRequest,
    x_admin_key: Optional[str] = Header(None, alias="X-Admin-Key"),
):
    """Change the admin dashboard key. Persists across container restarts."""
    if not x_admin_key or x_admin_key != settings.ADMIN_DASHBOARD_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing admin key")

    new_key = body.new_key.strip()

    try:
        import os
        os.makedirs(os.path.dirname(_ADMIN_KEY_FILE), exist_ok=True)
        with open(_ADMIN_KEY_FILE, "w") as f:
            f.write(new_key)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to persist key: {e}")

    object.__setattr__(settings, "ADMIN_DASHBOARD_KEY", new_key)
    return {"success": True, "message": "Admin key updated successfully"}
