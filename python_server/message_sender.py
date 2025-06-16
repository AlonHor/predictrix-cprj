from firebase_admin import messaging


def send_message(topic: str, text: str, profile: dict) -> bool:
    message = messaging.Message(
        topic=topic,
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                title=profile.get("displayName", "New Message"),
                icon="ic_notification",
                image=profile.get("photoUrl", ""),
                color="#0088FF",
                body=text,
                sound="default"
            ),
        ),
    )

    try:
        response = messaging.send(message)
        print(f"Sent message to topic {topic}: {response}")
        return True
    except Exception as e:
        print(f"Failed to send message to topic {topic}: {e}")
        return False
