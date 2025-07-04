import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:predictrix/redux/types/assertion.dart';
import 'package:predictrix/redux/types/chat_message.dart';
import 'package:predictrix/redux/types/chat_tile.dart';
import 'package:predictrix/redux/types/member.dart';
import 'package:predictrix/utils/encryption_utils.dart';
import 'package:predictrix/redux/reducers.dart';
import 'package:redux/redux.dart';

class SocketService with WidgetsBindingObserver {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  SocketService._internal();

  final String host = "34.22.247.161";
  final int port = 32782;
  Socket? _socket;
  bool _connecting = false;
  Uint8List? _buffer;

  String token = '';
  AesCrypt? _aes;

  Store<AppState>? _store;

  void registerStore(Store<AppState> store) {
    _store = store;
  }

  Future<void> init(String token) async {
    this.token = token;

    WidgetsBinding.instance.addObserver(this);

    await _connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("App lifecycle state changed: $state");
    if (state == AppLifecycleState.resumed) {
      _checkConnectionAndReconnect();
    }
  }

  Future<void> _checkConnectionAndReconnect() async {
    if (_socket == null) {
      debugPrint("Socket is null, reconnecting");
      _handleDisconnect();
      return;
    }

    bool isValid = true;

    try {
      final remote = _socket!.remoteAddress;
      debugPrint("Socket connected to $remote:${_socket!.remotePort}");
    } catch (e) {
      debugPrint("Socket failed remote address check: $e");
      isValid = false;
    }

    if (isValid) {
      try {
        _socket!.write("");
      } catch (e) {
        debugPrint("Socket ping failed: $e");
        isValid = false;
      }
    }

    if (!isValid) {
      debugPrint("Socket appears invalid, reconnecting");
      _handleDisconnect();
    }
  }

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _socket != null;

  Future<void> _connect() async {
    if (_connecting) return;
    _connecting = true;
    while (_socket == null) {
      try {
        debugPrint("Connecting to $host:$port");
        _socket = await Socket.connect(host, port,
            timeout: const Duration(seconds: 5));
        // wrap socket data stream as broadcast of Uint8List
        final byteStream = _socket!
            .map((data) => Uint8List.fromList(data))
            .asBroadcastStream();
        // after raw connection, perform RSA/AES key exchange
        _aes =
            await EncryptionUtils.keyExchange(_socket!, dataStream: byteStream);
        debugPrint("Key exchange completed, AES established.");
        // send token encrypted
        send("user$token");
        byteStream.listen(
          (data) {
            _buffer ??= Uint8List(0);
            _buffer = Uint8List.fromList(_buffer! + data);

            while (_buffer!.length >= 4) {
              final sizeBytes = _buffer!.sublist(0, 4);
              final messageLength =
                  ByteData.sublistView(sizeBytes).getInt32(0, Endian.big);

              if (_buffer!.length < 4 + messageLength) break;

              final messageBytes = _buffer!.sublist(4, 4 + messageLength);
              // decrypt if AES established
              Uint8List payload = messageBytes;
              String text;
              if (_aes != null) {
                final dec = EncryptionUtils.decryptFrame(_aes!, payload);
                text = utf8.decode(dec);
              } else {
                text = utf8.decode(payload);
              }
              debugPrint("Received: $text");
              handleIncomingData(text);

              _buffer = _buffer!.sublist(4 + messageLength);
            }
          },
          onDone: _handleDisconnect,
          onError: (e) => _handleDisconnect(),
          cancelOnError: true,
        );
      } catch (e) {
        debugPrint("Connection failed: $e");
        _socket?.destroy();
        _socket = null;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    _connecting = false;
  }

  void send(String message) {
    if (_socket == null) {
      debugPrint("Cannot send: Socket is null, attempting to reconnect");
      _handleDisconnect();
      return;
    }

    try {
      final messageBytes = utf8.encode(message);
      if (_aes != null) {
        final frame = EncryptionUtils.encryptFrame(_aes!, messageBytes);
        EncryptionUtils.sendRaw(_socket!, frame);
      } else {
        final sizeBytes = ByteData(4)
          ..setInt32(0, messageBytes.length, Endian.big);
        _socket!.add(sizeBytes.buffer.asUint8List());
        _socket!.add(messageBytes);
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
      _handleDisconnect();
    }
  }

  void handleIncomingData(String data) {
    if (data.isEmpty) return;

    if (data.startsWith("token_ok")) {
      debugPrint("Token accepted by server, ready to send/receive messages.");
      _store?.dispatch(SetConnectionStatusAction(true));
      String displayName = data.substring("token_ok".length);
      _store?.dispatch(SetDisplayNameAction(displayName));
      return;
    } else if (data == "token_fail") {
      debugPrint("Token error, attempting to refresh token...");
      _store?.dispatch(SetConnectionStatusAction(false));

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        try {
          currentUser.getIdToken(true).then((newToken) {
            if (newToken != null && newToken.isNotEmpty) {
              debugPrint("Successfully refreshed token, reconnecting");
              token = newToken;
              _handleDisconnect();
              return;
            } else {
              debugPrint("Failed to refresh token (empty token)");
              _handleDisconnect();
            }
          }).catchError((error) {
            debugPrint("Error refreshing token: $error");
            _handleDisconnect();
          });
          return;
        } catch (e) {
          debugPrint("Exception while refreshing token: $e");
        }
      } else {
        debugPrint("Cannot refresh token: No user is signed in");
      }

      _handleDisconnect();
      return;
    }

    if (data.length >= 4) {
      final prefix = data.substring(0, 4);
      final content = data.substring(4);
      switch (prefix) {
        case 'chts':
          try {
            final decoded = jsonDecode(content);
            if (decoded is List) {
              final chats = decoded
                  .map(
                      (item) => ChatTile.fromJson(item as Map<String, dynamic>))
                  .toList();
              _store?.dispatch(SetChatsAction(chats));
            }
          } catch (e) {
            debugPrint("Error decoding JSON: $e");
          }
          return;
        case "tpcs":
          try {
            final decoded = jsonDecode(content);
            if (decoded is List) {
              final topics = decoded.map((item) => item.toString()).toList();
              // Unsubscribe from all previous topics
              debugPrint("Unsubscribing from all previous topics");
              FirebaseMessaging.instance.unsubscribeFromTopic('all').then((_) {
                debugPrint("Unsubscribed from all topics successfully");
              }).catchError((error) {
                debugPrint("Failed to unsubscribe from all topics: $error");
              });
              for (final topic in topics) {
                // Subscribe to each topic for push notifications
                debugPrint("Subscribing to topic: $topic");
                // Use FirebaseMessaging to subscribe to the topic
                FirebaseMessaging.instance
                    .subscribeToTopic(topic)
                    .then((_) {
                  debugPrint("Subscribed to $topic successfully");
                }).catchError((error) {
                  debugPrint("Failed to subscribe to $topic: $error");
                });
              }
            }
          } catch (e) {
            debugPrint("Error decoding topics JSON: $e");
          }
          return;
        case 'msgs':
          try {
            final parts = content.split(',');
            if (parts.length < 2) {
              debugPrint("Invalid messages format: $content");
              return;
            }
            final chatId = parts[0];
            final jsonContent = parts.sublist(1).join(",");
            final decoded = jsonDecode(jsonContent);
            if (decoded is List) {
              final messages = decoded
                  .map((item) =>
                      ChatMessage.fromJson(item as Map<String, dynamic>))
                  .toList();

              // If messages are assertions, convert them to IDs
              for (var message in messages) {
                if (message.type == 'assertion') {
                  final assertion = message.message as Assertion;
                  _store?.dispatch(SetAssertionAction(assertion.id, assertion));
                  message.message = assertion.id; // Store only ID in message
                }
              }

              _store?.dispatch(SetChatMessagesAction(chatId, messages));
            }
          } catch (e) {
            debugPrint("Error decoding messages JSON: $e");
          }
          return;
        case "newm":
          try {
            final parts = content.split(',');
            if (parts.length < 2) {
              debugPrint("Invalid new message format: $content");
              return;
            }
            final chatId = parts[0];
            final jsonContent = parts.sublist(1).join(",");
            final message = ChatMessage.fromJson(
                jsonDecode(jsonContent) as Map<String, dynamic>);

            if (message.type == 'assertion') {
              final assertion = message.message as Assertion;
              _store?.dispatch(SetAssertionAction(assertion.id, assertion));
              message.message = assertion.id; // Store only ID in message
            }

            _store?.dispatch(AddChatMessageAction(chatId, message));
          } catch (e) {
            debugPrint("Error decoding new message JSON: $e");
          } finally {
            _store?.dispatch(SetIsMessageSendingAction(false));
          }
          return;
        case "assr":
          try {
            if (content == "create_failed") {
              debugPrint("Assertion creation failed");
              _store?.dispatch(SetIsMessageSendingAction(false));
              return;
            }
            final jsonContent = content;
            final assertion = Assertion.fromJson(
                jsonDecode(jsonContent) as Map<String, dynamic>);
            _store?.dispatch(SetAssertionAction(assertion.id, assertion));
          } catch (e) {
            debugPrint("Assertion status update");
          }
          return;
        case "cjtk":
          try {
            final joinToken = content;
            debugPrint("Join link received for chat: $joinToken");
            Clipboard.setData(ClipboardData(text: joinToken));
          } catch (e) {
            debugPrint("Error handling join link: $e");
          }
          return;
        case "memb":
          try {
            final parts = content.split(',');
            if (parts.length < 2) {
              debugPrint("Invalid members format: $content");
              return;
            }
            final chatId = parts[0];
            final membersJson = parts.sublist(1).join(",");
            final members = jsonDecode(membersJson) as List<dynamic>;
            final memberProfiles = members
                .map((m) => Member.fromJson(m as Map<String, dynamic>))
                .toList();
            _store?.dispatch(SetChatMembersAction(chatId, memberProfiles));
          } catch (e) {
            debugPrint("Error decoding members JSON: $e");
          }
          return;
        default:
          break;
      }
    }
  }

  void _handleDisconnect() {
    _socket?.destroy();
    _socket = null;
    _store?.dispatch(SetConnectionStatusAction(false));
    _connect();
  }

  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    _socket?.destroy();
    _socket = null;
    _aes = null;
  }
}
