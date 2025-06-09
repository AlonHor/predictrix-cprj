from cqrs import Command
from db_utils import DbUtils
from firebase_admin import auth
from queries import GetUserProfileQuery
import json


class CreateUserCommand(Command):
    def execute(self, token: str) -> str:
        """
        Execute the command to create a user in the database based on the provided Firebase token.
        :param token: Firebase ID token of the user to be created.
        :return: User ID if successful, empty string if an error occurs.
        """
        try:
            decoded_token = auth.verify_id_token(token)
            uid = decoded_token["uid"]
            display_name = decoded_token.get("name", "Unknown User")
            email = decoded_token.get("email", "")
            photo_url = decoded_token.get("picture", "")
            print(f"Decoded token for user {uid}: {decoded_token}")

        except Exception as e:
            print(f"Error decoding token: {e}")
            return ""

        try:
            # Check if user already exists
            count = DbUtils(
                "SELECT COUNT(*) FROM Users WHERE UserId = %s", (uid,)).execute_single()
            count = list(count.values())[0] if count else 0  # type: ignore
            if count > 0:  # type: ignore
                print(f"User {uid} already exists.")
                return uid

            print(f"User {uid} does not exist, adding to database...")
            success = DbUtils(
                "INSERT INTO Users (UserId, DisplayName, Email, PhotoUrl, Chats) VALUES (%s, %s, %s, %s, '[]')",
                (uid, display_name, email, photo_url)
            ).execute_update()

            if not success:
                print(f"Failed to add user {uid}.")
                return ""
            print(f"User {uid} added successfully.")

            return uid

        except Exception as e:
            print(f"Error adding user {uid}: {e}")
            return ""


class AppendChatMessageCommand(Command):
    def execute(self, chat_id: str, message: dict) -> bool:
        """
        Append a new message dict to the Messages JSON array in the Chats table.
        Also updates LastMessage to be "{sender}: {content}".
        """
        try:
            # Fetch existing messages
            row = DbUtils(
                "SELECT Messages FROM Chats WHERE Id = %s", (chat_id,)
            ).execute_single()
            raw = row.get("Messages") if row else None  # type: ignore
            msgs = []
            if raw:
                try:
                    msgs = json.loads(str(raw))
                except Exception:
                    msgs = []
            # Append new message
            msgs.append(message)
            # Prepare LastMessage
            sender = GetUserProfileQuery().execute(message.get("sender", "")
                                                   ).get("displayName", "Unknown User")
            content = message.get("content", "")
            last_message = f"{sender}: {content}"
            # Persist back to database
            updated = json.dumps(msgs)
            success = DbUtils(
                "UPDATE Chats SET Messages = %s, LastMessage = %s WHERE Id = %s",
                (updated, last_message, chat_id)
            ).execute_update()
            return success
        except Exception as e:
            print(f"Error appending message to chat {chat_id}: {e}")
            return False
