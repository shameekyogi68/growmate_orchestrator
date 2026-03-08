import asyncio
from app.utils.database import init_db, fetch_all, close_db
from app.services.notification_service import init_firebase, send_push_notification


async def broadcast_kannada_notif():
    print("🚀 DISPATCHING GLOBAL BROADCAST...")
    print("-" * 40)

    await init_db()
    init_firebase()

    # Get all users with tokens
    users = await fetch_all(
        "SELECT id, full_name, fcm_token FROM users WHERE fcm_token IS NOT NULL"
    )

    if not users:
        print("❌ No users found to notify.")
        return

    title = "GrowMate Alert! 🌾"
    body = "ಇದ್ರೆ ಅವನಮ್ಮನ್ ನೆಮ್ಮದಿ ಆಗಿರಬೇಕು!"

    print(f"Broadcasting message: '{body}' to {len(users)} users...")

    for u in users:
        print(f"📡 Sending to {u['full_name']} (ID: {u['id']})...")
        success = await send_push_notification(
            u["fcm_token"],
            title=title,
            body=body,
            data={"type": "broadcast", "priority": "high"},
        )
        if success:
            print(f"✅ SUCCESS: {u['full_name']}")
        else:
            # This is expected for the test_tokens we just added, but good to track
            print(f"⚠️ SKIPPED/FAILED: {u['full_name']} (Invalid Token)")

    await close_db()
    print("-" * 40)
    print("Broadcast finished.")


if __name__ == "__main__":
    asyncio.run(broadcast_kannada_notif())
