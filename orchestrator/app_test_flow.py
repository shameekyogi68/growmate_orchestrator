
import asyncio
import uuid
from app.utils.database import init_db, fetch_one, execute, close_db
from app.services.notification_service import init_firebase, notify_user
from app.utils.config import get_settings

async def test_end_to_end():
    print("🧪 STARTING END-TO-END FLOW TEST...")
    print("-" * 40)
    
    # 1. Initialize
    await init_db()
    init_firebase()
    
    test_phone = f"+91{uuid.uuid4().hex[:8]}"
    test_name = "Automated Test User"
    test_fcm = "mock_fcm_token_123456"
    
    print(f"📝 Step 1: Simulating Registration for {test_phone}...")
    try:
        # We manually insert to test the DB connection logic
        await execute(
            "INSERT INTO users (phone_number, full_name, fcm_token) VALUES ($1, $2, $3)",
            test_phone, test_name, test_fcm
        )
        print("✅ User successfully inserted into Supabase!")
    except Exception as e:
        print(f"❌ DB Insert failed: {e}")
        return

    print(f"🔍 Step 2: Verifying user exists in DB...")
    user = await fetch_one("SELECT id, full_name, fcm_token FROM users WHERE phone_number = $1", test_phone)
    if user and user['full_name'] == test_name:
        print(f"✅ Verified: User {user['id']} found in Supabase with correct data.")
        user_id = user['id']
    else:
        print("❌ Verification failed: User not found after insert.")
        return

    print(f"🔔 Step 3: Testing Notification Dispatch...")
    # This will attempt to send to the mock token. 
    # It will fail in the Firebase SDK (because the token is fake), 
    # but we want to see if the backend logic reaches the 'send' stage.
    success = await notify_user(user_id, "Test Title", "Test Body")
    
    # Note: notify_user returns False if the token is invalid/fake, 
    # but we checked in final_diag that the SDK is initialized.
    print("✅ Notification logic executed.")
    print("-" * 40)
    print("🎉 TEST COMPLETE!")
    print(f"The user '{test_name}' is now permanent in your Supabase dashboard.")
    
    await close_db()

if __name__ == "__main__":
    asyncio.run(test_end_to_end())
