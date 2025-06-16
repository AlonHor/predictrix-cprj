from abc import ABC, abstractmethod
from connection import Connection
from commands import CreateUserCommand, AppendChatMessageCommand, JoinChatCommand, CreateChatCommand
from commands import CreateAssertionCommand, AddPredictionCommand, AddVoteCommand
from queries import GetChatsQuery, GetChatMembersQuery, GetChatMessagesQuery, GetUserProfileQuery, GetChatStatsQuery
from queries import GetAssertionQuery
from message_sender import send_message
import event_framework
import datetime
import json
import hashlib
import os
import threading
import base64


# Global dictionary to store locks per chat_id
_chat_locks: dict[str, threading.Lock] = {}
_chat_locks_lock = threading.Lock()  # Lock to protect the locks dictionary


def get_chat_lock(chat_id: str) -> threading.Lock:
    """
    Get or create a lock for the specified chat_id.
    Thread-safe creation ensures only one lock per chat_id.
    """
    with _chat_locks_lock:
        if chat_id not in _chat_locks:
            _chat_locks[chat_id] = threading.Lock()
        return _chat_locks[chat_id]


def generate_chat_join_token_hash(chat_id: str) -> str | None:
    """
    Generate a short hash for a chat join token using the chat ID and secret.
    """
    secret_code = os.environ.get("CJTK_SECRET", None)
    if not secret_code:
        return None
    hash_input = chat_id + secret_code
    hash_obj = hashlib.sha256(hash_input.encode())
    return base64.b64encode(hash_obj.digest())[:16].decode()


def generate_chat_topic(chat_id: str) -> str | None:
    """
    Generate a topic name for a chat based on its ID.
    """
    secret_code = os.environ.get("CJTK_SECRET", None)
    if not secret_code:
        return None
    hash_input = str(chat_id) + secret_code
    hash_obj = hashlib.sha256(hash_input.encode())
    return f"chat_{hash_obj.hexdigest()[:64]}"


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
        } for chat in chats])

        connection.send("chts", chats_json.encode())
        topics = [
            generate_chat_topic(chat["Id"]) for chat in chats
        ]

        if topics:
            connection.send("tpcs", json.dumps(topics).encode())

        return True


class MessagesController(Controller):
    def name(self):
        return "msgs"

    def handle(self, connection: Connection, payload: str) -> bool:
        # Send the last X messages for the given chat
        chat_id = payload.strip()

        with get_chat_lock(chat_id):
            # Check if user is a member of this chat
            members = GetChatMembersQuery().execute(chat_id)
            if connection.uid not in members:
                connection.send("msgs", b"not_member")
                return False

            messages = GetChatMessagesQuery().execute(chat_id)
            last_x = messages[-500:]
            # Enrich sender with profile (displayName, photoUrl)
            for msg in last_x:
                if isinstance(msg, dict) and msg.get("sender"):
                    profile = GetUserProfileQuery().execute(msg["sender"])
                    msg["sender"] = profile
                elif isinstance(msg, (int, str)) and str(msg).isdigit():
                    # This is an assertion ID, replace with assertion data
                    assertion_data = GetAssertionQuery().execute(str(msg), connection.uid)
                    if assertion_data:
                        last_x[last_x.index(msg)] = assertion_data
            connection.send(f"msgs{chat_id},", json.dumps(last_x).encode())
            return True


class MembersController(Controller):
    def name(self):
        return "memb"

    def handle(self, connection: Connection, payload: str) -> bool:
        # Send the members of the given chat
        chat_id = payload.strip()

        with get_chat_lock(chat_id):
            members = GetChatMembersQuery().execute(chat_id)

            if not members:
                connection.send("memb", b"no_members")
                return True

            # Fetch chat stats for ELO calculation
            score_map, pred_map = GetChatStatsQuery().execute(chat_id)
            result: list[dict[str, int | str]] = []

            for uid in members:
                profile = GetUserProfileQuery().execute(uid)
                name = profile.get("displayName") or uid
                preds = pred_map.get(uid, 0)
                score = score_map.get(uid, 0)
                elo = int(score / preds) if preds > 0 else 500
                result.append({
                    "displayName": name,
                    "photoUrl": profile.get("photoUrl", ""),
                    "elo": elo
                })

            # Sort members by ELO score in descending order
            result.sort(key=lambda m: m["elo"], reverse=True)

            connection.send("memb", chat_id.encode() +
                            b"," + json.dumps(result).encode())
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

        with get_chat_lock(chat_id):
            # Use display name as sender
            print("TIMESTAMP:", datetime.datetime.now(
                datetime.timezone.utc).isoformat())
            msg_obj = {
                "sender": connection.uid,
                "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
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

            # Embed full sender profile in event data
            profile = GetUserProfileQuery().execute(connection.uid)

            event_msg_obj = {
                **msg_obj,
                "sender": profile,
            }

            event_framework.emit_event({
                "prefix": "newm",
                "data": chat_id.encode() + b"," + json.dumps(event_msg_obj).encode(),
                "recipients": recipients,
            })

            topic = generate_chat_topic(chat_id)
            if topic:
                send_message(topic, text, profile)

            connection.send("sndm", b"ok")
            return True


class UserController(Controller):
    def name(self):
        return "user"

    def handle(self, connection: Connection, payload: str) -> bool:
        print(f"Adding user...")
        uid, display_name = CreateUserCommand().execute(payload)
        if uid == "":
            print(f"Failed to add user with token: {payload}")
            connection.send("", b"token_fail")
            return False

        connection.set_uid(uid)
        connection.send("token_ok", display_name.encode())
        ChatsController().handle(connection, "")
        return True


class ChatJoinTokenGeneratorController(Controller):
    def name(self):
        return "cjtk"

    def handle(self, connection: Connection, payload: str) -> bool:
        chat_id = payload.strip()
        if not chat_id:
            connection.send("cjtk", b"invalid_chat_id")
            return False

        with get_chat_lock(chat_id):
            # Check if user is a member of this chat
            members = GetChatMembersQuery().execute(chat_id)
            if connection.uid not in members:
                return False

            # Generate token: ${chatId}.{short_hash}
            short_hash = generate_chat_join_token_hash(chat_id)
            if not short_hash:
                connection.send("cjtk", b"secret_fail")
                return False
            token = f"{short_hash}.{base64.b64encode(chat_id.encode()).decode()}"

            connection.send("cjtk", token.encode())
            return True


class ChatJoinTokenController(Controller):
    def name(self):
        return "join"

    def handle(self, connection: Connection, payload: str) -> bool:
        token = payload.strip()
        if "." not in token:
            connection.send("join", b"invalid_token")
            return False

        parts = token.split(".", 1)
        if len(parts) != 2:
            connection.send("join", b"invalid_token")
            return False

        provided_hash, chat_id = parts
        chat_id = base64.b64decode(chat_id).decode()

        # Generate expected hash and compare
        expected_hash = generate_chat_join_token_hash(chat_id)
        if not expected_hash:
            connection.send("join", b"secret_fail")
            return False

        if provided_hash != expected_hash:
            connection.send("join", b"invalid_token")
            return False

        with get_chat_lock(chat_id):
            # Check if user is already a member
            members = GetChatMembersQuery().execute(chat_id)
            if connection.uid in members:
                connection.send("join", b"already_member")
                return True

            # Join the chat
            success = JoinChatCommand().execute(chat_id, connection.uid)
            if not success:
                connection.send("join", b"join_failed")
                return False

            # Send updated chat list
            connection.send("join", b"joined")
            ChatsController().handle(connection, "")
            return True


class ChatCreateController(Controller):
    def name(self):
        return "crtc"

    def handle(self, connection: Connection, payload: str) -> bool:
        chat_name = payload.strip()
        if not chat_name:
            connection.send("crtc", b"invalid_name")
            return False

        # Create the chat
        chat_id = CreateChatCommand().execute(chat_name, connection.uid)
        if not chat_id:
            connection.send("crtc", b"create_failed")
            return False

        # Send success response with chat ID
        connection.send("crtc", f"created:{chat_id}".encode())

        # Refresh chat list
        ChatsController().handle(connection, "")
        return True


class AssertionSendController(Controller):
    def name(self):
        return "assr"

    def handle(self, connection: Connection, payload: str) -> bool:
        # Parse payload: "chatId,2025-06-10T00:00:00.000,2025-06-11T00:00:00.000,Ophir will cancel tomorrow's lesson"
        parts = payload.strip().split(",", 3)
        if len(parts) != 4:
            connection.send("assr", b"invalid_format")
            return False

        chat_id, validation_date, casting_deadline, text = parts

        if not chat_id or not validation_date or not casting_deadline or not text:
            connection.send("assr", b"missing_fields")
            return False

        with get_chat_lock(chat_id):
            # Check if user is a member of this chat
            members = GetChatMembersQuery().execute(chat_id)
            if connection.uid not in members:
                connection.send("assr", b"not_member")
                return False

            # Validate dates
            try:
                now = datetime.datetime.now(datetime.timezone.utc)

                casting_dt = datetime.datetime.fromisoformat(
                    casting_deadline.replace('Z', '+00:00'))
                validation_dt = datetime.datetime.fromisoformat(
                    validation_date.replace('Z', '+00:00'))

                # Casting deadline must be after now
                if casting_dt <= now:
                    connection.send("assr", b"casting_deadline_past")
                    return False

                # Validation date must be after casting deadline
                if validation_dt <= casting_dt:
                    connection.send("assr", b"validation_before_casting")
                    return False

            except ValueError as e:
                connection.send("assr", b"invalid_date_format")
                return False

            # Create the assertion
            assertion_id = CreateAssertionCommand().execute(
                connection.uid, chat_id, text, validation_date[:-
                                                               1], casting_deadline[:-1]
            )

            if not assertion_id:
                connection.send("assr", b"create_failed")
                return False

            # Add assertion ID as a message to the chat
            success = AppendChatMessageCommand().execute(
                chat_id, int(assertion_id))  # type: ignore
            if not success:
                connection.send("assr", b"message_failed")
                return False

            recipients = members.copy()
            assertion_data = GetAssertionQuery().execute(assertion_id, connection.uid)

            event_framework.emit_event({
                "prefix": "newm",
                "data": chat_id.encode() + b"," + json.dumps(assertion_data).encode(),
                "recipients": recipients,
            })

            send_message(chat_id, text,
                         GetUserProfileQuery().execute(connection.uid))

            connection.send("assr", f"created:{assertion_id}".encode())
            return True


class PredictionController(Controller):
    def name(self):
        return "pred"

    def handle(self, connection: Connection, payload: str) -> bool:
        # Parse payload: "assertionId,confidence,forecast"
        parts = payload.strip().split(",", 2)
        if len(parts) != 3:
            connection.send("pred", b"invalid_format")
            return False

        assertion_id, confidence_str, forecast_str = parts

        if not assertion_id:
            connection.send("pred", b"missing_assertion_id")
            return False

        # Get chat ID from assertion
        assertion_result = GetAssertionQuery().execute(assertion_id, None)
        assertion_data = assertion_result.get("content", {})
        chat_id = assertion_data.get("chatId", "0")
        if not chat_id or chat_id == "0":
            connection.send("pred", b"invalid_chat_id")
            return False

        with get_chat_lock(chat_id):
            members = GetChatMembersQuery().execute(chat_id)
            if connection.uid not in members:
                connection.send("pred", b"not_member")
                return False

            # Check if assertion is already complete
            if assertion_data.get("completed", False):
                connection.send("pred", b"assertion_complete")
                return False

            # Check if casting deadline has passed
            try:
                now = datetime.datetime.now(datetime.timezone.utc)
                casting_deadline = assertion_data.get(
                    "castingForecastDeadline", "")
                if casting_deadline:
                    casting_dt = datetime.datetime.fromisoformat(
                        casting_deadline.replace('Z', '+00:00'))
                    if now >= casting_dt:
                        connection.send("pred", b"casting_deadline_passed")
                        return False
            except ValueError:
                connection.send("pred", b"invalid_casting_deadline")
                return False

            try:
                confidence = float(confidence_str)
                if not (0.0 <= confidence <= 1.0):
                    connection.send("pred", b"invalid_confidence")
                    return False
            except ValueError:
                connection.send("pred", b"invalid_confidence")
                return False

            try:
                forecast = forecast_str.lower() == "true"
            except:
                connection.send("pred", b"invalid_forecast")
                return False

            # Add prediction to assertion
            success = AddPredictionCommand().execute(
                assertion_id, connection.uid, confidence, forecast
            )

            if not success:
                connection.send("pred", b"add_failed")
                return False

            # Update assertion data locally with the new prediction
            user_profile = GetUserProfileQuery().execute(connection.uid)
            new_prediction = {
                "displayName": user_profile.get("displayName", ""),
                "photoUrl": user_profile.get("photoUrl", ""),
                "confidence": confidence,
                "forecast": forecast
            }

            # Add the new prediction to the existing predictions list
            if not isinstance(assertion_data.get("predictions"), list):
                assertion_data["predictions"] = []
            assertion_data["predictions"].append(new_prediction)

            recipients = [uid for uid in members if uid != connection.uid]

            event_framework.emit_event({
                "prefix": "assr",
                "data": f"{json.dumps(assertion_data)}".encode(),
                "recipients": recipients,
            })

            assertion_data["didPredict"] = True
            event_framework.emit_event({
                "prefix": "assr",
                "data": f"{json.dumps(assertion_data)}".encode(),
                "recipients": [connection.uid],
            })

            connection.send("pred", b"added")
            return True


class VoteController(Controller):
    def name(self):
        return "vote"

    def handle(self, connection: Connection, payload: str) -> bool:
        parts = payload.strip().split(",", 1)
        if len(parts) != 2:
            connection.send("vote", b"invalid_format")
            return True

        assertion_id, vote_str = parts

        if not assertion_id or vote_str not in ["true", "false"]:
            connection.send("vote", b"invalid_data")
            return True

        vote = vote_str.lower() == "true"

        # Get assertion data to check validation date
        assertion_query = GetAssertionQuery()
        assertion_data = assertion_query.execute(
            assertion_id, None)

        if not assertion_data:
            connection.send("vote", b"assertion_not_found")
            return True

        # Check if assertion is completed
        if assertion_data.get("content", {}).get("completed", False):
            connection.send("vote", b"assertion_completed")
            return True

        # Check if we're past validation date
        validation_date_str: str = assertion_data.get(
            "content", {}).get("validationDate", "")
        if not validation_date_str:
            connection.send("vote", b"no_validation_date")
            return True

        try:
            validation_date = datetime.datetime.fromisoformat(
                validation_date_str.replace('Z', '+00:00'))
            now = datetime.datetime.now(datetime.timezone.utc)

            if now <= validation_date:
                connection.send("vote", b"voting_not_open")
                return True
        except ValueError:
            connection.send("vote", b"invalid_validation_date")
            return True

        # Check if user is a member of the chat
        chat_id = assertion_data.get("content", {}).get("chatId", "")
        if not chat_id:
            connection.send("vote", b"invalid_chat")
            return True

        with get_chat_lock(chat_id):
            members = GetChatMembersQuery().execute(chat_id)
            if connection.uid not in members:
                connection.send("vote", b"not_member")
                return True

            # Add the vote
            add_vote_command = AddVoteCommand()
            success = add_vote_command.execute(
                assertion_id, connection.uid, bool(vote))

            if not success:
                connection.send("vote", b"vote_failed")
                return True

            # Get updated assertion data and emit to all members
            updated_assertion_data = assertion_query.execute(
                assertion_id, None)

            # Emit to all chat members
            event_framework.emit_event({
                "prefix": "assr",
                "data": f"{json.dumps(updated_assertion_data['content'])}".encode(),
                "recipients": members,
            })

            connection.send("vote", b"voted")
            return True
