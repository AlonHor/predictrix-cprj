import socket
import threading
import endpoints

from Crypto.PublicKey import RSA
from Crypto import Random
from Crypto.Cipher import AES, PKCS1_OAEP

endpoint_instances = {inst.name(
): inst for cls in endpoints.Endpoint.__subclasses__() for inst in [cls()]}

s = socket.socket()
s.bind(("0.0.0.0", 32782))

s.listen(5)
print("Server is listening on port 32782...")


class Connection():
    def __init__(self, conn: socket.socket, addr: tuple[str, int]):
        self.conn = conn
        self.addr = addr
        self.aes_cipher = None
        self.conn.settimeout(5)

    def send(self, data: bytes):
        if self.aes_cipher:
            ciphertext, tag = self.aes_cipher.encrypt_and_digest(data)
            data = self.aes_cipher.nonce + tag + ciphertext
        size = len(data)
        self.conn.send(size.to_bytes(4, 'big'))
        self.conn.send(data)

    def recv(self):
        size = int.from_bytes(self.conn.recv(4), 'big')
        if size == 0:
            return b""
        payload = self.conn.recv(size)
        if self.aes_cipher:
            nonce = payload[:16]
            tag = payload[16:32]
            ct = payload[32:]
            cipher = AES.new(self.aes_cipher.key, AES.MODE_EAX, nonce=nonce)
            return cipher.decrypt_and_verify(ct, tag)
        return payload

    def set_aes_cipher(self, aes_cipher):
        self.aes_cipher = aes_cipher

    def close(self):
        if self.conn:
            self.conn.shutdown(socket.SHUT_RDWR)
        self.conn.close()


def key_exchange(connection: Connection):
    rsa_key = RSA.generate(2048, Random.new().read)
    pub = rsa_key.publickey()
    connection.send(pub.export_key(format="PEM"))

    encrypted_session_key = connection.recv()
    session_key = PKCS1_OAEP.new(rsa_key).decrypt(encrypted_session_key)

    aes = AES.new(session_key, AES.MODE_EAX)
    connection.set_aes_cipher(aes)
    connection.send(aes.nonce)


def handle_client(connection: Connection):
    print(f"Connection from {connection.addr} has been established.")
    key_exchange(connection)

    token = connection.recv().decode()
    print(f"Token received from {connection.addr}: {token}")

    while True:
        data = connection.recv()
        if not data:
            break

        decoded = data.decode()
        cmd = decoded[:4].lower()
        payload = decoded[4:]
        print(f"Received from {connection.addr}: {decoded}")

        endpoint = endpoint_instances.get(cmd)
        if endpoint:
            cont = endpoint.handle(connection, payload)
            if not cont:
                break
        else:
            print(f"Unknown command from {connection.addr}: {decoded}")
            connection.send(b"what")

    connection.close()
    print(f"Connection from {connection.addr} has been closed.")


while True:
    conn, addr = s.accept()
    connection = Connection(conn, addr)
    client_thread = threading.Thread(target=handle_client, args=(connection,))
    client_thread.start()
    print(f"Active connections: {threading.active_count() - 1}")
