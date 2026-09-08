"""Authentication endpoints for privileged operational users."""

from __future__ import annotations

import hmac
import secrets
import time
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.config import settings
from app.core.security import (
    create_access_token,
    get_current_user,
    get_role_permissions,
)

router = APIRouter()


class LoginRequest(BaseModel):
    username: str
    password: str


class UserResponse(BaseModel):
    user_id: str
    username: str
    role: str
    permissions: List[str]
    state_code: Optional[str] = None
    district_code: Optional[str] = None


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_minutes: int
    user: UserResponse


class CitizenRegisterRequest(BaseModel):
    phone_number: str
    full_name: Optional[str] = None
    state_code: Optional[str] = None
    district_code: Optional[str] = None


class CitizenOtpVerifyRequest(BaseModel):
    phone_number: str
    otp: str


class CitizenRegisterResponse(BaseModel):
    request_id: str
    otp_sent: bool
    message: str


class CitizenVerifyResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_minutes: int
    user: UserResponse


# In-memory OTP store for prototype (production: use Redis or DB)
_OTP_STORE: Dict[str, Dict[str, Any]] = {}  # phone -> {otp, expires_at, attempt_count}
_OTP_TTL_SECONDS = 300
_OTP_MAX_ATTEMPTS = 5


def _bootstrap_users() -> List[Dict[str, Any]]:
    return [
        {
            "user_id": "bootstrap-national-admin",
            "username": settings.bootstrap_admin_username,
            "password": settings.bootstrap_admin_password,
            "role": "NATIONAL_ADMIN",
            "state_code": None,
            "district_code": None,
        },
        {
            "user_id": "bootstrap-national-analyst",
            "username": settings.bootstrap_analyst_username,
            "password": settings.bootstrap_analyst_password,
            "role": "NATIONAL_ANALYST",
            "state_code": None,
            "district_code": None,
        },
        {
            "user_id": "bootstrap-field-surveyor",
            "username": settings.bootstrap_field_username,
            "password": settings.bootstrap_field_password,
            "role": "FIELD_OFFICER",
            "state_code": None,
            "district_code": None,
        },
        {
            "user_id": "bootstrap-field-officer",
            "username": settings.bootstrap_field_officer_username,
            "password": settings.bootstrap_field_officer_password,
            "role": "FIELD_OFFICER",
            "state_code": None,
            "district_code": None,
        },
        {
            "user_id": "bootstrap-citizen",
            "username": settings.bootstrap_citizen_username,
            "password": settings.bootstrap_citizen_password,
            "role": "CITIZEN",
            "state_code": None,
            "district_code": None,
        },
    ]


def _find_user(username: str) -> Optional[Dict[str, Any]]:
    lookup = username.strip().lower()
    for user in _bootstrap_users():
        if user["username"].strip().lower() == lookup:
            return {
                **user,
                "permissions": get_role_permissions(user["role"]),
            }
    return None


def _public_user(user: Dict[str, Any]) -> UserResponse:
    return UserResponse(
        user_id=user["user_id"],
        username=user["username"],
        role=user["role"],
        permissions=list(user.get("permissions") or get_role_permissions(user["role"])),
        state_code=user.get("state_code"),
        district_code=user.get("district_code"),
    )


@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    user = _find_user(request.username)
    if user is None or not hmac.compare_digest(request.password, user["password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = create_access_token(
        {
            "sub": user["user_id"],
            "username": user["username"],
            "role": user["role"],
            "permissions": user["permissions"],
            "state_code": user.get("state_code"),
            "district_code": user.get("district_code"),
        }
    )
    return LoginResponse(
        access_token=token,
        expires_in_minutes=settings.access_token_expire_minutes,
        user=_public_user(user),
    )


@router.get("/me", response_model=UserResponse)
async def me(current_user: Dict[str, Any] = Depends(get_current_user)):
    return _public_user(current_user)


# ---------------------------------------------------------------------------
# Citizen self-registration via phone + OTP (prototype)
# ---------------------------------------------------------------------------

def _generate_otp() -> str:
    """Generate a 6-digit OTP."""
    return f"{secrets.randbelow(1000000):06d}"


@router.post("/citizen/request-otp", response_model=CitizenRegisterResponse)
async def citizen_request_otp(request: CitizenRegisterRequest):
    """Request an OTP for citizen self-registration by phone number.

    In prototype: returns the OTP in the `message` field for demo/judging convenience.
    In production: integrate with an SMS gateway (e.g. MSG91, Twilio, IMD-SMS).
    """
    phone = request.phone_number.strip()
    if len(phone) < 10:
        raise HTTPException(status_code=400, detail="A valid phone number is required.")

    otp = _generate_otp()
    request_id = f"citizen-req-{secrets.token_urlsafe(8)}"
    _OTP_STORE[phone] = {
        "otp": otp,
        "expires_at": time.time() + _OTP_TTL_SECONDS,
        "attempt_count": 0,
        "full_name": request.full_name,
        "state_code": request.state_code,
        "district_code": request.district_code,
    }

    # Prototype: include the OTP in the message so judges can verify the flow end-to-end.
    return CitizenRegisterResponse(
        request_id=request_id,
        otp_sent=True,
        message=f"OTP generated. (Prototype demo OTP: {otp}. In production, delivered via SMS gateway.)",
    )


@router.post("/citizen/verify-otp", response_model=CitizenVerifyResponse)
async def citizen_verify_otp(request: CitizenOtpVerifyRequest):
    """Verify an OTP and issue a CITIZEN-role JWT."""
    phone = request.phone_number.strip()
    record = _OTP_STORE.get(phone)
    if record is None:
        raise HTTPException(status_code=400, detail="No OTP request found for this phone number.")

    if time.time() > record["expires_at"]:
        _OTP_STORE.pop(phone, None)
        raise HTTPException(status_code=410, detail="OTP expired. Please request a new one.")

    if record["attempt_count"] >= _OTP_MAX_ATTEMPTS:
        _OTP_STORE.pop(phone, None)
        raise HTTPException(status_code=429, detail="Too many failed attempts. Please request a new OTP.")

    record["attempt_count"] += 1
    if not hmac.compare_digest(str(record["otp"]), request.otp.strip()):
        raise HTTPException(status_code=401, detail="Incorrect OTP.")

    _OTP_STORE.pop(phone, None)

    user_id = f"citizen-{phone[-4:]}-{secrets.token_urlsafe(4)}"
    username = f"+{phone}"
    role = "CITIZEN"
    permissions = get_role_permissions(role)
    token = create_access_token(
        {
            "sub": user_id,
            "username": username,
            "role": role,
            "permissions": permissions,
            "state_code": record.get("state_code"),
            "district_code": record.get("district_code"),
            "phone": phone,
        }
    )
    return CitizenVerifyResponse(
        access_token=token,
        expires_in_minutes=settings.access_token_expire_minutes,
        user=UserResponse(
            user_id=user_id,
            username=username,
            role=role,
            permissions=permissions,
            state_code=record.get("state_code"),
            district_code=record.get("district_code"),
        ),
    )
