"""Authentication endpoints for privileged operational users."""

from __future__ import annotations

import hmac
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
            "role": "FIELD_SURVEYOR",
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
