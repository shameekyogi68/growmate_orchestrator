import bcrypt
import jwt
import hashlib
from datetime import datetime, timedelta, timezone
from fastapi import Header, HTTPException
from app.utils.config import get_settings


def hash_password(password: str) -> str:
    """Hashes a password with bcrypt (UTF-8)."""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode("utf-8"), salt)
    return hashed.decode("utf-8")


def verify_password(password: str, stored_hash: str | None) -> bool:
    """Verifies a password against a stored bcrypt hash or legacy SHA256 hash."""
    if not stored_hash:
        return False

    if ":" in stored_hash:
        try:
            salt, hashed = stored_hash.split(":")
            return hashlib.sha256(f"{salt}{password}".encode()).hexdigest() == hashed
        except ValueError:
            return False

    try:
        return bcrypt.checkpw(password.encode("utf-8"), stored_hash.encode("utf-8"))
    except Exception:
        return False


def create_access_token(
    user_id: str,
    phone_number: str,
    active_crop: str | None = None,
    active_sowing_date: str | None = None,
) -> str:
    """Creates a signed JWT access token."""
    settings = get_settings()
    payload = {
        "sub": user_id,
        "phone_number": phone_number,
        "active_crop": active_crop,
        "active_sowing_date": (
            active_sowing_date.isoformat()
            if hasattr(active_sowing_date, "isoformat")
            else active_sowing_date
        ),
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc)
        + timedelta(minutes=settings.jwt_expiry_minutes),
    }
    return jwt.encode(
        payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm
    )


def decode_access_token(token: str) -> dict:
    """Decodes and validates a JWT. Raises HTTPException on failure."""
    settings = get_settings()
    try:
        payload = jwt.decode(
            token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


def verify_token(authorization: str = Header(None)) -> dict:
    """FastAPI dependency that validates the Authorization header and returns the token payload."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid or missing token")

    token = authorization.split(" ", 1)[1]
    return decode_access_token(token)
