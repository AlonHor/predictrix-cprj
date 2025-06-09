import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:predictrix/redux/types/chat_message.dart';
import 'package:predictrix/redux/types/chat_tile.dart';
import 'package:predictrix/utils/encryption_utils.dart';
import 'package:predictrix/redux/reducers.dart';
import 'package:redux/redux.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  SocketService._internal();

  final String host = '192.168.1.122'; // TODO: change to server ip
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
    await _connect();
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
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    _connecting = false;
  }

  void send(String message) {
    final messageBytes = utf8.encode(message);
    if (_aes != null && _socket != null) {
      // encrypt and send
      final frame = EncryptionUtils.encryptFrame(_aes!, messageBytes);
      // send raw AES frame with length header
      EncryptionUtils.sendRaw(_socket!, frame);
    } else if (_socket != null) {
      // plaintext send before key exchange
      final sizeBytes = ByteData(4)
        ..setInt32(0, messageBytes.length, Endian.big);
      _socket!.add(sizeBytes.buffer.asUint8List());
      _socket!.add(messageBytes);
    }
  }

  // Future<String> sendAndReceive(String message) async {
  //   final completer = Completer<String>();
  //   late StreamSubscription sub;
  //   sub = onData.listen((data) {
  //     completer.complete(data);
  //     sub.cancel();
  //   });
  //   send(message);
  //   return completer.future;
  // }

  void handleIncomingData(String data) {
    if (data.isEmpty) return;

    if (data == "token_ok") {
      debugPrint("Token accepted by server, ready to send/receive messages.");
      _store?.dispatch(SetConnectionStatusAction(true));
      // send("chts");
      return;
    } else if (data == "token_fail") {
      debugPrint("Token error, disconnecting...");
      _store?.dispatch(SetConnectionStatusAction(false));
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
            _store?.dispatch(AddChatMessageAction(chatId, message));
          } catch (e) {
            debugPrint("Error decoding new message JSON: $e");
          } finally {
            _store?.dispatch(SetIsMessageSendingAction(false));
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
    _socket?.destroy();
  }
}
