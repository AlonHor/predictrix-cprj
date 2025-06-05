from abc import ABC, abstractmethod
from connection import Connection
from commands import CreateUserCommand
from queries import GetChatsQuery
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
        connection.send(b"pong")
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
            connection.send(json.dumps([]).encode())
            return True

        chats_json = json.dumps([{
            "name": chat["Name"],
            "lastMessage": chat["LastMessage"],
            "chatId": str(chat["Id"]),
            "type": chat["Type"],
            "iconColor": "blue"
        } for chat in chats])
        connection.send(chats_json.encode())
        return True


class MessagesController(Controller):
    def name(self):
        return "msgs"

    def handle(self, connection: Connection, payload: str) -> bool:
        chat_id = payload.strip()
        print(
            f"Client {connection.addr} requested messages for chat {chat_id}.")
        connection.send(b"msg1,msg2,msg3")
        return False


class UserController(Controller):
    def name(self):
        return "user"

    def handle(self, connection: Connection, payload: str) -> bool:
        print(f"Adding user...")
        uid = CreateUserCommand().execute(payload)
        if uid == "":
            print(f"Failed to add user with token: {payload}")
            connection.send(b"token_fail")
            return False

        connection.set_uid(uid)
        connection.send(b"token_ok")
        return True
