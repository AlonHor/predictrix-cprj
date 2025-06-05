from cqrs import Query
from db_utils import DbUtils
import json


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
            query = f"SELECT * FROM Chats WHERE Id IN ({format_strings})"
            chats = DbUtils(query, tuple(chat_ids)).execute()
            print("Returning chat list: " + str(chats))
            return chats  # type: ignore

        except Exception as e:
            print(f"Error executing GetChatsQuery for user {uid}: {e}")
            return None
