from abc import ABC, abstractmethod
from connection import Connection
from db import add_user, get_chats
import json


class Endpoint(ABC):
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


class PingEndpoint(Endpoint):
    def name(self):
        return "ping"

    def handle(self, connection: Connection, payload: str) -> bool:
        print(f"Ping received from {connection.addr}.")
        connection.send(b"pong")
        return True


class ChatsEndpoint(Endpoint):
    def name(self):
        return "chts"

    def handle(self, connection: Connection, payload: str) -> bool:
        print(f"Client {connection.addr} requested chat list.")
        chats = get_chats(connection.uid)
        chats_json = json.dumps([{"name": chat["Name"], "lastMessage": chat["LastMessage"], "chatId": str(chat["Id"]), "type": chat["Type"], "iconColor": "blue"} for chat in chats])
        connection.send(chats_json.encode())
        return True


class MsgsEndpoint(Endpoint):
    def name(self):
        return "msgs"

    def handle(self, connection: Connection, payload: str) -> bool:
        chat_id = payload.strip()
        print(
            f"Client {connection.addr} requested messages for chat {chat_id}.")
        connection.send(b"msg1,msg2,msg3")
        return False


class UserEndpoint(Endpoint):
    def name(self):
        return "user"

    def handle(self, connection: Connection, payload: str) -> bool:
        print(f"User data received from {connection.addr}: {payload}")

        payload_data = payload.split(",")
        if len(payload_data) != 4:
            print(
                f"Invalid user data format from {connection.addr}: {payload}")
            connection.send(b"invalid_data")
            return False

        uid, display_name, email, photo_url = payload_data

        print(f"Adding user: {uid}, {display_name}, {email}, {photo_url}")
        add_user(uid, display_name, email, photo_url)

        connection.set_uid(uid)
        connection.send(b"token_ok")
        return True
