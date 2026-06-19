from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Tuple
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.user import User, UserRole
from app.models.business import Business, BusinessPlan
from app.utils.slug import generate_slug, unique_slug
from app.models.otp import OTPVerification, OTPPurpose
from app.models.plan_limit import PlanLimit
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    generate_otp,
    verify_otp,
)
from app.schemas.auth import RegisterRequest, LoginRequest, OTPSendRequest, OTPVerifyRequest
from app.config import settings


class AuthService:
    def __init__(self, db: Session):
        self.db = db
    
    def register_user(self, data: RegisterRequest) -> Tuple[User, Business]:
        existing_user = self.db.query(User).filter(
            User.phone == data.phone,
            User.deleted_at.is_(None)
        ).first()
        
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Phone number already registered"
            )
        
        if data.email:
            existing_email = self.db.query(User).filter(
                User.email == data.email,
                User.deleted_at.is_(None)
            ).first()
            
            if existing_email:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email already registered"
                )
        
        user = User(
            phone=data.phone,
            email=data.email,
            password_hash=hash_password(data.password),
            full_name=data.full_name,
            role=UserRole.BUSINESS_OWNER,
            is_active=True,
            is_verified=False
        )
        
        self.db.add(user)
        self.db.flush()
        
        # 30-day free trial for all new accounts
        from datetime import date
        trial_expiry = date.today() + timedelta(days=30)

        slug = unique_slug(generate_slug(data.business_name), self.db)

        business = Business(
            owner_id=user.id,
            business_name=data.business_name,
            store_slug=slug,
            phone=data.business_phone,
            email=data.business_email,
            plan=BusinessPlan.PAID,
            plan_expiry_date=trial_expiry,
            subscription_type="trial",
            is_active=True
        )

        self.db.add(business)
        self.db.flush()

        # Full PRO features during trial
        plan_limit = PlanLimit(
            business_id=business.id,
            max_products=999999,
            max_orders=999999,
            max_customers=999999,
            features={
                "reports_enabled": True,
                "export_pdf": True,
                "export_csv": True,
                "advanced_dashboard": True,
                "priority_support": True
            }
        )
        
        self.db.add(plan_limit)

        # Link referral if a valid code was provided
        if data.referral_code:
            from app.models.affiliate import Affiliate, Referral
            aff = self.db.query(Affiliate).filter(
                Affiliate.referral_code == data.referral_code.strip().upper(),
                Affiliate.is_active == True,
            ).first()
            if aff:
                referral = Referral(
                    affiliate_id=aff.id,
                    referred_business_id=business.id,
                )
                aff.total_referrals += 1
                self.db.add(referral)

        self.db.commit()
        self.db.refresh(user)
        self.db.refresh(business)

        return user, business
    
    def login_user(self, data: LoginRequest) -> Tuple[User, Optional[Business]]:
        user = self.db.query(User).filter(
            User.phone == data.phone,
            User.deleted_at.is_(None)
        ).first()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid phone number or password"
            )
        
        # Check if account is locked
        if user.locked_until and user.locked_until > datetime.now(timezone.utc):
            remaining_minutes = int((user.locked_until - datetime.now(timezone.utc)).total_seconds() / 60)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Account is temporarily locked due to too many failed attempts. Try again in {remaining_minutes} minutes."
            )
        
        if not verify_password(data.password, user.password_hash):
            user.failed_login_attempts += 1
            if user.failed_login_attempts >= 5:
                user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=15)
                user.failed_login_attempts = 0 # Reset count after locking
                self.db.commit()
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Too many failed attempts. Account locked for 15 minutes."
                )
            self.db.commit()
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid phone number or password. {5 - user.failed_login_attempts} attempts remaining."
            )
        
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is deactivated"
            )
        
        # Reset failed attempts on successful login
        user.failed_login_attempts = 0
        user.locked_until = None
        self.db.commit()
        
        business = None
        if user.role == UserRole.BUSINESS_OWNER:
            business = self.db.query(Business).filter(
                Business.owner_id == user.id,
                Business.deleted_at.is_(None)
            ).first()
            # Auto-revert expired trials to FREE
            if business and business.plan == BusinessPlan.PAID and business.subscription_type == "trial":
                from datetime import date
                if business.plan_expiry_date and business.plan_expiry_date < date.today():
                    business.plan = BusinessPlan.FREE
                    business.subscription_type = None
                    self.db.commit()
                    # Downgrade plan limits
                    from app.services.plan_limit_service import PlanLimitService
                    PlanLimitService.update_plan_limits(self.db, business.id, BusinessPlan.FREE)

        return user, business

    def send_otp(self, data: OTPSendRequest) -> OTPVerification:
        self.db.query(OTPVerification).filter(
            OTPVerification.phone == data.phone,
            OTPVerification.purpose == data.purpose,
            OTPVerification.is_verified == False
        ).delete()
        self.db.commit()
        
        if data.purpose == "REGISTRATION":
            existing_user = self.db.query(User).filter(
                User.phone == data.phone,
                User.deleted_at.is_(None)
            ).first()
            
            if existing_user:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Phone number already registered"
                )
        
        otp_code = generate_otp()
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
        
        otp_record = OTPVerification(
            phone=data.phone,
            otp_code=otp_code,
            purpose=OTPPurpose(data.purpose),
            is_verified=False,
            expires_at=expires_at
        )
        
        self.db.add(otp_record)
        self.db.commit()
        self.db.refresh(otp_record)
        
        return otp_record
    
    def verify_otp(self, data: OTPVerifyRequest) -> bool:
        otp_record = self.db.query(OTPVerification).filter(
            OTPVerification.phone == data.phone,
            OTPVerification.purpose == data.purpose,
            OTPVerification.is_verified == False
        ).order_by(OTPVerification.created_at.desc()).first()
        
        if not otp_record:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No active OTP found for this phone number"
            )
        
        if datetime.now(timezone.utc) > otp_record.expires_at:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="OTP has expired"
            )
        
        if otp_record.failed_attempts >= 5:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Too many failed attempts. Please request a new OTP."
            )
        
        if not verify_otp(data.otp_code, otp_record.otp_code):
            otp_record.failed_attempts += 1
            self.db.commit()
            
            remaining = 5 - otp_record.failed_attempts
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid OTP code. {remaining} attempts remaining."
            )
        
        otp_record.is_verified = True
        self.db.commit()
        
        return True
    
    def login_with_otp(self, data: OTPVerifyRequest) -> Tuple[User, Optional[Business]]:
        self.verify_otp(data)
        
        user = self.db.query(User).filter(
            User.phone == data.phone,
            User.deleted_at.is_(None)
        ).first()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found. Please register first."
            )
        
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is deactivated"
            )
        
        user.is_verified = True
        self.db.commit()
        
        business = None
        if user.role == UserRole.BUSINESS_OWNER:
            business = self.db.query(Business).filter(
                Business.owner_id == user.id,
                Business.deleted_at.is_(None)
            ).first()
            # Auto-revert expired trials to FREE
            if business and business.plan == BusinessPlan.PAID and business.subscription_type == "trial":
                from datetime import date
                if business.plan_expiry_date and business.plan_expiry_date < date.today():
                    business.plan = BusinessPlan.FREE
                    business.subscription_type = None
                    self.db.commit()
                    # Downgrade plan limits
                    from app.services.plan_limit_service import PlanLimitService
                    PlanLimitService.update_plan_limits(self.db, business.id, BusinessPlan.FREE)

        return user, business

    def generate_tokens(self, user: User, business: Optional[Business] = None) -> Dict[str, str]:
        token_data = {
            "sub": user.uuid,
            "user_id": user.id,
            "role": user.role.value,
            "business_id": business.id if business else None
        }
        
        access_token = create_access_token(token_data)
        refresh_token = create_refresh_token({"sub": user.uuid, "user_id": user.id})
        
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        }
    
    def refresh_access_token(self, refresh_token: str) -> Dict[str, str]:
        payload = decode_token(refresh_token)
        
        if not payload or payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token"
            )
        
        user_id = payload.get("user_id")
        user = self.db.query(User).filter(
            User.id == user_id,
            User.deleted_at.is_(None)
        ).first()
        
        if not user or not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found or inactive"
            )
        
        business = None
        if user.role == UserRole.BUSINESS_OWNER:
            business = self.db.query(Business).filter(
                Business.owner_id == user.id,
                Business.deleted_at.is_(None)
            ).first()
        
        return self.generate_tokens(user, business)

    def reset_password(self, phone: str, otp_code: str, new_password: str) -> bool:
        from app.schemas.auth import OTPVerifyRequest
        # Verify the OTP first
        otp_data = OTPVerifyRequest(phone=phone, otp_code=otp_code, purpose="PASSWORD_RESET")
        self.verify_otp(otp_data)

        # Find user
        user = self.db.query(User).filter(
            User.phone == phone,
            User.deleted_at.is_(None)
        ).first()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found with this phone number"
            )

        # Update password
        user.password_hash = hash_password(new_password)
        # Reset lockout if any
        user.failed_login_attempts = 0
        user.locked_until = None
        self.db.commit()
        return True
