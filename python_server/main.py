import socket
import threading
import endpoints

from Crypto.PublicKey import RSA
from Crypto.Cipher import AES, PKCS1_OAEP
from Crypto.Random import get_random_bytes


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
        self.session_key: bytes = b""  # store raw AES key for decrypt
        self.conn.settimeout(5)
        self.conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    def send(self, data: bytes):
        if self.aes_cipher:
            # AEAD encrypt: frame as nonce||ciphertext||tag (nonce is 16 bytes)
            ciphertext, tag = self.aes_cipher.encrypt_and_digest(data)
            data = self.aes_cipher.nonce + ciphertext + tag
        size = len(data)
        self.conn.send(size.to_bytes(4, 'big'))
        self.conn.send(data)

    def recv(self):
        # read 4-byte length header fully
        header = b""
        while len(header) < 4:
            chunk = self.conn.recv(4 - len(header))
            if not chunk:
                return b""
            header += chunk
        size = int.from_bytes(header, 'big')
        if size == 0:
            return b""
        # read the full payload
        payload = b""
        while len(payload) < size:
            chunk = self.conn.recv(size - len(payload))
            if not chunk:
                break
            payload += chunk
        # decrypt if AES session established
        if self.session_key and self.aes_cipher:
            # fixed nonce length of 16 bytes
            nonce = payload[:16]
            ciphertext = payload[16:-16]
            tag = payload[-16:]
            print(
                f"[DEBUG] Frame parts - payload_len={len(payload)}, nonce={nonce.hex()}, tag={tag.hex()}, ciphertext_len={len(ciphertext)}")
            try:
                cipher = AES.new(self.session_key, AES.MODE_GCM, nonce=nonce)
                return cipher.decrypt_and_verify(ciphertext, tag)
            except Exception as e:
                print(f"[DEBUG] Decrypt error: {e}")
                raise
        return payload

    def set_aes_cipher(self, aes_cipher, key: bytes):
        """Store the AES-GCM cipher and raw key for encrypt/decrypt operations."""
        self.aes_cipher = aes_cipher
        self.session_key = key
        print(
            f"[DEBUG] Session key set ({len(key)} bytes), using nonce: {aes_cipher.nonce.hex()}")

    def close(self):
        if self.conn:
            self.conn.shutdown(socket.SHUT_RDWR)
        self.conn.close()


def key_exchange(connection: Connection):
    rsa_key = RSA.generate(2048)
    pub = rsa_key.publickey()
    connection.send(pub.export_key(format="PEM"))

    encrypted_session_key = connection.recv()
    session_key = PKCS1_OAEP.new(rsa_key).decrypt(encrypted_session_key)

    # Generate fresh 16-byte nonce and send raw so Dart client can read
    final_nonce = get_random_bytes(16)
    aes = AES.new(session_key, AES.MODE_GCM, nonce=final_nonce)
    connection.conn.send(len(final_nonce).to_bytes(4, 'big'))
    connection.conn.send(final_nonce)
    connection.set_aes_cipher(aes, session_key)


def handle_client(connection: Connection):
    print(f"Connection from {connection.addr} has been established.")
    key_exchange(connection)

    token = connection.recv().decode()
    print(f"Token received from {connection.addr}: {token}")

    connection.conn.settimeout(None)

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
