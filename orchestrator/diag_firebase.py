import firebase_admin
from firebase_admin import credentials, messaging
import os


def test_firebase():
    cred_path = "firebase-service-account.json"
    if not os.path.exists(cred_path):
        print(f"Error: {cred_path} not found.")
        return

    try:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        print("Firebase Admin initialized successfully.")

        # Try a dry-run send to check API access
        # We use a fake token but set dry_run=True to check if the connection to Google works
        message = messaging.Message(
            notification=messaging.Notification(
                title="Test",
                body="Test",
            ),
            token="fake-token-for-dry-run",
        )
        try:
            # This should fail with "invalid-argument" or "unregistered" if the token is fake,
            # but if it fails with "authentication" or "permission-denied", then the key is the issue.
            messaging.send(message, dry_run=True)
        except firebase_admin.exceptions.InvalidArgumentError as e:
            print(f"Connection successful! (Expected error for fake token: {e})")
        except Exception as e:
            print(f"Firebase Messaging error: {e}")

    except Exception as e:
        print(f"Initialization error: {e}")


if __name__ == "__main__":
    test_firebase()
