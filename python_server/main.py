import socket
import threading
import endpoints
from connection import Connection

from Crypto.PublicKey import RSA
from Crypto.Cipher import AES, PKCS1_OAEP
from Crypto.Random import get_random_bytes


endpoint_instances = {inst.name(
): inst for cls in endpoints.Endpoint.__subclasses__() for inst in [cls()]}

s = socket.socket()
s.bind(("0.0.0.0", 32782))

s.listen(5)
print("Server is listening on port 32782...")


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

    # token = connection.recv().decode()
    # print(f"Token received from {connection.addr}: {token}")

    connection.conn.settimeout(None)

    while True:
        data = connection.recv()
        if not data:
            break

        decoded = data.decode()
        cmd = decoded[:4].lower()
        payload = decoded[4:]

        # print(f"\n{'-'*100}")

        print(f"Received from {connection.addr}: {decoded}")

        endpoint = endpoint_instances.get(cmd)
        if endpoint:
            cont = endpoint.handle(connection, payload)
            if not cont:
                break
        else:
            print(f"Unknown command from {connection.addr}: {decoded}")
            connection.send(b"what")

        # print(f"{'-'*100}\n")

    connection.close()
    print(f"Connection from {connection.addr} has been closed.")


try:
    while True:
        conn, addr = s.accept()
        connection = Connection(conn, addr)
        client_thread = threading.Thread(
            target=handle_client, args=(connection,), name=f"ClientThread-{addr[0]}:{addr[1]}", daemon=True)
        client_thread.start()
        print(f"Active connections: {threading.active_count() - 1}")
except KeyboardInterrupt:
    print("Server is shutting down.")
    s.close()
