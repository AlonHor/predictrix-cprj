import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:predictrix/utils/encryption_utils.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() => _instance;

  SocketService._internal();

  final String host = '192.168.1.122'; // TODO: change to server ip
  final int port = 32782;
  Socket? _socket;
  final StreamController<String> _dataController = StreamController.broadcast();
  bool _connecting = false;
  Uint8List? _buffer;

  String token = '';
  AesCrypt? _aes;

  Stream<String> get onData => _dataController.stream;

  Future<void> init(String token) async {
    this.token = token;
    await _connect();
  }

  Future<void> _connect() async {
    if (_connecting) return;
    _connecting = true;
    while (_socket == null) {
      try {
        print("Connecting to $host:$port");
        _socket = await Socket.connect(host, port,
            timeout: const Duration(seconds: 5));
        // wrap socket data stream as broadcast of Uint8List
        final byteStream = _socket!
            .map((data) => Uint8List.fromList(data))
            .asBroadcastStream();
        // after raw connection, perform RSA/AES key exchange
        _aes =
            await EncryptionUtils.keyExchange(_socket!, dataStream: byteStream);
        print("Key exchange completed, AES established.");
        // send token encrypted
        send(token);
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
              _dataController.add(text);
              print("Received: $text");

              _buffer = _buffer!.sublist(4 + messageLength);
            }
          },
          onDone: _handleDisconnect,
          onError: (e) => _handleDisconnect(),
          cancelOnError: true,
        );
      } catch (e) {
        print("Connection failed: $e");
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    _connecting = false;
  }

  void send(String message) {
    final messageBytes = utf8.encode(message) as Uint8List;
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

  void _handleDisconnect() {
    _socket?.destroy();
    _socket = null;
    _connect();
  }

  void dispose() {
    _socket?.destroy();
    _dataController.close();
  }
}
