
import asyncio
from app.utils.database import init_db, fetch_all, close_db
from app.services.notification_service import init_firebase, send_push_notification

async def send_real_test():
    print("🚀 DISPATCHING REAL TEST NOTIFICATIONS...")
    print("-" * 40)
    
    await init_db()
    init_firebase()
    
    # Get all real tokens (excluding the mock one)
    users = await fetch_all("SELECT id, full_name, fcm_token FROM users WHERE fcm_token IS NOT NULL AND fcm_token != 'mock_fcm_token_123456'")
    
    if not users:
        print("❌ No real devices found to notify.")
        return

    for u in users:
        print(f"📡 Sending to {u['full_name']} (ID: {u['id']})...")
        success = await send_push_notification(
            u['fcm_token'],
            title="GrowMate Live Test 🌾",
            body=f"Hello {u['full_name']}! This is a live test from your backend. Your database is now perfectly connected!",
            data={"type": "test", "priority": "high"}
        )
        if success:
            print(f"✅ SUCCESSFULLY SENT to {u['full_name']}")
        else:
            print(f"❌ FAILED to send to {u['full_name']} (Token might be expired)")

    await close_db()
    print("-" * 40)
    print("Done.")

if __name__ == "__main__":
    asyncio.run(send_real_test())
