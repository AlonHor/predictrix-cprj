from cqrs import Query
from db_utils import DbUtils
import json
from typing import Any
import time

# Cache for user profiles: uid -> (profile dict, timestamp)
_user_profile_cache: dict[str, tuple[dict[str, str], float]] = {}


class GetChatsQuery(Query):
    def execute(self, uid: str) -> list[dict[str, str]] | None:
        """
        Execute the query to get chats for a user.
        :param uid: User ID for which to retrieve chats.
        :return: List of chats or None if an error occurs.
        """
        try:
            # Get chat ids from Users table (Chats column)
            row = DbUtils(
                "SELECT Chats FROM Users WHERE UserId = %s", (uid,)).execute_single()
            if not row or not row.get("Chats"):  # type: ignore
                print(f"No chats found for user {uid}.")
                return []
            chat_ids = json.loads(row["Chats"])  # type: ignore
            print(f"Chat IDs for user {uid}: {chat_ids}")
            if not chat_ids:
                print(f"No chats found for user {uid}.")
                return []

            # Fetch chats from Chats table
            format_strings = ','.join(['%s'] * len(chat_ids))
            query = f"SELECT Id, Name, LastMessage, Type, Members FROM Chats WHERE Id IN ({format_strings})"
            chats = DbUtils(query, tuple(chat_ids)).execute()
            print("Returning chat list: " + str(chats))
            return chats  # type: ignore

        except Exception as e:
            print(f"Error executing GetChatsQuery for user {uid}: {e}")
            return None


class GetUserProfileQuery(Query):
    def execute(self, uid: str) -> dict[str, str]:
        """
        Retrieve both displayName and photoUrl for a given user ID, cached for 1 hour.
        """
        now = time.time()
        cached = _user_profile_cache.get(uid)
        if cached:
            profile, ts = cached
            if now - ts < 3600:
                return profile
        profile = {"displayName": "", "photoUrl": ""}
        try:
            row = DbUtils(
                "SELECT DisplayName, PhotoUrl FROM Users WHERE UserId = %s", (
                    uid,)
            ).execute_single()
            if row:
                data: Any = dict(row)  # type: ignore
                name = data.get("DisplayName", "")
                photo = data.get("PhotoUrl", "")
                profile["displayName"] = str(name)
                profile["photoUrl"] = str(photo)
        except Exception as e:
            print(f"Error executing GetUserProfileQuery for user {uid}: {e}")
        _user_profile_cache[uid] = (profile, now)
        return profile


class GetChatMembersQuery(Query):
    def execute(self, chat_id: str) -> list[str]:
        """
        Retrieve user IDs of members in the given chat using Chats.Members column.
        """
        try:
            row = DbUtils(
                "SELECT Members FROM Chats WHERE Id = %s", (chat_id,)
            ).execute_single()
            # No members field or empty
            if not row or not row.get("Members"):  # type: ignore
                print(f"No members found for chat {chat_id}.")
                return []
            # Ensure JSON string
            raw = row.get("Members")  # type: ignore
            members_str = str(raw)
            ids = json.loads(members_str)
            return [str(uid) for uid in ids]
        except Exception as e:
            print(
                f"Error executing GetChatMembersQuery for chat {chat_id}: {e}")
            return []


class GetChatMessagesQuery(Query):
    def execute(self, chat_id: str) -> list[dict]:
        """
        Retrieve list of message entries (dict or IDs) from Chats.Messages JSON.
        """
        try:
            row = DbUtils(
                "SELECT Messages FROM Chats WHERE Id = %s", (chat_id,)
            ).execute_single()
            if not row or not row.get("Messages"):  # type: ignore
                return []
            raw = row.get("Messages")  # type: ignore
            msgs = json.loads(str(raw))
            return msgs if isinstance(msgs, list) else []
        except Exception as e:
            print(
                f"Error executing GetChatMessagesQuery for chat {chat_id}: {e}")
            return []


class GetChatStatsQuery(Query):
    def execute(self, chat_id: str) -> tuple[dict[str, float], dict[str, int]]:
        """
        Retrieve score sums and prediction counts per user for a chat.
        Returns (score_map, pred_count_map).
        """
        try:
            row = DbUtils(
                "SELECT ScoreSumPerUser, PredictionsPerUser FROM Chats WHERE Id = %s", (
                    chat_id,)
            ).execute_single()
            if not row:
                return {}, {}
            # convert to plain dict for key access
            row_dict: dict[str, Any] = dict(row)  # type: ignore
            # raw JSON fields
            raw_scores = row_dict.get("ScoreSumPerUser") or '{}'
            raw_preds = row_dict.get("PredictionsPerUser") or '{}'
            # parse JSON
            scores = json.loads(str(raw_scores))
            preds = json.loads(str(raw_preds))
            # normalize
            score_map = {str(k): float(v) for k, v in scores.items()}
            pred_map = {str(k): int(v) for k, v in preds.items()}
            return score_map, pred_map
        except Exception as e:
            print(f"Error executing GetChatStatsQuery for chat {chat_id}: {e}")
            return {}, {}


class GetAssertionQuery(Query):
    def execute(self, assertion_id: str) -> dict[str, Any]:
        """
        Retrieve assertion details by ID for message enrichment.
        """
        try:
            row = DbUtils(
                "SELECT UserId, Text, ValidationDate, CastingForecastDeadline, CreatedAt, Completed, FinalAnswer FROM Assertions WHERE Id = %s",
                (assertion_id,)
            ).execute_single()

            if not row:
                return {}

            assertion_dict: dict[str, Any] = dict(row)  # type: ignore

            # Get user profile for sender info
            user_id = assertion_dict.get("UserId", "")
            profile = GetUserProfileQuery().execute(str(user_id)) if user_id else {
                "displayName": "", "photoUrl": ""}

            # Convert TINYINT to boolean
            completed = bool(assertion_dict.get("Completed", 0))
            final_answer = bool(assertion_dict.get("FinalAnswer", 0))

            # Format timestamp
            created_at = assertion_dict.get("CreatedAt", "")
            timestamp = created_at.isoformat() + "Z" if hasattr(created_at,
                                                                'isoformat') else str(created_at)

            return {
                "sender": profile,
                "timestamp": timestamp,
                "type": "assertion",
                "content": {
                    "id": assertion_id,
                    "text": str(assertion_dict.get("Text", "")),
                    "validationDate": str(assertion_dict.get("ValidationDate", "")),
                    "castingForecastDeadline": str(assertion_dict.get("CastingForecastDeadline", "")),
                    "completed": completed,
                    "finalAnswer": final_answer
                }
            }

        except Exception as e:
            print(
                f"Error executing GetAssertionQuery for assertion {assertion_id}: {e}")
            return {}
