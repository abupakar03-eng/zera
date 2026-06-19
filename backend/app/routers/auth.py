from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from app.database import get_db
from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
    OTPSendRequest,
    OTPVerifyRequest,
    ResetPasswordRequest,
    RefreshTokenRequest,
    AuthResponse,
    OTPResponse,
    UserResponse,
    TokenResponse
)
from app.services.auth_service import AuthService
from app.core.dependencies import get_current_user
from app.models.user import User
from app.config import settings

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _business_dict(business) -> dict:
    """Serialize business object including store_slug."""
    return {
        "uuid": business.uuid,
        "store_slug": business.store_slug,
        "business_name": business.business_name,
        "plan": business.plan.value,
        "is_active": business.is_active,
        "logo_url": business.logo_url,
        "banner_url": business.banner_url,
        "phone": business.phone,
        "email": business.email,
        "city": getattr(business, 'city', None),
        "state": getattr(business, 'state', None),
        "plan_expiry_date": business.plan_expiry_date.isoformat() if business.plan_expiry_date else None,
        "subscription_type": business.subscription_type,
    }


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(data: RegisterRequest, db: Session = Depends(get_db)):
    auth_service = AuthService(db)
    user, business = auth_service.register_user(data)
    tokens = auth_service.generate_tokens(user, business)
    
    return AuthResponse(
        success=True,
        message="Registration successful",
        data={
            "user": UserResponse.model_validate(user).model_dump(),
            "business": _business_dict(business),
            "tokens": tokens
        }
    )


@router.post("/login", response_model=AuthResponse)
async def login(data: LoginRequest, db: Session = Depends(get_db)):
    auth_service = AuthService(db)
    user, business = auth_service.login_user(data)
    tokens = auth_service.generate_tokens(user, business)

    user.last_login = datetime.now(timezone.utc)
    db.commit()

    return AuthResponse(
        success=True,
        message="Login successful",
        data={
            "user": UserResponse.model_validate(user).model_dump(),
            "business": _business_dict(business) if business else None,
            "tokens": tokens
        }
    )


@router.post("/otp/send", response_model=OTPResponse)
async def send_otp(data: OTPSendRequest, db: Session = Depends(get_db)):
    auth_service = AuthService(db)
    otp_record = auth_service.send_otp(data)
    
    response_data = OTPResponse(
        success=True,
        message=f"OTP sent to {data.phone}",
        expires_in_minutes=settings.OTP_EXPIRY_MINUTES
    )

    # Only include OTP in response during development with mock mode
    if settings.OTP_MOCK and settings.is_development:
        response_data.message = f"OTP: {otp_record.otp_code} (Mock mode)"

    return response_data


@router.post("/otp/verify", response_model=AuthResponse)
async def verify_otp(data: OTPVerifyRequest, db: Session = Depends(get_db)):
    auth_service = AuthService(db)
    
    if data.purpose == "LOGIN":
        user, business = auth_service.login_with_otp(data)
        tokens = auth_service.generate_tokens(user, business)

        # Track last login timestamp
        user.last_login = datetime.now(timezone.utc)
        db.commit()

        return AuthResponse(
            success=True,
            message="OTP verified successfully",
            data={
                "user": UserResponse.model_validate(user).model_dump(),
                "business": _business_dict(business) if business else None,
                "tokens": tokens
            }
        )
    else:
        auth_service.verify_otp(data)
        return AuthResponse(
            success=True,
            message="OTP verified successfully",
            data={}
        )


@router.post("/reset-password", response_model=AuthResponse)
async def reset_password(data: ResetPasswordRequest, db: Session = Depends(get_db)):
    auth_service = AuthService(db)
    auth_service.reset_password(
        phone=data.phone,
        otp_code=data.otp_code,
        new_password=data.new_password,
    )
    return AuthResponse(
        success=True,
        message="Password reset successful. Please login with your new password.",
        data={}
    )


@router.post("/refresh", response_model=AuthResponse)
async def refresh_token(data: RefreshTokenRequest, db: Session = Depends(get_db)):
    auth_service = AuthService(db)
    tokens = auth_service.refresh_access_token(data.refresh_token)
    
    return AuthResponse(
        success=True,
        message="Token refreshed successfully",
        data={"tokens": tokens}
    )


@router.get("/me", response_model=AuthResponse)
async def get_current_user_info(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    from app.models.business import Business
    
    business = None
    if current_user.role.value == "BUSINESS_OWNER":
        business = db.query(Business).filter(
            Business.owner_id == current_user.id,
            Business.deleted_at.is_(None)
        ).first()
    
    return AuthResponse(
        success=True,
        message="User information retrieved",
        data={
            "user": UserResponse.model_validate(current_user).model_dump(),
            "business": _business_dict(business) if business else None
        }
    )


@router.post("/logout", response_model=AuthResponse)
async def logout(current_user: User = Depends(get_current_user)):
    return AuthResponse(
        success=True,
        message="Logged out successfully",
        data={}
    )


@router.post("/google", response_model=AuthResponse)
async def google_auth(payload: dict, db: Session = Depends(get_db)):
    """
    Called after Supabase Google OAuth. Accepts the Supabase access token,
    verifies it, then finds or creates a user in our DB.
    Returns our JWT if user exists, or needs_registration=true for new users.
    """
    import httpx
    supabase_token = payload.get("supabase_token", "")
    if not supabase_token:
        raise HTTPException(status_code=400, detail="supabase_token required")

    # Verify token with Supabase and get user info
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{settings.SUPABASE_URL}/auth/v1/user",
            headers={"Authorization": f"Bearer {supabase_token}",
                     "apikey": settings.SUPABASE_ANON_KEY},
            timeout=10,
        )

    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Invalid Supabase token")

    sb_user = resp.json()
    google_email = (sb_user.get("email", "") or "").lower().strip()
    google_name = sb_user.get("user_metadata", {}).get("full_name") or \
                  sb_user.get("user_metadata", {}).get("name") or ""

    if not google_email:
        raise HTTPException(status_code=400, detail="Google account has no email")

    # Find existing user by email (including soft-deleted — restore them)
    from app.models.business import Business
    user = db.query(User).filter(User.email == google_email).first()

    if user:
        # Restore soft-deleted account if needed
        if user.deleted_at is not None:
            user.deleted_at = None
            user.is_active = True
        business = db.query(Business).filter(Business.owner_id == user.id).first()
        if business and business.deleted_at is not None:
            business.deleted_at = None
            business.is_active = True
        auth_service = AuthService(db)
        tokens = auth_service.generate_tokens(user, business)
        user.last_login = datetime.now(timezone.utc)
        db.commit()
        return AuthResponse(
            success=True,
            message="Login successful",
            data={
                "user": UserResponse.model_validate(user).model_dump(),
                "business": _business_dict(business) if business else None,
                "tokens": tokens,
            }
        )

    # New Google user — send back info so Flutter can show registration form
    return AuthResponse(
        success=True,
        message="needs_registration",
        data={
            "needs_registration": True,
            "google_email": google_email,
            "google_name": google_name,
            "supabase_token": supabase_token,
        }
    )


@router.post("/google/complete", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def google_complete_registration(payload: dict, db: Session = Depends(get_db)):
    """
    Completes registration for new Google sign-in users.
    Requires: supabase_token, phone, business_name, business_phone
    """
    import httpx, re
    from datetime import timedelta, date
    from app.models.business import Business, BusinessPlan
    from app.models.plan_limit import PlanLimit
    from app.core.security import hash_password
    import secrets, string

    supabase_token = payload.get("supabase_token", "")
    phone = re.sub(r"\D", "", payload.get("phone", ""))
    business_name = payload.get("business_name", "").strip()
    business_phone = re.sub(r"\D", "", payload.get("business_phone", phone))

    if not all([supabase_token, phone, business_name]):
        raise HTTPException(status_code=400, detail="phone and business_name required")

    # Re-verify Supabase token
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"{settings.SUPABASE_URL}/auth/v1/user",
            headers={"Authorization": f"Bearer {supabase_token}",
                     "apikey": settings.SUPABASE_ANON_KEY},
            timeout=10,
        )
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Invalid Supabase token")

    sb_user = resp.json()
    google_email = (sb_user.get("email", "") or "").lower().strip()
    google_name = sb_user.get("user_metadata", {}).get("full_name") or \
                  sb_user.get("user_metadata", {}).get("name") or business_name

    # If email already exists (e.g. soft-deleted account), restore and log in
    existing = db.query(User).filter(User.email == google_email).first()
    if existing:
        if existing.deleted_at is not None:
            existing.deleted_at = None
            existing.is_active = True
        biz = db.query(Business).filter(Business.owner_id == existing.id).first()
        if biz and biz.deleted_at is not None:
            biz.deleted_at = None
            biz.is_active = True
        existing.last_login = datetime.now(timezone.utc)
        db.commit()
        db.refresh(existing)
        auth_service = AuthService(db)
        tokens = auth_service.generate_tokens(existing, biz)
        return AuthResponse(
            success=True,
            message="Login successful",
            data={
                "user": UserResponse.model_validate(existing).model_dump(),
                "business": {
                    "uuid": biz.uuid,
                    "business_name": biz.business_name,
                    "plan": biz.plan.value,
                } if biz else None,
                "tokens": tokens,
            }
        )

    # Check phone not taken — link or log in if the account belongs to this Google user
    existing_phone_user = db.query(User).filter(User.phone == phone, User.deleted_at.is_(None)).first()
    if existing_phone_user:
        existing_email = (existing_phone_user.email or "").lower().strip()
        email_matches = existing_email == google_email or existing_email == ""
        if email_matches:
            # No email set (link it) OR email already matches this Google account → log in
            if existing_phone_user.email is None:
                existing_phone_user.email = google_email
            existing_phone_user.last_login = datetime.now(timezone.utc)
            biz = db.query(Business).filter(Business.owner_id == existing_phone_user.id).first()
            if biz and biz.deleted_at is not None:
                biz.deleted_at = None
                biz.is_active = True
            db.commit()
            db.refresh(existing_phone_user)
            auth_service = AuthService(db)
            tokens = auth_service.generate_tokens(existing_phone_user, biz)
            return AuthResponse(
                success=True,
                message="Login successful",
                data={
                    "user": UserResponse.model_validate(existing_phone_user).model_dump(),
                    "business": {
                        "uuid": biz.uuid,
                        "business_name": biz.business_name,
                        "plan": biz.plan.value,
                    } if biz else None,
                    "tokens": tokens,
                }
            )
        else:
            raise HTTPException(status_code=409, detail="This phone number is already registered with a different account. Please log in with your phone number and password instead.")

    # Create user with random password (Google users don't use password login)
    rand_pw = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32))
    user = User(
        phone=phone,
        email=google_email,
        password_hash=hash_password(rand_pw),
        full_name=google_name,
        role="BUSINESS_OWNER",
        is_active=True,
        is_verified=True,
    )
    db.add(user)
    db.flush()

    trial_expiry = date.today() + timedelta(days=30)
    business = Business(
        owner_id=user.id,
        business_name=business_name,
        phone=business_phone or phone,
        email=google_email,
        plan=BusinessPlan.PAID,
        plan_expiry_date=trial_expiry,
        subscription_type="trial",
        is_active=True,
    )
    db.add(business)
    db.flush()

    plan_limit = PlanLimit(
        business_id=business.id,
        max_products=999999, max_orders=999999, max_customers=999999,
        features={"reports_enabled": True, "export_pdf": True, "export_csv": True,
                  "advanced_dashboard": True, "priority_support": True},
    )
    db.add(plan_limit)
    db.commit()
    db.refresh(user)
    db.refresh(business)

    auth_service = AuthService(db)
    tokens = auth_service.generate_tokens(user, business)

    return AuthResponse(
        success=True,
        message="Registration successful",
        data={
            "user": UserResponse.model_validate(user).model_dump(),
            "business": _business_dict(business),
            "tokens": tokens,
        }
    )
