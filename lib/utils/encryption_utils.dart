import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:pointycastle/pointycastle.dart';

/// Container for AES/EAX encryption primitives
class AesCrypt {
  final KeyParameter keyParam;
  final Uint8List nonce;
  AesCrypt(this.keyParam, this.nonce);
}

/// Utilities for RSA/OAEP key exchange and AES/EAX message framing
class EncryptionUtils {
  /// Decode PEM-formatted public key to DER bytes
  static Uint8List _decodePEM(String pem) {
    final lines = pem.split('\n').where((l) => !l.startsWith('-----')).toList();
    return base64.decode(lines.join());
  }

  /// Parse DER-encoded RSA public key to RSAPublicKey
  static RSAPublicKey _parsePublicKey(Uint8List derBytes) {
    final parser = ASN1Parser(derBytes);
    final topSeq = parser.nextObject() as ASN1Sequence;
    ASN1Sequence seq;
    final elements = topSeq.elements;
    if (elements?.length == 2 && elements?[0] is ASN1Integer) {
      seq = topSeq;
    } else {
      final bitString = elements?[1] as ASN1BitString;
      final rawBytes = bitString.valueBytes as Uint8List;
      // Skip the first byte (unused bits indicator) to get the DER-encoded key sequence
      final keyBytes = rawBytes.sublist(1);
      final parser2 = ASN1Parser(keyBytes);
      seq = parser2.nextObject() as ASN1Sequence;
    }
    final seqElements = seq.elements;
    final modulus = (seqElements?[0] as ASN1Integer).integer;
    final exponent = (seqElements?[1] as ASN1Integer).integer;
    return RSAPublicKey(modulus!, exponent!);
  }

  /// Read a single length-prefixed message from a broadcast Stream<Uint8List>
  static Future<Uint8List> _readRawFrom(Stream<Uint8List> stream) {
    final comp = Completer<Uint8List>();
    final buffer = <int>[];
    int? expected;
    late StreamSubscription<Uint8List> sub;
    sub = stream.listen((data) {
      buffer.addAll(data);
      if (expected == null && buffer.length >= 4) {
        expected = ByteData.sublistView(Uint8List.fromList(buffer), 0, 4)
            .getInt32(0, Endian.big);
      }
      if (expected != null && buffer.length >= 4 + expected!) {
        sub.cancel();
        comp.complete(Uint8List.fromList(buffer.sublist(4, 4 + expected!)));
      }
    }, onError: (e) => comp.completeError(e));
    return comp.future;
  }

  /// Send a length-prefixed message to socket
  static void sendRaw(Socket socket, Uint8List data) {
    final header = ByteData(4)..setInt32(0, data.length, Endian.big);
    socket.add(header.buffer.asUint8List());
    socket.add(data);
  }

  /// RSA/OAEP key exchange: returns AES/EAX cryptor
  static Future<AesCrypt> keyExchange(Socket socket,
      {Stream<Uint8List>? dataStream}) async {
    // receive server RSA public key PEM
    final stream = dataStream ?? socket.cast<Uint8List>().asBroadcastStream();
    final pubPem = utf8.decode(await _readRawFrom(stream));
    // parse public key
    final der = _decodePEM(pubPem);
    final rsaPub = _parsePublicKey(der);
    // generate AES session key
    final fortuna = FortunaRandom();
    final seed = <int>[];
    for (var i = 0; i < 32; i++) {
      seed.add(Random.secure().nextInt(256));
    }
    fortuna.seed(KeyParameter(Uint8List.fromList(seed)));
    final sessionKey = fortuna.nextBytes(16);
    final keyParam = KeyParameter(sessionKey);

    final rsa = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(rsaPub));
    final encryptedSession = rsa.process(sessionKey);
    sendRaw(socket, encryptedSession as Uint8List);

    // receive AES nonce
    final nonce = await _readRawFrom(stream);
    return AesCrypt(keyParam, nonce);
  }

  /// Encrypt data with AES/EAX: returns frame = nonce + ciphertext + tag
  static Uint8List encryptFrame(AesCrypt aes, Uint8List data) {
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(aes.keyParam, 128, aes.nonce, Uint8List(0)));
    final out = cipher.process(data);
    // out = ciphertext||tag
    return Uint8List.fromList(aes.nonce + out);
  }

  /// Decrypt frame (nonce + ciphertext + tag)
  static Uint8List decryptFrame(AesCrypt aes, Uint8List frame) {
    final nonce = frame.sublist(0, aes.nonce.length);
    final body = frame.sublist(aes.nonce.length);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(aes.keyParam, 128, nonce, Uint8List(0)));
    return cipher.process(body);
  }
}
