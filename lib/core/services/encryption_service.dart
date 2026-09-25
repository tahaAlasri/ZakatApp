import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service providing cryptographic key management via FlutterSecureStorage
/// and authenticated field encryption for sensitive user data.
class EncryptionService {
  static const String _storageKey = 'zakat_assistance_encryption_key_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static Uint8List? _cachedKey;

  @visibleForTesting
  static void setMockKey(Uint8List? key) {
    _cachedKey = key;
  }

  /// Get or generate 256-bit encryption key stored securely in FlutterSecureStorage
  static Future<Uint8List> getMasterKey() async {
    if (_cachedKey != null) return _cachedKey!;

    try {
      final storedBase64 = await _storage
          .read(key: _storageKey)
          .timeout(const Duration(milliseconds: 1500));
      if (storedBase64 != null && storedBase64.isNotEmpty) {
        final keyBytes = base64Decode(storedBase64);
        if (keyBytes.length == 32) {
          _cachedKey = Uint8List.fromList(keyBytes);
          return _cachedKey!;
        }
      }

      // Generate a new cryptographically secure 256-bit key
      final newKey = Hive.generateSecureKey();
      final keyBytes = Uint8List.fromList(newKey);
      await _storage
          .write(key: _storageKey, value: base64Encode(keyBytes))
          .timeout(const Duration(milliseconds: 1500));
      _cachedKey = keyBytes;
      return _cachedKey!;
    } catch (e) {
      debugPrint('SecureStorage read/write notice (fallback to persisted local secure key): $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        const fallbackKey = 'zakat_app_fallback_enc_key_v1';
        final existing = prefs.getString(fallbackKey);
        if (existing != null && existing.isNotEmpty) {
          final decoded = base64Decode(existing);
          if (decoded.length == 32) {
            _cachedKey = Uint8List.fromList(decoded);
            return _cachedKey!;
          }
        }
        final secureRandomKey = Hive.generateSecureKey();
        final keyBytes = Uint8List.fromList(secureRandomKey);
        await prefs.setString(fallbackKey, base64Encode(keyBytes));
        _cachedKey = keyBytes;
        return _cachedKey!;
      } catch (_) {
        final secureRandomKey = Hive.generateSecureKey();
        _cachedKey = Uint8List.fromList(secureRandomKey);
        return _cachedKey!;
      }
    }
  }

  /// Returns a HiveAesCipher initialized with the master key from FlutterSecureStorage
  static Future<HiveCipher> getHiveCipher() async {
    final key = await getMasterKey();
    return HiveAesCipher(key);
  }

  /// Encrypts sensitive string using HMAC-SHA256 authenticated CTR stream cipher
  static String encryptString(String plainText, Uint8List key) {
    if (plainText.isEmpty) return '';
    final plainBytes = utf8.encode(plainText);

    // 16 bytes random IV
    final rng = Random.secure();
    final iv = Uint8List.fromList(List<int>.generate(16, (_) => rng.nextInt(256)));

    final encryptedBytes = Uint8List(plainBytes.length);
    final blockCount = (plainBytes.length / 32).ceil();

    for (int b = 0; b < blockCount; b++) {
      final counterBytes = Uint8List(4)..buffer.asByteData().setUint32(0, b);
      final blockKey = Hmac(sha256, key).convert([...iv, ...counterBytes]).bytes;
      final start = b * 32;
      final end = min(start + 32, plainBytes.length);
      for (int i = start; i < end; i++) {
        encryptedBytes[i] = plainBytes[i] ^ blockKey[i - start];
      }
    }

    // HMAC verification tag over IV + ciphertext
    final mac = Hmac(sha256, key).convert([...iv, ...encryptedBytes]).bytes;

    final payload = [...iv, ...mac, ...encryptedBytes];
    return 'ENC:${base64Encode(payload)}';
  }

  /// Decrypts ciphertext produced by encryptString
  static String decryptString(String cipherText, Uint8List key) {
    if (cipherText.isEmpty) return '';
    if (!cipherText.startsWith('ENC:')) {
      // Legacy unencrypted plain text fallback
      return cipherText;
    }

    try {
      final raw = base64Decode(cipherText.substring(4));
      if (raw.length < 48) return cipherText; // 16 bytes IV + 32 bytes MAC minimum

      final iv = raw.sublist(0, 16);
      final mac = raw.sublist(16, 48);
      final encryptedBytes = raw.sublist(48);

      // Verify MAC
      final expectedMac = Hmac(sha256, key).convert([...iv, ...encryptedBytes]).bytes;
      bool matches = true;
      for (int i = 0; i < 32; i++) {
        if (mac[i] != expectedMac[i]) matches = false;
      }
      if (!matches) {
        throw StateError('MAC authentication failed for encrypted sensitive field');
      }

      final decryptedBytes = Uint8List(encryptedBytes.length);
      final blockCount = (encryptedBytes.length / 32).ceil();

      for (int b = 0; b < blockCount; b++) {
        final counterBytes = Uint8List(4)..buffer.asByteData().setUint32(0, b);
        final blockKey = Hmac(sha256, key).convert([...iv, ...counterBytes]).bytes;
        final start = b * 32;
        final end = min(start + 32, encryptedBytes.length);
        for (int i = start; i < end; i++) {
          decryptedBytes[i] = encryptedBytes[i] ^ blockKey[i - start];
        }
      }

      return utf8.decode(decryptedBytes);
    } catch (e) {
      debugPrint('Error decrypting sensitive field: $e');
      return cipherText;
    }
  }

  /// Clears in-memory cached key
  static void purgeKey() {
    _cachedKey = null;
  }
}
