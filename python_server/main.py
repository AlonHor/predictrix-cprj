import socket
import threading
import controllers
from connection import Connection
import event_framework

from Crypto.PublicKey import RSA
from Crypto.Cipher import AES, PKCS1_OAEP
from Crypto.Random import get_random_bytes


controller_instances = {inst.name(
): inst for cls in controllers.Controller.__subclasses__() for inst in [cls()]}

s = socket.socket()
s.bind(("0.0.0.0", 32782))

s.listen(5)
print("Server is listening on port 32782...")

# Start background event processing thread
event_thread = threading.Thread(
    target=event_framework.process_events,
    name="EventProcessor",
    daemon=True
)
event_thread.start()


def key_exchange(connection: Connection):
    rsa_key = RSA.generate(2048)
    pub = rsa_key.publickey()
    connection.send("", pub.export_key(format="PEM"))

    encrypted_session_key = b""
    reattempt = 0
    while len(encrypted_session_key) != 256 and reattempt < 5:
        encrypted_session_key = connection.recv()
        print(
            f"Encrypted session key length: {len(encrypted_session_key)}")
        reattempt += 1
    session_key = PKCS1_OAEP.new(rsa_key).decrypt(encrypted_session_key)

    # Generate fresh 16-byte nonce and send raw so Dart client can read
    final_nonce = get_random_bytes(16)
    aes = AES.new(session_key, AES.MODE_GCM, nonce=final_nonce)
    connection.conn.send(len(final_nonce).to_bytes(4, 'big'))
    connection.conn.send(final_nonce)
    connection.set_aes_cipher(aes, session_key)


def handle_client(connection: Connection):
    print(f"Connection from {connection.addr} has been established.")
    try:
        key_exchange(connection)
    except:
        connection.close()
        print(
            f"Key exchange failed with {connection.addr}. Closing connection.")
        return
    print(f"Key exchange successful with {connection.addr}.")

    # token = connection.recv().decode()
    # print(f"Token received from {connection.addr}: {token}")

    connection.conn.settimeout(None)

    while True:
        data = connection.recv()
        if not data or data == b"":
            break

        decoded = data.decode()
        cmd = decoded[:4].lower()
        payload = decoded[4:]

        # print(f"\n{'-'*100}")

        print(
            f"Received from {connection.addr}: {cmd}___{payload[:50]}{'...' if len(payload) > 50 else ''}")

        endpoint = controller_instances.get(cmd)
        if endpoint:
            endpoint.handle(connection, payload)
        else:
            print(f"Unknown command from {connection.addr}: {decoded}")
            connection.send("", b"what")

        # print(f"{'-'*100}\n")

    # Unregister connection before closing if authenticated
    if connection.uid:
        event_framework.unregister_connection(connection.uid, connection)

    try:
        connection.close()
    except:
        pass
    print(f"Connection from {connection.addr} has been closed.")


try:
    while True:
        conn, addr = s.accept()
        connection = Connection(conn, addr)
        client_thread = threading.Thread(
            target=handle_client, args=(connection,), name=f"ClientThread-{addr[0]}:{addr[1]}", daemon=True)
        client_thread.start()
        print(f"Active connections: {threading.active_count() - 2}")
except KeyboardInterrupt:
    print("Server is shutting down.")
    s.close()
