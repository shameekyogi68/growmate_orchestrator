import firebase_admin
from firebase_admin import credentials, messaging
from app.utils.logger import logger
from app.utils.config import get_settings
import os

_initialized = False

def init_firebase():
    """Initializes Firebase Admin SDK."""
    global _initialized
    if _initialized:
        return

    settings = get_settings()
    # Path to service account JSON (from environment variable or default location)
    cred_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "firebase-service-account.json")
    
    try:
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            _initialized = True
            logger.info("Firebase Admin initialized successfully.")
        else:
            logger.warning(f"Firebase service account file not found at {cred_path}. Push notifications will be disabled.")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin: {e}")

async def send_push_notification(token: str, title: str, body: str, data: dict = None):
    """Sends a push notification to a specific device token (async-safe)."""
    if not _initialized:
        logger.warning("Firebase Admin not initialized. Skipping notification.")
        return False

    import asyncio
    
    def _send_sync():
        # Industry Standard: Add Platform-Specific Configs for Reliability
        android_config = messaging.AndroidConfig(
            priority='high',
            notification=messaging.AndroidNotification(
                channel_id='high_importance_channel',
                priority='high',
                default_sound=True,
                default_vibrate_timings=True,
            )
        )
        
        apns_config = messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    alert=messaging.ApsAlert(title=title, body=body),
                    sound='default',
                    badge=1,
                    mutable_content=True,
                )
            )
        )

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=token,
            android=android_config,
            apns=apns_config
        )
        return messaging.send(message)

    try:
        # Run blocking SDK call in a separate thread to keep FastAPI responsive
        response = await asyncio.to_thread(_send_sync)
        logger.info(f"Successfully sent message: {response}")
        return True
    except messaging.UnregisteredError:
        logger.warning(f"FCM token {token} is unregistered. Removing from DB.")
        from app.utils.database import execute
        await execute("UPDATE users SET fcm_token = NULL WHERE fcm_token = $1", token)
        return False
    except Exception as e:
        logger.error(f"Error sending push notification: {e}")
        return False

async def notify_user(user_id: int, title: str, body: str, data: dict = None):
    """Fetches user FCM token from DB and sends a notification."""
    from app.utils.database import fetch_one
    
    user = await fetch_one("SELECT fcm_token FROM users WHERE id = $1", user_id)
    if user and user["fcm_token"]:
        return await send_push_notification(user["fcm_token"], title, body, data)
    else:
        logger.warning(f"No FCM token found for user {user_id}")
        return False
