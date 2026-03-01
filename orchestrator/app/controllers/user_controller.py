from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from app.utils.auth import create_access_token, hash_password, verify_password, verify_token
from app.utils.database import fetch_one, execute, fetch_all, get_pool
from app.utils.logger import logger

router = APIRouter(prefix="/user", tags=["User"])


class ProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    language: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class RegisterRequest(BaseModel):
    phone_number: str
    password: Optional[str] = None
    full_name: Optional[str] = None
    language: str = "en"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    active_crop: Optional[str] = None
    active_sowing_date: Optional[str] = None
    quick_pin: Optional[str] = None


class LoginRequest(BaseModel):
    phone_number: str
    password: str


class CropRequest(BaseModel):
    crop_name: str
    variety: Optional[str] = None
    sowing_date: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    is_primary: bool = False


class PinLoginRequest(BaseModel):
    phone_number: str
    pin: str



@router.post("/register")
async def register(req: RegisterRequest):
    """Registers a new user and returns a signed JWT."""
    from app.utils.database import get_pool

    pool = get_pool()

    # Case A: Database is active
    if pool:
        try:
            existing = await fetch_one(
                "SELECT id FROM users WHERE phone_number = $1", req.phone_number
            )
            if existing:
                raise HTTPException(
                    status_code=409, detail="Phone number already registered"
                )

            if req.password:
                pw_hash = hash_password(req.password)
            else:
                pw_hash = None
            
            row = await fetch_one(
                """INSERT INTO users (phone_number, password_hash, full_name, language, latitude, longitude, active_crop, active_sowing_date, quick_pin)
                   VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id""",
                req.phone_number,
                pw_hash,
                req.full_name,
                req.language,
                req.latitude,
                req.longitude,
                req.active_crop,
                req.active_sowing_date,
                req.quick_pin,
            )

            if row:
                user_id = row["id"]
                user_id_str = str(user_id)
                
                # SEEDING: If active_crop is provided, insert it into user_crops table
                if req.active_crop:
                    from datetime import date
                    sowing_date = req.active_sowing_date if req.active_sowing_date else date.today()
                    await execute(
                        """INSERT INTO user_crops (user_id, crop_name, sowing_date, latitude, longitude, is_primary)
                           VALUES ($1, $2, $3, $4, $5, TRUE)""",
                        user_id,
                        req.active_crop,
                        sowing_date,
                        req.latitude,
                        req.longitude
                    )

                token = create_access_token(
                    user_id_str, req.phone_number, req.active_crop, req.active_sowing_date
                )
                logger.info(f"User registered: {req.phone_number} (id={user_id_str})")
                return {
                    "status": "registered",
                    "user_id": user_id_str,
                    "token": token,
                    "profile": {
                        "full_name": req.full_name, 
                        "language": req.language,
                        "latitude": req.latitude,
                        "longitude": req.longitude,
                        "active_crop": req.active_crop,
                        "active_sowing_date": str(req.active_sowing_date) if req.active_sowing_date else None
                    },
                }
        except Exception as e:
            logger.error(f"Registration failed: {e}")
            if isinstance(e, HTTPException):
                raise e
            raise HTTPException(status_code=500, detail="Registration failed internally")

    # Case B: DB-less mode (Database URL not set) - allow simulation
    token = create_access_token("local-user", req.phone_number)
    logger.info(f"User registered (DB-less mode fallback): {req.phone_number}")
    return {
        "status": "registered (DB-less)",
        "user_id": "local-user",
        "token": token,
        "profile": {
            "full_name": req.full_name, 
            "language": req.language,
            "latitude": req.latitude,
            "longitude": req.longitude,
            "active_crop": req.active_crop,
            "active_sowing_date": str(req.active_sowing_date) if req.active_sowing_date else None
        },
    }


@router.post("/login")
async def login(req: LoginRequest):
    """Authenticates a user and returns a signed JWT."""
    from app.utils.database import get_pool

    pool = get_pool()

    # Case A: Database is active - enforce strict lookup
    if pool:
        try:
            user = await fetch_one(
                "SELECT id, phone_number, password_hash, full_name, language, latitude, longitude, active_crop, active_sowing_date FROM users WHERE phone_number = $1",
                req.phone_number,
            )
            if not user:
                raise HTTPException(
                    status_code=404, detail="User not found. Please register first."
                )

            if not verify_password(req.password, user["password_hash"]):
                raise HTTPException(status_code=401, detail="Invalid credentials")

            token = create_access_token(
                str(user["id"]),
                user["phone_number"],
                user["active_crop"],
                user["active_sowing_date"],
            )
            logger.info(f"User logged in: {user['phone_number']}")
            return {
                "status": "authenticated",
                "user_id": str(user["id"]),
                "token": token,
                "profile": {
                    "full_name": user["full_name"],
                    "language": user["language"],
                    "latitude": user["latitude"],
                    "longitude": user["longitude"],
                    "active_crop": user["active_crop"],
                    "active_sowing_date": (
                        user["active_sowing_date"].isoformat()
                        if user["active_sowing_date"]
                        else None
                    ),
                },
            }
        except Exception as e:
            logger.error(f"Login failed: {e}")
            if isinstance(e, HTTPException):
                raise e
            raise HTTPException(status_code=500, detail="Login failed internally")

    # Case B: DB-less mode (Database URL not set) - allow simulation
    token = create_access_token("local-user", req.phone_number)
    logger.info(f"User logged in (DB-less mode fallback): {req.phone_number}")
    return {
        "status": "authenticated (DB-less)",
        "user_id": "local-user",
        "token": token,
        "profile": {
            "full_name": "Mock User",
            "language": "en",
            "latitude": 13.8,
            "longitude": 74.6,
            "active_crop": "Paddy",
            "active_sowing_date": "2026-02-01",
        },
    }


@router.get("/profile")
async def get_profile(token_data: dict = Depends(verify_token)):
    """Fetches the current user profile data."""
    user_id = token_data.get("sub")
    if not user_id or user_id == "local-user":
        return {"full_name": "Mock User", "language": "en", "latitude": 13.8, "longitude": 74.6}

    user = await fetch_one(
        "SELECT full_name, language, latitude, longitude, active_crop, active_sowing_date FROM users WHERE id = $1",
        int(user_id),
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return dict(user)


@router.patch("/profile")
async def update_profile(req: ProfileUpdate, token_data: dict = Depends(verify_token)):
    """Updates the user's name, language, or location."""
    user_id = token_data.get("sub")
    if not user_id or user_id == "local-user":
        return {"status": "success (DB-less)"}

    # Dynamic query builder
    updates = []
    params = []
    if req.full_name is not None:
        updates.append(f"full_name = ${len(params)+1}")
        params.append(req.full_name)
    if req.language is not None:
        updates.append(f"language = ${len(params)+1}")
        params.append(req.language)
    if req.latitude is not None:
        updates.append(f"latitude = ${len(params)+1}")
        params.append(req.latitude)
    if req.longitude is not None:
        updates.append(f"longitude = ${len(params)+1}")
        params.append(req.longitude)

    if not updates:
        return {"status": "no_changes"}

    params.append(int(user_id))
    query = f"UPDATE users SET {', '.join(updates)} WHERE id = ${len(params)}"
    
    await execute(query, *params)
    return {"status": "success", "updated_fields": [u.split(' = ')[0] for u in updates]}



@router.get("/crops")
async def list_crops(token_data: dict = Depends(verify_token)):
    """Lists all crops for the authenticated user."""
    user_id = token_data.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    if user_id == "local-user":
        return [{"id": 0, "crop_name": "Paddy", "is_primary": True}]

    crops = await fetch_all(
        "SELECT id, crop_name, variety, sowing_date, latitude, longitude, is_primary FROM user_crops WHERE user_id = $1 ORDER BY is_primary DESC, created_at DESC",
        int(user_id),
    )
    return [dict(c) for c in crops]


@router.post("/crops")
async def add_crop(req: CropRequest, token_data: dict = Depends(verify_token)):
    """Adds a new crop to the user's profile."""
    user_id = token_data.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    if user_id == "local-user":
        return {"status": "success (DB-less)", "crop_id": "mock-crop"}

    # Check if this is the first crop for the user
    existing = await fetch_one(
        "SELECT id FROM user_crops WHERE user_id = $1 LIMIT 1", int(user_id)
    )
    is_primary = req.is_primary or (not existing)

    pool = get_pool()
    if not pool:
        raise HTTPException(status_code=500, detail="Database unavailable")

    try:
        async with pool.acquire() as conn:
            async with conn.transaction():
                if is_primary:
                    await conn.execute(
                        "UPDATE user_crops SET is_primary = FALSE WHERE user_id = $1",
                        int(user_id),
                    )
                row = await conn.fetchrow(
                    """INSERT INTO user_crops (user_id, crop_name, variety, sowing_date, latitude, longitude, is_primary)
                       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id""",
                    int(user_id),
                    req.crop_name,
                    req.variety,
                    req.sowing_date,
                    req.latitude,
                    req.longitude,
                    is_primary,
                )
        return {"status": "success", "crop_id": row["id"]}
    except Exception as e:
        logger.error(f"Failed to add crop: {e}")
        raise HTTPException(status_code=500, detail=f"Database failure: {str(e)}")


@router.delete("/crops/{crop_id}")
async def delete_crop(crop_id: int, token_data: dict = Depends(verify_token)):
    """Removes a crop from the user's profile."""
    user_id = token_data.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    if user_id == "local-user":
        return {"status": "deleted (DB-less)"}

    await execute(
        "DELETE FROM user_crops WHERE id = $1 AND user_id = $2", crop_id, int(user_id)
    )
    return {"status": "success"}


@router.patch("/crops/{crop_id}/set-primary")
async def set_primary_crop(crop_id: int, token_data: dict = Depends(verify_token)):
    """Switches the active dashboard crop."""
    user_id = token_data.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")
    if user_id == "local-user":
        return {"status": "primary_updated (DB-less)"}

    pool = get_pool()
    if not pool:
        raise HTTPException(status_code=500, detail="Database unavailable")

    try:
        async with pool.acquire() as conn:
            async with conn.transaction():
                await conn.execute(
                    "UPDATE user_crops SET is_primary = FALSE WHERE user_id = $1",
                    int(user_id),
                )
                await conn.execute(
                    "UPDATE user_crops SET is_primary = TRUE WHERE id = $1 AND user_id = $2",
                    crop_id,
                    int(user_id),
                )
                
                # CRITICAL SYNC: Update the main users table for fast dashboard lookups
                crop_info = await conn.fetchrow(
                    "SELECT crop_name, sowing_date FROM user_crops WHERE id = $1", crop_id
                )
                if crop_info:
                    await conn.execute(
                        "UPDATE users SET active_crop = $1, active_sowing_date = $2 WHERE id = $3",
                        crop_info["crop_name"],
                        crop_info["sowing_date"],
                        int(user_id)
                    )

        return {"status": "success", "message": "Primary crop updated and synced"}
    except Exception as e:
        logger.error(f"Transaction failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to update primary crop")


@router.post("/quick-login")
async def quick_login(req: PinLoginRequest):
    """Fast login for shared devices using phone + PIN."""
    from app.utils.database import fetch_one, get_pool

    pool = get_pool()
    if not pool:
        # DB-less simulation
        return {
            "status": "authenticated (DB-less)",
            "token": create_access_token("local-user", req.phone_number),
            "profile": {"full_name": "Shared User", "language": "en"},
        }

    user = await fetch_one(
        "SELECT id, phone_number, full_name, language, active_crop, active_sowing_date, quick_pin FROM users WHERE phone_number = $1",
        req.phone_number,
    )

    if not user or user["quick_pin"] != req.pin:
        raise HTTPException(status_code=401, detail="Invalid PIN or phone number")

    token = create_access_token(
        str(user["id"]),
        user["phone_number"],
        user["active_crop"],
        user["active_sowing_date"],
    )
    return {
        "status": "authenticated",
        "token": token,
        "profile": {"full_name": user["full_name"], "language": user["language"]},
    }
