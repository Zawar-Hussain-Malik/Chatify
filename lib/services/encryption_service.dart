import 'dart:convert';
import 'package:encrypt/encrypt.dart';

/// Chat-level AES encryption service
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  /// Encrypt using chat key
  String encrypt({
    required String plainText,
    required String base64Key,
    required String base64Iv,
  }) {
    final key = Key(base64Decode(base64Key));
    final iv = IV(base64Decode(base64Iv));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    return encrypter.encrypt(plainText, iv: iv).base64;
  }

  /// Decrypt using chat key
  String decrypt({
    required String cipherText,
    required String base64Key,
    required String base64Iv,
  }) {
    final key = Key(base64Decode(base64Key));
    final iv = IV(base64Decode(base64Iv));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    return encrypter.decrypt64(cipherText, iv: iv);
  }

  /// Generate new chat key (AES-256)
  static Map<String, String> generateChatKey() {
    final key = Key.fromSecureRandom(32);
    final iv = IV.fromSecureRandom(16);

    return {
      'key': base64Encode(key.bytes),
      'iv': base64Encode(iv.bytes),
    };
  }
}
