from cqrs import Command
from db_utils import DbUtils
from firebase_admin import auth
from queries import GetUserProfileQuery
import json
from typing import Any


class CreateUserCommand(Command):
    def execute(self, token: str) -> tuple[str, str]:
        """
        Execute the command to create a user in the database based on the provided Firebase token.
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
            return ("", "Unknown User")

        try:
            # Check if user already exists
            count = DbUtils(
                "SELECT COUNT(*) FROM Users WHERE UserId = %s", (uid,)).execute_single()
            count = list(count.values())[0] if count else 0  # type: ignore
            if count > 0:  # type: ignore
                print(f"User {uid} already exists.")

                # Update user details if necessary
                existing_user = DbUtils(
                    "SELECT DisplayName, Email, PhotoUrl FROM Users WHERE UserId = %s", (
                        uid,)
                ).execute_single()

                if existing_user:
                    db_display_name = existing_user.get(  # type: ignore
                        "DisplayName", "")
                    db_email = existing_user.get("Email", "")  # type: ignore
                    db_photo_url = existing_user.get(  # type: ignore
                        "PhotoUrl", "")
                    if db_display_name != display_name or db_email != email or db_photo_url != photo_url:
                        print(f"Updating user {uid} details...")
                        DbUtils(
                            "UPDATE Users SET DisplayName = %s, Email = %s, PhotoUrl = %s WHERE UserId = %s",
                            (display_name, email, photo_url, uid)
                        ).execute_update()

                return (uid, display_name)

            print(f"User {uid} does not exist, adding to database...")
            success = DbUtils(
                "INSERT INTO Users (UserId, DisplayName, Email, PhotoUrl, Chats) VALUES (%s, %s, %s, %s, '[]')",
                (uid, display_name, email, photo_url)
            ).execute_update()

            if not success:
                print(f"Failed to add user {uid}.")
                return ("", "Unknown User")
            print(f"User {uid} added successfully.")

            return (uid, display_name)

        except Exception as e:
            print(f"Error adding user {uid}: {e}")
            return ("", "Unknown User")


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

            if (type(message) is int):
                success = DbUtils(
                    "UPDATE Chats SET Messages = %s WHERE Id = %s",
                    (json.dumps(msgs), chat_id)
                ).execute_update()
                return success

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


class JoinChatCommand(Command):
    def execute(self, chat_id: str, user_id: str) -> bool:
        """
        Add a user to a chat by updating both Chats.Members and Users.Chats.
        """
        try:
            # Add user to chat members
            chat_row = DbUtils(
                "SELECT Members FROM Chats WHERE Id = %s", (chat_id,)
            ).execute_single()
            if not chat_row:
                print(f"Chat {chat_id} not found.")
                return False

            chat_dict: dict[str, Any] = dict(chat_row)  # type: ignore
            members_json = chat_dict.get("Members") or "[]"
            members = json.loads(str(members_json))

            # Check if user is already a member
            if user_id in members:
                print(f"User {user_id} is already a member of chat {chat_id}.")
                return True

            # Add user to members list
            members.append(user_id)
            updated_members = json.dumps(members)

            success1 = DbUtils(
                "UPDATE Chats SET Members = %s WHERE Id = %s",
                (updated_members, chat_id)
            ).execute_update()

            if not success1:
                print(
                    f"Failed to add user {user_id} to chat {chat_id} members.")
                return False

            # Update ScoreSumPerUser and PredictionsPerUser for the new member
            chat_stats_row = DbUtils(
                "SELECT ScoreSumPerUser, PredictionsPerUser FROM Chats WHERE Id = %s", (
                    chat_id,)
            ).execute_single()
            if chat_stats_row:
                stats_dict: dict[str, Any] = dict(
                    chat_stats_row)  # type: ignore

                # Update ScoreSumPerUser
                scores_json = stats_dict.get("ScoreSumPerUser") or "{}"
                scores = json.loads(str(scores_json))
                if user_id not in scores:
                    scores[user_id] = 0

                # Update PredictionsPerUser
                preds_json = stats_dict.get("PredictionsPerUser") or "{}"
                preds = json.loads(str(preds_json))
                if user_id not in preds:
                    preds[user_id] = 0

                # Save updated stats
                success_stats = DbUtils(
                    "UPDATE Chats SET ScoreSumPerUser = %s, PredictionsPerUser = %s WHERE Id = %s",
                    (json.dumps(scores), json.dumps(preds), chat_id)
                ).execute_update()

                if not success_stats:
                    print(
                        f"Failed to update chat stats for user {user_id} in chat {chat_id}.")

            # Add chat to user's chats
            user_row = DbUtils(
                "SELECT Chats FROM Users WHERE UserId = %s", (user_id,)
            ).execute_single()
            if not user_row:
                print(f"User {user_id} not found.")
                return False

            user_dict: dict[str, Any] = dict(user_row)  # type: ignore
            chats_json = user_dict.get("Chats") or "[]"
            chats = json.loads(str(chats_json))

            # Check if chat is already in user's chats
            chat_id_int = int(chat_id)
            if chat_id_int not in chats:
                chats.append(chat_id_int)
                updated_chats = json.dumps(chats)

                success2 = DbUtils(
                    "UPDATE Users SET Chats = %s WHERE UserId = %s",
                    (updated_chats, user_id)
                ).execute_update()

                if not success2:
                    print(
                        f"Failed to add chat {chat_id} to user {user_id} chats.")
                    return False

            print(f"Successfully added user {user_id} to chat {chat_id}.")
            return True

        except Exception as e:
            print(
                f"Error in JoinChatCommand for user {user_id}, chat {chat_id}: {e}")
            return False


class CreateChatCommand(Command):
    def execute(self, name: str, creator_uid: str) -> str:
        """
        Create a new chat and add the creator as the first member.
        Returns the chat ID if successful, empty string if failed.
        """
        try:
            # Initialize chat data
            members = [creator_uid]
            score_sum = {creator_uid: 0}
            predictions = {creator_uid: 0}

            # Insert new chat
            success = DbUtils(
                "INSERT INTO Chats (Name, Type, Members, ScoreSumPerUser, PredictionsPerUser) VALUES (%s, %s, %s, %s, %s)",
                (name, 0, json.dumps(members), json.dumps(
                    score_sum), json.dumps(predictions))
            ).execute_update()

            if not success:
                print(f"Failed to create chat with name: {name}")
                return ""

            # Get the created chat ID
            chat_row = DbUtils(
                "SELECT Id FROM Chats WHERE Name = %s AND Type = 0 ORDER BY Id DESC LIMIT 1", (
                    name,)
            ).execute_single()

            if not chat_row:
                print(f"Failed to retrieve created chat ID for: {name}")
                return ""

            chat_dict: dict[str, Any] = dict(chat_row)  # type: ignore
            chat_id = str(chat_dict.get("Id", ""))

            if not chat_id:
                print(f"Invalid chat ID retrieved for: {name}")
                return ""

            # Add chat to creator's chat list
            user_row = DbUtils(
                "SELECT Chats FROM Users WHERE UserId = %s", (creator_uid,)
            ).execute_single()

            if user_row:
                user_dict: dict[str, Any] = dict(user_row)  # type: ignore
                chats_json = user_dict.get("Chats") or "[]"
                chats = json.loads(str(chats_json))
                chat_id_int = int(chat_id)

                if chat_id_int not in chats:
                    chats.append(chat_id_int)
                    updated_chats = json.dumps(chats)

                    success_user = DbUtils(
                        "UPDATE Users SET Chats = %s WHERE UserId = %s",
                        (updated_chats, creator_uid)
                    ).execute_update()

                    if not success_user:
                        print(
                            f"Failed to add chat {chat_id} to user {creator_uid} chats.")

            print(f"Successfully created chat '{name}' with ID {chat_id}")
            return chat_id

        except Exception as e:
            print(f"Error creating chat '{name}': {e}")
            return ""


class CreateAssertionCommand(Command):
    def execute(self, user_id: str, chat_id: str, text: str, validation_date: str, casting_deadline: str) -> str:
        """
        Create a new assertion in the Assertions table.
        Returns the assertion ID if successful, empty string if failed.
        """
        try:
            success = DbUtils(
                "INSERT INTO Assertions (UserId, Text, ChatId, Predictions, ValidationDate, CastingForecastDeadline) VALUES (%s, %s, %s, %s, %s, %s)",
                (user_id, text, chat_id, "{}",
                 validation_date, casting_deadline)
            ).execute_update()

            if not success:
                print(f"Failed to create assertion for user: {user_id}")
                return ""

            # Get the created assertion ID
            assertion_row = DbUtils(
                "SELECT Id FROM Assertions WHERE UserId = %s AND Text = %s ORDER BY Id DESC LIMIT 1",
                (user_id, text)
            ).execute_single()

            if not assertion_row:
                print(
                    f"Failed to retrieve created assertion ID for user: {user_id}")
                return ""

            assertion_dict: dict[str, Any] = dict(
                assertion_row)  # type: ignore
            assertion_id = str(assertion_dict.get("Id", ""))

            if not assertion_id:
                print(f"Invalid assertion ID retrieved for user: {user_id}")
                return ""

            print(f"Successfully created assertion with ID {assertion_id}")
            return assertion_id

        except Exception as e:
            print(f"Error creating assertion for user {user_id}: {e}")
            return ""


class AddPredictionCommand(Command):
    def execute(self, assertion_id: str, user_id: str, confidence: float, forecast: bool) -> bool:
        """
        Add a prediction to an assertion's Predictions JSON field.
        """
        try:
            # Get current predictions
            row = DbUtils(
                "SELECT Predictions FROM Assertions WHERE Id = %s", (
                    assertion_id,)
            ).execute_single()

            if not row:
                print(f"Assertion {assertion_id} not found.")
                return False

            # Parse existing predictions or start with empty dict
            row_dict: dict[str, Any] = dict(row)  # type: ignore
            predictions_json = row_dict.get("Predictions") or "{}"
            predictions = json.loads(
                str(predictions_json)) if predictions_json else {}

            # Check if user has already made a prediction
            if user_id in predictions:
                print(
                    f"User {user_id} has already made a prediction for assertion {assertion_id}")
                return False

            # Add user's prediction (first time only)
            predictions[user_id] = {
                "confidence": confidence,
                "forecast": forecast
            }

            # Update database
            success = DbUtils(
                "UPDATE Assertions SET Predictions = %s WHERE Id = %s",
                (json.dumps(predictions), assertion_id)
            ).execute_update()

            return success

        except Exception as e:
            print(f"Error adding prediction to assertion {assertion_id}: {e}")
            return False


class AddVoteCommand(Command):
    def execute(self, assertion_id: str, user_id: str, vote: bool) -> bool:
        """
        Add or update a user's vote on an assertion.
        """
        try:
            # Get current votes
            row = DbUtils(
                "SELECT Votes FROM Assertions WHERE Id = %s",
                (assertion_id,)
            ).execute_single()

            if not row:
                print(f"Assertion {assertion_id} not found.")
                return False

            votes_data: dict[str, Any] = dict(row)  # type: ignore
            votes_json = votes_data.get("Votes", "{}")

            # Parse existing votes
            if isinstance(votes_json, str):
                try:
                    votes = json.loads(votes_json)
                except:
                    votes = {}
            else:
                votes = votes_json if votes_json else {}

            # Add or update the user's vote
            votes[user_id] = vote

            # Update database
            success = DbUtils(
                "UPDATE Assertions SET Votes = %s WHERE Id = %s",
                (json.dumps(votes), assertion_id)
            ).execute_update()

            return success

        except Exception as e:
            print(f"Error adding vote to assertion {assertion_id}: {e}")
            return False
