from abc import ABC, abstractmethod


class Endpoint(ABC):
    @abstractmethod
    def name(self) -> str:
        """
        Returns the 4-letter command name for this endpoint.
        """
        pass

    @abstractmethod
    def handle(self, connection, payload: str) -> bool:
        """
        Handle the request. Return True to continue the loop, False to close the connection.
        """
        pass


class PingEndpoint(Endpoint):
    def name(self):
        return "ping"

    def handle(self, connection, payload: str) -> bool:
        print(f"Ping received from {connection.addr}.")
        connection.send(b"pong")
        return True


class ChatsEndpoint(Endpoint):
    def name(self):
        return "chts"

    def handle(self, connection, payload: str) -> bool:
        print(f"Client {connection.addr} requested chat list.")
        connection.send(b"chat1,chat2,chat3")
        return True


class MsgsEndpoint(Endpoint):
    def name(self):
        return "msgs"

    def handle(self, connection, payload: str) -> bool:
        chat_id = payload.strip()
        print(
            f"Client {connection.addr} requested messages for chat {chat_id}.")
        connection.send(b"msg1,msg2,msg3")
        return False
