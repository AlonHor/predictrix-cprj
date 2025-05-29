import socket
from Crypto.Cipher import AES


class Connection():
    def __init__(self, conn: socket.socket, addr: tuple[str, int]):
        self.uid = ""
        self.conn = conn
        self.addr = addr
        self.aes_cipher = None
        self.session_key: bytes = b""  # store raw AES key for decrypt
        self.conn.settimeout(5)
        self.conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    def send(self, data: bytes):
        if self.session_key:
            cipher = AES.new(self.session_key, AES.MODE_GCM)
            ciphertext, tag = cipher.encrypt_and_digest(data)
            data = cipher.nonce + ciphertext + tag  # type: ignore
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
            # print(
            #     f"[DEBUG] Frame parts - payload_len={len(payload)}, nonce={nonce.hex()}, tag={tag.hex()}, ciphertext_len={len(ciphertext)}")
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
    
    def set_uid(self, uid: str):
        self.uid = uid

    def close(self):
        if self.conn:
            self.conn.shutdown(socket.SHUT_RDWR)
        self.conn.close()
