from cqrs import Query
from db_utils import DbUtils
import json
from typing import Any
import time

# Cache for user display names: uid -> (name, timestamp)
_display_name_cache: dict[str, tuple[str, float]] = {}


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


class GetUserDisplayNameQuery(Query):
    def execute(self, uid: str) -> str:
        """
        Retrieve the display name for a given user ID from Users table.
        """
        now = time.time()
        # Return cached if within TTL
        if uid in _display_name_cache:
            name, ts = _display_name_cache[uid]
            if now - ts < 3600:
                return name
        try:
            row = DbUtils(
                "SELECT DisplayName FROM Users WHERE UserId = %s", (uid,)
            ).execute_single()
            if row and row.get("DisplayName"):  # type: ignore
                display_name = str(row.get("DisplayName"))  # type: ignore
                _display_name_cache[uid] = (display_name, now)
                return display_name
        except Exception as e:
            print(
                f"Error executing GetUserDisplayNameQuery for user {uid}: {e}")
        return ""
