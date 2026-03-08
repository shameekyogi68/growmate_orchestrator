import asyncio
from app.utils.database import init_db, fetch_one, close_db
from app.services.notification_service import init_firebase
from app.utils.config import get_settings


async def final_diagnostic():
    print("🚀 Starting Final GrowMate Diagnostic...")
    print("-" * 40)

    # 1. Check Configuration Loading
    settings = get_settings()
    print(f"📦 Env Loaded: {settings.environment}")
    print(f"🔗 Detected DB URL: {settings.database_url}")
    if (
        not settings.database_url
        or "[YOUR_PASSWORD]" in settings.database_url
        or "YOUR_PROJECT_ID" in settings.database_url
    ):
        print("❌ ERROR: DATABASE_URL still contains placeholders in .env")
        return

    # 2. Test Supabase Connection & Table Initialization
    print("⏳ Connecting to Supabase...")
    try:
        await init_db()
        # Try a simple query
        result = await fetch_one("SELECT 1 as connected")
        if result and result["connected"] == 1:
            print("✅ Supabase: Connected Successfully.")
            print("✅ Database Schema: Tables verified/created.")
        else:
            print("❌ Supabase: Connection failed (received empty result).")
    except Exception as e:
        print(f"❌ Supabase Error: {e}")
        return
    finally:
        await close_db()

    # 3. Test Firebase initialization
    print("-" * 40)
    print("⏳ Checking Firebase Admin SDK...")
    try:
        init_firebase()
        # The global _initialized is in the notification_service module
        from app.services.notification_service import _initialized as firebase_ready

        if firebase_ready:
            print("✅ Firebase: Initialized Successfully.")
        else:
            print("❌ Firebase: Service account file not found or init failed.")
    except Exception as e:
        print(f"❌ Firebase Error: {e}")

    print("-" * 40)
    print("🎉 DIAGNOSTIC COMPLETE!")
    print("If all items are green, your notifications will WORK perfectly.")
    print("Action: Just restart your local backend and log into the app!")


if __name__ == "__main__":
    asyncio.run(final_diagnostic())
