from cqrs import Command
from db_utils import DbUtils
from firebase_admin import auth


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
