from abc import ABC, abstractmethod
from connection import Connection
from commands import CreateUserCommand, AppendChatMessageCommand
from queries import GetChatsQuery, GetChatMembersQuery, GetChatMessagesQuery
from queries import GetUserDisplayNameQuery
import event_framework
import datetime
import json


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
        messages = GetChatMessagesQuery().execute(chat_id)
        last50 = messages[-50:]
        # Replace sender UID with display name
        for msg in last50:
            if isinstance(msg, dict) and msg.get("sender"):
                disp = GetUserDisplayNameQuery().execute(msg["sender"])
                msg["sender"] = disp or msg["sender"]
        connection.send(f"msgs{chat_id},", json.dumps(last50).encode())
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

        sender_name = GetUserDisplayNameQuery().execute(connection.uid)
        msg_obj["sender"] = sender_name if sender_name else connection.uid

        event_framework.emit_event({
            "prefix": "newm",
            # include display-name-based sender
            "data": chat_id.encode() + b"," + json.dumps(msg_obj).encode(),
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
