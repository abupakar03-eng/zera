from typing import Callable
from fastapi import Request, HTTPException, status
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response
from app.core.security import decode_token


_ADMIN_DASHBOARD_CSP = (
    "default-src 'self'; "
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://unpkg.com https://cdn.jsdelivr.net; "
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
    "font-src 'self' https://fonts.gstatic.com; "
    "connect-src 'self' https://unpkg.com https://cdn.jsdelivr.net https://fonts.googleapis.com https://fonts.gstatic.com; "
    "img-src 'self' data: https:; "
    "frame-ancestors 'none'; "
    "object-src 'none';"
)

_DEFAULT_CSP = "default-src 'self'; frame-ancestors 'none'; object-src 'none';"


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        if request.url.path == "/admin-dashboard":
            response.headers["Content-Security-Policy"] = _ADMIN_DASHBOARD_CSP
        else:
            response.headers["Content-Security-Policy"] = _DEFAULT_CSP
        return response


class MultiTenantMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        public_paths = [
            "/",
            "/health",
            "/docs",
            "/redoc",
            "/openapi.json",
            "/v1/auth/register",
            "/v1/auth/login",
            "/v1/auth/otp/send",
            "/v1/auth/otp/verify",
            "/v1/auth/refresh"
        ]
        
        if request.url.path in public_paths or request.url.path.startswith("/docs") or request.url.path.startswith("/openapi") or request.url.path.startswith("/uploads"):
            return await call_next(request)
        
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.replace("Bearer ", "")
            payload = decode_token(token)
            
            if payload:
                request.state.user_id = payload.get("user_id")
                request.state.business_id = payload.get("business_id")
                request.state.role = payload.get("role")
            else:
                request.state.user_id = None
                request.state.business_id = None
                request.state.role = None
        else:
            request.state.user_id = None
            request.state.business_id = None
            request.state.role = None
        
        response = await call_next(request)
        return response


def get_business_id_from_request(request: Request) -> int:
    if not hasattr(request.state, "business_id") or request.state.business_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Business ID not found in token. This endpoint requires business owner authentication."
        )
    return request.state.business_id


def ensure_business_isolation(query, business_id: int, model):
    return query.filter(model.business_id == business_id, model.deleted_at.is_(None))
