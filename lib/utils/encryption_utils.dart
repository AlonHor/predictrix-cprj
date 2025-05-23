import 'dart:convert';

import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionUtils {
  static late encrypt.IV iv;
  late String aesEncryptionKey;
  static late encrypt.Encrypter encrypter;
}
