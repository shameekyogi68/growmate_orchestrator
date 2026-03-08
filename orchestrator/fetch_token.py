import asyncio
from app.utils.database import init_db, fetch_all, close_db


async def main():
    try:
        await init_db()
        users = await fetch_all(
            "SELECT id, phone_number, fcm_token FROM users WHERE fcm_token IS NOT NULL"
        )
        for u in users:
            print(
                f"ID: {u['id']}, Phone: {u['phone_number']}, FCM Token: {u['fcm_token']}"
            )
    finally:
        await close_db()


if __name__ == "__main__":
    asyncio.run(main())
