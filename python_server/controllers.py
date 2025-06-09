from abc import ABC, abstractmethod
from connection import Connection
from commands import CreateUserCommand, AppendChatMessageCommand, JoinChatCommand, CreateChatCommand
from commands import CreateAssertionCommand
from queries import GetChatsQuery, GetChatMembersQuery, GetChatMessagesQuery, GetUserProfileQuery, GetChatStatsQuery
from queries import GetAssertionQuery
import event_framework
import datetime
import json
import hashlib
import os


def generate_chat_join_token_hash(chat_id: str) -> str | None:
    """
    Generate a short hash for a chat join token using the chat ID and secret.
    """
    secret_code = os.environ.get("CJTK_SECRET", None)
    if not secret_code:
        return None
    hash_input = chat_id + secret_code
    hash_obj = hashlib.sha256(hash_input.encode())
    return hash_obj.hexdigest()[:32].upper()


class Controller(ABC):
    @abstractmethod
    def name(self) -> str:
        """
        Returns the 4-letter command name for this endpoint.
        """
        pass

    @abstractmethod
    def handle(self, connection: Connection, payload: str) -> bool:
        """
        Handle the request. Return True to continue the loop, False to close the connection.
        """
        pass


class PingController(Controller):
    def name(self):
        return "ping"

    def handle(self, connection: Connection, payload: str) -> bool:
        print(f"Ping received from {connection.addr}.")
        connection.send("ping", b"pong")
        return True


class ChatsController(Controller):
    def name(self):
        return "chts"

    def handle(self, connection: Connection, payload: str) -> bool:
        print(f"Client {connection.addr} requested chat list.")
        chats: list[dict[str, str]] | None = GetChatsQuery().execute(
            connection.uid)

        if not chats:
            print(f"No chats found for user {connection.uid}.")
            connection.send("chts", json.dumps([]).encode())
            return True

        chats_json = json.dumps([{
            "name": chat["Name"],
            "lastMessage": chat["LastMessage"],
            "chatId": str(chat["Id"]),
            "type": chat["Type"],
            "iconColor": "blue"
        } for chat in chats])

        connection.send("chts", chats_json.encode())

        return True


class MessagesController(Controller):
    def name(self):
        return "msgs"

    def handle(self, connection: Connection, payload: str) -> bool:
        # Send the last 50 messages for the given chat
        chat_id = payload.strip()
        print(
            f"Client {connection.addr} requested messages for chat {chat_id}.")

        # Check if user is a member of this chat
        members = GetChatMembersQuery().execute(chat_id)
        if connection.uid not in members:
            connection.send("msgs", b"not_member")
            return False

        messages = GetChatMessagesQuery().execute(chat_id)
        last50 = messages[-50:]
        # Enrich sender with profile (displayName, photoUrl)
        for msg in last50:
            if isinstance(msg, dict) and msg.get("sender"):
                profile = GetUserProfileQuery().execute(msg["sender"])
                msg["sender"] = profile
            elif isinstance(msg, (int, str)) and str(msg).isdigit():
                # This is an assertion ID, replace with assertion data
                assertion_data = GetAssertionQuery().execute(str(msg))
                if assertion_data:
                    last50[last50.index(msg)] = assertion_data
        connection.send(f"msgs{chat_id},", json.dumps(last50).encode())
        return True


class MembersController(Controller):
    def name(self):
        return "memb"

    def handle(self, connection: Connection, payload: str) -> bool:
        # Send the members of the given chat
        chat_id = payload.strip()
        print(
            f"Client {connection.addr} requested members for chat {chat_id}.")
        members = GetChatMembersQuery().execute(chat_id)
        if not members:
            connection.send("memb", b"no_members")
            return True
        # Fetch chat stats for ELO calculation
        score_map, pred_map = GetChatStatsQuery().execute(chat_id)
        result: dict[str, dict[str, float | str]] = {}
        for uid in members:
            profile = GetUserProfileQuery().execute(uid)
            name = profile.get("displayName") or uid
            preds = pred_map.get(uid, 0)
            score = score_map.get(uid, 0.0)
            elo = score / preds if preds > 0 else 0.0
            result[name] = {"photoUrl": profile.get(
                "photoUrl", ""), "elo": elo}
        connection.send("memb", json.dumps(result).encode())
        return True


class SendMessageController(Controller):
    def name(self):
        return "sndm"

    def handle(self, connection: Connection, payload: str) -> bool:
        # Append a new message to chat and broadcast event
        parts = payload.strip().split(" ", 1)
        chat_id = parts[0] if parts else ""
        if not chat_id:
            connection.send("sndm", b"invalid_chat_id")
            return False
        text = parts[1] if len(parts) > 1 else ""
        # Use display name as sender
        msg_obj = {
            "sender": connection.uid,
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            "content": text,
        }
        # Persist message
        success = AppendChatMessageCommand().execute(chat_id, msg_obj)
        if not success:
            connection.send("sndm", b"fail")
            return False
        # Broadcast to other members
        members = GetChatMembersQuery().execute(chat_id)
        recipients = [uid for uid in members if uid != connection.uid]

        # Embed full sender profile in event data
        profile = GetUserProfileQuery().execute(connection.uid)

        event_msg_obj = {
            **msg_obj,
            "sender": profile,
        }

        event_framework.emit_event({
            "prefix": "newm",
            "data": chat_id.encode() + b"," + json.dumps(event_msg_obj).encode(),
            "recipients": recipients,
        })
        connection.send("sndm", b"ok")
        return True


class UserController(Controller):
    def name(self):
        return "user"

    def handle(self, connection: Connection, payload: str) -> bool:
        print(f"Adding user...")
        uid = CreateUserCommand().execute(payload)
        if uid == "":
            print(f"Failed to add user with token: {payload}")
            connection.send("", b"token_fail")
            return False

        connection.set_uid(uid)
        connection.send("", b"token_ok")
        ChatsController().handle(connection, "")
        return True


class ChatJoinTokenGeneratorController(Controller):
    def name(self):
        return "cjtk"

    def handle(self, connection: Connection, payload: str) -> bool:
        chat_id = payload.strip()
        if not chat_id:
            connection.send("cjtk", b"invalid_chat_id")
            return False

        # Check if user is a member of this chat
        members = GetChatMembersQuery().execute(chat_id)
        if connection.uid not in members:
            return False

        # Generate token: ${chatId}.{short_hash}
        short_hash = generate_chat_join_token_hash(chat_id)
        if not short_hash:
            connection.send("cjtk", b"secret_fail")
            return False
        token = f"${short_hash}.@{chat_id}"

        connection.send("cjtk", token.encode())
        return True


class ChatJoinTokenController(Controller):
    def name(self):
        return "join"

    def handle(self, connection: Connection, payload: str) -> bool:
        token = payload.strip()
        if not token.startswith("$") or ".@" not in token:
            connection.send("join", b"invalid_token")
            return False

        # Parse token: ${chatId}.{hash}
        token_without_dollar = token[1:]  # Remove $
        parts = token_without_dollar.split(".@", 1)
        if len(parts) != 2:
            connection.send("join", b"invalid_token")
            return False

        provided_hash, chat_id = parts

        # Generate expected hash and compare
        expected_hash = generate_chat_join_token_hash(chat_id)
        if not expected_hash:
            connection.send("join", b"secret_fail")
            return False

        if provided_hash != expected_hash:
            connection.send("join", b"invalid_token")
            return False

        # Check if user is already a member
        members = GetChatMembersQuery().execute(chat_id)
        if connection.uid in members:
            connection.send("join", b"already_member")
            return True

        # Join the chat
        success = JoinChatCommand().execute(chat_id, connection.uid)
        if not success:
            connection.send("join", b"join_failed")
            return False

        # Send updated chat list
        connection.send("join", b"joined")
        ChatsController().handle(connection, "")
        return True


class ChatCreateController(Controller):
    def name(self):
        return "crtc"

    def handle(self, connection: Connection, payload: str) -> bool:
        chat_name = payload.strip()
        if not chat_name:
            connection.send("crtc", b"invalid_name")
            return False

        # Create the chat
        chat_id = CreateChatCommand().execute(chat_name, connection.uid)
        if not chat_id:
            connection.send("crtc", b"create_failed")
            return False

        # Send success response with chat ID
        connection.send("crtc", f"created:{chat_id}".encode())

        # Refresh chat list
        ChatsController().handle(connection, "")
        return True


class AssertionSendController(Controller):
    def name(self):
        return "assr"

    def handle(self, connection: Connection, payload: str) -> bool:
        # Parse payload: "chatId,2025-06-10T00:00:00.000,2025-06-11T00:00:00.000,Ophir will cancel tomorrow's lesson"
        parts = payload.strip().split(",", 3)
        if len(parts) != 4:
            connection.send("assr", b"invalid_format")
            return False

        chat_id, validation_date, casting_deadline, text = parts

        if not chat_id or not validation_date or not casting_deadline or not text:
            connection.send("assr", b"missing_fields")
            return False

        # Check if user is a member of this chat
        members = GetChatMembersQuery().execute(chat_id)
        if connection.uid not in members:
            connection.send("assr", b"not_member")
            return False

        # Create the assertion
        assertion_id = CreateAssertionCommand().execute(
            connection.uid, text, validation_date, casting_deadline
        )

        if not assertion_id:
            connection.send("assr", b"create_failed")
            return False

        # Add assertion ID as a message to the chat
        success = AppendChatMessageCommand().execute(
            chat_id, int(assertion_id))  # type: ignore
        if not success:
            connection.send("assr", b"message_failed")
            return False

        # Broadcast to other members
        # recipients = [uid for uid in members if uid != connection.uid]
        recipients = members.copy()

        # Get the formatted assertion data like MessagesController does
        assertion_data = GetAssertionQuery().execute(assertion_id)

        event_framework.emit_event({
            "prefix": "newm",
            "data": chat_id.encode() + b"," + json.dumps(assertion_data).encode(),
            "recipients": recipients,
        })

        connection.send("assr", f"created:{assertion_id}".encode())
        return True
