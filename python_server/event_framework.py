from queue import Queue
from typing import Dict, List
from connection import Connection
import time

# Thread-safe queue for events
event_queue: Queue = Queue()

# Mapping of user IDs to their active connections
user_connections: Dict[str, List[Connection]] = {}


def register_connection(uid: str, conn: Connection):
    """
    Register a user's connection for event dispatch.
    """
    conns = user_connections.setdefault(uid, [])
    if conn not in conns:
        conns.append(conn)


def unregister_connection(uid: str, conn: Connection):
    """
    Unregister a user's connection when it closes.
    """
    conns = user_connections.get(uid)
    if conns and conn in conns:
        conns.remove(conn)
        if not conns:
            del user_connections[uid]


def emit_event(event: dict):
    """
    Enqueue a new event to be dispatched.

    Event dict keys:
        - 'prefix': 4-char command prefix
        - 'data': bytes payload
        - 'recipients': list of user IDs to notify
    """
    event_queue.put(event)


def process_events():
    """
    Background worker to process and dispatch events.
    """
    while True:
        event = event_queue.get()
        if event is None:
            break
        time.sleep(0.01)
        try:
            prefix = event.get('prefix', '')
            data = event.get('data', b'')
            recipients = event.get('recipients', [])
            for uid in recipients:
                conns = user_connections.get(uid, [])
                for conn in conns:
                    try:
                        conn.send(prefix, data)
                    except Exception as e:
                        print(f"Error sending event to {uid}: {e}")
        finally:
            event_queue.task_done()
