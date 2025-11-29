import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/export.dart';

/// Encryption service implementing AES-256-GCM and PBKDF2 key derivation
///
/// Security features:
/// - AES-256-GCM for authenticated encryption
/// - PBKDF2 with 100,000 iterations for key derivation
/// - SHA-256 for checksums and hashing
/// - Secure random IV/nonce generation
class EncryptionService {
  static const int _keyLength = 32; // 256 bits
  static const int _pbkdf2Iterations = 100000;
  static const int _saltLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits for GCM

  /// Derives a cryptographic key from a password using PBKDF2
  ///
  /// [password] - User password or PIN
  /// [salt] - Salt bytes (must be 32 bytes)
  /// [iterations] - Number of PBKDF2 iterations (default: 100,000)
  ///
  /// Returns: 32-byte (256-bit) encryption key
  Uint8List deriveKey({
    required String password,
    required Uint8List salt,
    int iterations = _pbkdf2Iterations,
  }) {
    if (salt.length != _saltLength) {
      throw ArgumentError('Salt must be $_saltLength bytes');
    }

    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(salt, iterations, _keyLength));

    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Generates a secure random salt
  Uint8List generateSalt() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(256));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    return secureRandom.nextBytes(_saltLength);
  }

  /// Generates a secure random IV/nonce
  Uint8List generateIV() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(256));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    return secureRandom.nextBytes(_ivLength);
  }

  /// Encrypts data using AES-256-GCM
  ///
  /// [plaintext] - Data to encrypt
  /// [key] - 32-byte encryption key
  ///
  /// Returns: Encrypted data with IV prepended (IV || ciphertext || tag)
  Uint8List encryptBytes({
    required Uint8List plaintext,
    required Uint8List key,
  }) {
    if (key.length != _keyLength) {
      throw ArgumentError('Key must be $_keyLength bytes');
    }

    final iv = generateIV();
    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        encrypt.Key(key),
        mode: encrypt.AESMode.gcm,
      ),
    );

    final encrypted = encrypter.encryptBytes(
      plaintext,
      iv: encrypt.IV(iv),
    );

    // Prepend IV to ciphertext (IV || ciphertext || tag)
    final result = Uint8List(iv.length + encrypted.bytes.length);
    result.setAll(0, iv);
    result.setAll(iv.length, encrypted.bytes);

    return result;
  }

  /// Decrypts data using AES-256-GCM
  ///
  /// [ciphertext] - Encrypted data with IV prepended (IV || ciphertext || tag)
  /// [key] - 32-byte encryption key
  ///
  /// Returns: Decrypted plaintext
  Uint8List decryptBytes({
    required Uint8List ciphertext,
    required Uint8List key,
  }) {
    if (key.length != _keyLength) {
      throw ArgumentError('Key must be $_keyLength bytes');
    }

    if (ciphertext.length < _ivLength) {
      throw ArgumentError('Ciphertext too short');
    }

    // Extract IV and actual ciphertext
    final iv = ciphertext.sublist(0, _ivLength);
    final actualCiphertext = ciphertext.sublist(_ivLength);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        encrypt.Key(key),
        mode: encrypt.AESMode.gcm,
      ),
    );

    try {
      final decrypted = encrypter.decryptBytes(
        encrypt.Encrypted(actualCiphertext),
        iv: encrypt.IV(iv),
      );

      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw Exception('Decryption failed: Invalid key or corrupted data');
    }
  }

  /// Encrypts a string using AES-256-GCM
  String encryptString({
    required String plaintext,
    required Uint8List key,
  }) {
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));
    final encrypted = encryptBytes(plaintext: plaintextBytes, key: key);
    return base64.encode(encrypted);
  }

  /// Decrypts a string using AES-256-GCM
  String decryptString({
    required String ciphertext,
    required Uint8List key,
  }) {
    final ciphertextBytes = base64.decode(ciphertext);
    final decrypted = decryptBytes(ciphertext: ciphertextBytes, key: key);
    return utf8.decode(decrypted);
  }

  /// Computes SHA-256 checksum of data
  String computeChecksum(Uint8List data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }

  /// Derives Data Encryption Key (DEK) from master key using HKDF
  Uint8List deriveDEK({
    required Uint8List masterKey,
    required String context,
  }) {
    return _hkdfSha256(
      masterKey: masterKey,
      info: utf8.encode('DEK:$context'),
      length: _keyLength,
    );
  }

  /// Derives Backup Encryption Key (BEK) from user password
  Uint8List deriveBEK({
    required String password,
    required Uint8List salt,
  }) {
    return deriveKey(
      password: password,
      salt: salt,
      iterations: _pbkdf2Iterations,
    );
  }

  /// HKDF-SHA256 implementation
  Uint8List _hkdfSha256({
    required Uint8List masterKey,
    required List<int> info,
    int length = 32,
  }) {
    final hmac = Hmac(sha256, masterKey);
    final prk = hmac.convert(Uint8List(32)); // Extract step

    // Expand step
    final result = <int>[];
    var t = <int>[];
    var counter = 1;

    while (result.length < length) {
      final hmac2 = Hmac(sha256, prk.bytes);
      t = hmac2.convert([...t, ...info, counter]).bytes;
      result.addAll(t);
      counter++;
    }

    return Uint8List.fromList(result.sublist(0, length));
  }

  /// Validates encryption key format
  bool isValidKey(Uint8List key) {
    return key.length == _keyLength;
  }

  /// Securely wipes a key from memory (best effort)
  void wipeKey(Uint8List key) {
    for (int i = 0; i < key.length; i++) {
      key[i] = 0;
    }
  }
}
