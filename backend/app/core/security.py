"""
Security and authentication utilities
"""

from datetime import datetime, timedelta
from typing import Any, Dict, Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

ROLE_PERMISSIONS = {
    "ADMIN": [
        "READ",
        "ANALYZE",
        "EXPORT",
        "SYNC",
        "APPROVE",
        "MANAGE_CONFIG",
        "TRIGGER_INGESTION",
    ],
    "NATIONAL_ADMIN": [
        "READ",
        "ANALYZE",
        "EXPORT",
        "SYNC",
        "APPROVE",
        "MANAGE_CONFIG",
        "TRIGGER_INGESTION",
    ],
    "NATIONAL_ANALYST": ["READ", "ANALYZE", "EXPORT", "SYNC"],
    "STATE_SDMA_ADMIN": ["READ", "ANALYZE", "EXPORT", "SYNC", "APPROVE"],
    "STATE_ANALYST": ["READ", "ANALYZE", "EXPORT", "SYNC"],
    "DISTRICT_MAGISTRATE": ["READ", "ANALYZE", "EXPORT", "SYNC", "APPROVE"],
    "DISTRICT_OPERATIONS_OFFICER": ["READ", "ANALYZE", "SYNC", "WRITE_FIELD_DATA"],
    # Renamed / unified field role
    "FIELD_OFFICER": ["READ", "WRITE_FIELD_DATA", "SYNC", "ANALYZE", "RELAY_SOS"],
    # Back-compat alias
    "FIELD_SURVEYOR": ["READ", "WRITE_FIELD_DATA", "SYNC", "ANALYZE", "RELAY_SOS"],
    "ANALYST": ["READ", "ANALYZE", "EXPORT"],
    # Public citizen role — can submit SOS, view public layers, post crowd reports
    "CITIZEN": ["READ_PUBLIC", "SOS_SEND", "CROWD_REPORT", "ALERT_RECEIVE", "RELAY_SOS"],
    "VIEWER": ["READ"],
}

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT token settings
security = HTTPBearer()
optional_security = HTTPBearer(auto_error=False)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password"""
    return pwd_context.hash(password)


def create_access_token(
    data: Dict[str, Any], expires_delta: Optional[timedelta] = None
) -> str:
    """Create a JWT access token"""
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(
            minutes=settings.access_token_expire_minutes
        )

    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode, settings.secret_key, algorithm=settings.algorithm
    )

    return encoded_jwt


def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    """Decode and verify a JWT access token"""
    try:
        payload = jwt.decode(
            token, settings.secret_key, algorithms=[settings.algorithm]
        )
        return payload
    except JWTError:
        return None


def get_role_permissions(role: Optional[str]) -> list[str]:
    return list(ROLE_PERMISSIONS.get((role or "").upper(), ["READ"]))


def _user_from_credentials(
    credentials: Optional[HTTPAuthorizationCredentials],
) -> Optional[Dict[str, Any]]:
    if credentials is None:
        return None
    token = credentials.credentials
    payload = decode_access_token(token)
    if payload is None:
        return None
    user_id: str = payload.get("sub")
    if user_id is None:
        return None
    role = payload.get("role")
    return {
        "user_id": user_id,
        "username": payload.get("username"),
        "role": role,
        "permissions": payload.get("permissions") or get_role_permissions(role),
        "state_code": payload.get("state_code"),
        "district_code": payload.get("district_code"),
        "exp": payload.get("exp"),
    }


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> Dict[str, Any]:
    """Get the current user from JWT token"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    user = _user_from_credentials(credentials)
    if user is None:
        raise credentials_exception
    return user


def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(optional_security),
) -> Optional[Dict[str, Any]]:
    """Best-effort identity for prototype routes that must work without login."""
    return _user_from_credentials(credentials)


def check_role(required_role: str):
    """Dependency to check if user has required role"""

    def role_checker(
        current_user: Dict[str, Any] = Depends(get_current_user),
    ) -> Dict[str, Any]:
        user_role = current_user.get("role")

        # Admin has access to everything
        if user_role == "ADMIN":
            return current_user

        # Check if user has required role
        if user_role != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"User role '{user_role}' does not have required role '{required_role}'",
            )

        return current_user

    return role_checker


def check_permission(permission: str):
    """Dependency to check if user has specific permission"""

    def permission_checker(
        current_user: Dict[str, Any] = Depends(get_current_user),
    ) -> Dict[str, Any]:
        user_role = current_user.get("role")

        # Admin roles have all permissions
        if user_role in {"ADMIN", "NATIONAL_ADMIN"}:
            return current_user

        user_permissions = get_role_permissions(user_role)

        # READ implies READ_PUBLIC for citizen-facing endpoints
        effective = set(user_permissions)
        if "READ" in effective:
            effective.add("READ_PUBLIC")
        if "READ_PUBLIC" in effective and permission == "READ":
            return current_user

        if permission not in effective:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"User role '{user_role}' does not have permission '{permission}'",
            )

        return current_user

    return permission_checker


def create_api_key(user_id: str) -> str:
    """Generate an API key for a user"""
    import secrets

    api_key = f"dm_{secrets.token_urlsafe(32)}"
    return api_key


def hash_api_key(api_key: str) -> str:
    """Hash an API key for storage"""
    return pwd_context.hash(api_key)


def verify_api_key(api_key: str, hashed_key: str) -> bool:
    """Verify an API key against its hash"""
    return pwd_context.verify(api_key, hashed_key)
