import asyncpg
from app.utils.config import get_settings
from app.utils.logger import logger

# Module-level connection pool
_pool: asyncpg.Pool | None = None


async def init_db():
    """Initializes the async connection pool and creates tables if they don't exist."""
    global _pool
    settings = get_settings()

    if not settings.database_url:
        logger.warning("DATABASE_URL not configured. Running in DB-less mode.")
        return

    try:
        # Scaled for production concurrency
        _pool = await asyncpg.create_pool(
            settings.database_url, min_size=5, max_size=20
        )
        logger.info("Database connection pool created.")

        async with _pool.acquire() as conn:
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    phone_number VARCHAR(20) UNIQUE NOT NULL,
                    password_hash TEXT,
                    full_name VARCHAR(200),
                    language VARCHAR(5) DEFAULT 'en',
                    latitude DOUBLE PRECISION,
                    longitude DOUBLE PRECISION,
                    active_crop VARCHAR(100),
                    active_sowing_date DATE,
                    quick_pin VARCHAR(4),
                    fcm_token TEXT,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                );
            """)
            # MIGRATION: Ensure password_hash is nullable and add index for quick_pin
            await conn.execute("ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;")
            await conn.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;")
            await conn.execute("CREATE INDEX IF NOT EXISTS idx_users_quick_pin ON users (quick_pin);")
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS user_crops (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
                    crop_name VARCHAR(100) NOT NULL,
                    variety VARCHAR(100),
                    sowing_date DATE NOT NULL,
                    latitude DOUBLE PRECISION,
                    longitude DOUBLE PRECISION,
                    is_primary BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                );
            """)
            # Ensure only one primary crop per user (partial index)
            await conn.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS idx_user_primary_crop 
                ON user_crops (user_id) WHERE (is_primary = TRUE);
            """)
            await conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_user_crops_user_id 
                ON user_crops (user_id, is_primary DESC, created_at DESC);
            """)
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS advisory_history (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
                    crop VARCHAR(100),
                    variety VARCHAR(100),
                    request_date DATE,
                    response_json JSONB,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                );
            """)
            await conn.execute("""
                CREATE INDEX IF NOT EXISTS idx_advisory_user
                ON advisory_history(user_id, created_at DESC);
            """)
        logger.info("Database tables verified/created.")
    except Exception as e:
        logger.error(f"Database initialization failed: {e}. Running in DB-less mode.")
        _pool = None


async def close_db():
    """Closes the database connection pool."""
    global _pool
    if _pool:
        await _pool.close()
        logger.info("Database connection pool closed.")
        _pool = None


def get_pool() -> asyncpg.Pool | None:
    """Returns the connection pool, or None if DB is unavailable."""
    return _pool


async def execute(query: str, *args):
    """Executes a query and returns the status. Returns None if DB is unavailable."""
    if not _pool:
        return None
    try:
        async with _pool.acquire() as conn:
            return await conn.execute(query, *args)
    except Exception as e:
        logger.error(f"DB execute error: {e}")
        return None


async def fetch_one(query: str, *args):
    """Fetches a single row. Returns None if DB is unavailable."""
    if not _pool:
        return None
    try:
        async with _pool.acquire() as conn:
            return await conn.fetchrow(query, *args)
    except Exception as e:
        logger.error(f"DB fetch_one error: {e}")
        return None


async def fetch_all(query: str, *args):
    """Fetches all rows. Returns empty list if DB is unavailable."""
    if not _pool:
        return []
    try:
        async with _pool.acquire() as conn:
            return await conn.fetch(query, *args)
    except Exception as e:
        logger.error(f"DB fetch_all error: {e}")
        return []
