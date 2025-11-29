import 'package:flutter_test/flutter_test.dart';
import 'package:doc_scanner/core/services/encryption_service.dart';
import 'dart:typed_data';

void main() {
  group('EncryptionService', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
    });

    group('Salt Generation', () {
      test('generates salt of correct length', () {
        final salt = encryptionService.generateSalt();
        expect(salt.length, equals(32));
      });

      test('generates unique salts', () {
        final salt1 = encryptionService.generateSalt();
        final salt2 = encryptionService.generateSalt();
        expect(salt1, isNot(equals(salt2)));
      });
    });

    group('IV Generation', () {
      test('generates IV of correct length', () {
        final iv = encryptionService.generateIV();
        expect(iv.length, equals(16));
      });

      test('generates unique IVs', () {
        final iv1 = encryptionService.generateIV();
        final iv2 = encryptionService.generateIV();
        expect(iv1, isNot(equals(iv2)));
      });
    });

    group('Key Derivation', () {
      test('deriveKey produces correct key length', () {
        final password = 'testPassword';
        final salt = encryptionService.generateSalt();

        final key = encryptionService.deriveKey(
          password: password,
          salt: salt,
        );

        expect(key.length, equals(32)); // 256 bits
      });

      test('deriveKey produces consistent results with same inputs', () {
        final password = 'testPassword';
        final salt = encryptionService.generateSalt();

        final key1 = encryptionService.deriveKey(
          password: password,
          salt: salt,
        );
        final key2 = encryptionService.deriveKey(
          password: password,
          salt: salt,
        );

        expect(key1, equals(key2));
      });

      test('deriveKey produces different keys for different passwords', () {
        final salt = encryptionService.generateSalt();

        final key1 = encryptionService.deriveKey(
          password: 'password1',
          salt: salt,
        );
        final key2 = encryptionService.deriveKey(
          password: 'password2',
          salt: salt,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('deriveKey produces different keys for different salts', () {
        final password = 'testPassword';
        final salt1 = encryptionService.generateSalt();
        final salt2 = encryptionService.generateSalt();

        final key1 = encryptionService.deriveKey(
          password: password,
          salt: salt1,
        );
        final key2 = encryptionService.deriveKey(
          password: password,
          salt: salt2,
        );

        expect(key1, isNot(equals(key2)));
      });

      test('deriveKey throws on invalid salt length', () {
        expect(
          () => encryptionService.deriveKey(
            password: 'test',
            salt: Uint8List(16), // Wrong length
          ),
          throwsArgumentError,
        );
      });
    });

    group('Encryption/Decryption', () {
      test('encrypt and decrypt roundtrip preserves data', () {
        final plaintext = Uint8List.fromList('test data'.codeUnits);
        final key = encryptionService.generateSalt();

        final encrypted = encryptionService.encryptBytes(
          plaintext: plaintext,
          key: key,
        );
        final decrypted = encryptionService.decryptBytes(
          ciphertext: encrypted,
          key: key,
        );

        expect(decrypted, equals(plaintext));
      });

      test('encrypted data is different from plaintext', () {
        final plaintext = Uint8List.fromList('test data'.codeUnits);
        final key = encryptionService.generateSalt();

        final encrypted = encryptionService.encryptBytes(
          plaintext: plaintext,
          key: key,
        );

        expect(encrypted, isNot(equals(plaintext)));
      });

      test('same plaintext produces different ciphertext (unique IVs)', () {
        final plaintext = Uint8List.fromList('test data'.codeUnits);
        final key = encryptionService.generateSalt();

        final encrypted1 = encryptionService.encryptBytes(
          plaintext: plaintext,
          key: key,
        );
        final encrypted2 = encryptionService.encryptBytes(
          plaintext: plaintext,
          key: key,
        );

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('decryption with wrong key fails', () {
        final plaintext = Uint8List.fromList('test data'.codeUnits);
        final correctKey = encryptionService.generateSalt();
        final wrongKey = encryptionService.generateSalt();

        final encrypted = encryptionService.encryptBytes(
          plaintext: plaintext,
          key: correctKey,
        );

        expect(
          () => encryptionService.decryptBytes(
            ciphertext: encrypted,
            key: wrongKey,
          ),
          throwsException,
        );
      });

      test('tampered ciphertext fails decryption', () {
        final plaintext = Uint8List.fromList('test data'.codeUnits);
        final key = encryptionService.generateSalt();

        final encrypted = encryptionService.encryptBytes(
          plaintext: plaintext,
          key: key,
        );

        // Tamper with ciphertext
        encrypted[20] ^= 0xFF;

        expect(
          () => encryptionService.decryptBytes(
            ciphertext: encrypted,
            key: key,
          ),
          throwsException,
        );
      });

      test('encrypt/decrypt large data', () {
        final plaintext = Uint8List(1024 * 100); // 100KB
        for (int i = 0; i < plaintext.length; i++) {
          plaintext[i] = i % 256;
        }
        final key = encryptionService.generateSalt();

        final encrypted = encryptionService.encryptBytes(
          plaintext: plaintext,
          key: key,
        );
        final decrypted = encryptionService.decryptBytes(
          ciphertext: encrypted,
          key: key,
        );

        expect(decrypted, equals(plaintext));
      });

      test('encrypt throws on invalid key length', () {
        final plaintext = Uint8List.fromList('test'.codeUnits);
        final invalidKey = Uint8List(16); // Wrong length

        expect(
          () => encryptionService.encryptBytes(
            plaintext: plaintext,
            key: invalidKey,
          ),
          throwsArgumentError,
        );
      });
    });

    group('String Encryption', () {
      test('encryptString and decryptString roundtrip', () {
        final plaintext = 'Hello, World!';
        final key = encryptionService.generateSalt();

        final encrypted = encryptionService.encryptString(
          plaintext: plaintext,
          key: key,
        );
        final decrypted = encryptionService.decryptString(
          ciphertext: encrypted,
          key: key,
        );

        expect(decrypted, equals(plaintext));
      });

      test('encryptString handles unicode', () {
        final plaintext = 'こんにちは 🔐 Encryption!';
        final key = encryptionService.generateSalt();

        final encrypted = encryptionService.encryptString(
          plaintext: plaintext,
          key: key,
        );
        final decrypted = encryptionService.decryptString(
          ciphertext: encrypted,
          key: key,
        );

        expect(decrypted, equals(plaintext));
      });
    });

    group('Checksum', () {
      test('computeChecksum produces consistent SHA-256 hash', () {
        final data = Uint8List.fromList('test data'.codeUnits);

        final checksum1 = encryptionService.computeChecksum(data);
        final checksum2 = encryptionService.computeChecksum(data);

        expect(checksum1, equals(checksum2));
        expect(checksum1.length, equals(64)); // SHA-256 hex string
      });

      test('computeChecksum produces different hashes for different data', () {
        final data1 = Uint8List.fromList('data1'.codeUnits);
        final data2 = Uint8List.fromList('data2'.codeUnits);

        final checksum1 = encryptionService.computeChecksum(data1);
        final checksum2 = encryptionService.computeChecksum(data2);

        expect(checksum1, isNot(equals(checksum2)));
      });

      test('computeChecksum handles empty data', () {
        final data = Uint8List(0);
        final checksum = encryptionService.computeChecksum(data);
        expect(checksum.length, equals(64));
      });
    });

    group('DEK and BEK Derivation', () {
      test('deriveDEK produces consistent keys', () {
        final masterKey = encryptionService.generateSalt();
        final context = 'test_context';

        final dek1 = encryptionService.deriveDEK(
          masterKey: masterKey,
          context: context,
        );
        final dek2 = encryptionService.deriveDEK(
          masterKey: masterKey,
          context: context,
        );

        expect(dek1, equals(dek2));
        expect(dek1.length, equals(32));
      });

      test('deriveDEK produces different keys for different contexts', () {
        final masterKey = encryptionService.generateSalt();

        final dek1 = encryptionService.deriveDEK(
          masterKey: masterKey,
          context: 'context1',
        );
        final dek2 = encryptionService.deriveDEK(
          masterKey: masterKey,
          context: 'context2',
        );

        expect(dek1, isNot(equals(dek2)));
      });

      test('deriveBEK produces correct backup encryption key', () {
        final password = 'backupPassword123';
        final salt = encryptionService.generateSalt();

        final bek = encryptionService.deriveBEK(
          password: password,
          salt: salt,
        );

        expect(bek.length, equals(32));
      });
    });

    group('Key Validation', () {
      test('isValidKey returns true for 32-byte key', () {
        final key = encryptionService.generateSalt();
        expect(encryptionService.isValidKey(key), isTrue);
      });

      test('isValidKey returns false for invalid key lengths', () {
        expect(encryptionService.isValidKey(Uint8List(16)), isFalse);
        expect(encryptionService.isValidKey(Uint8List(64)), isFalse);
        expect(encryptionService.isValidKey(Uint8List(0)), isFalse);
      });
    });

    group('Key Wiping', () {
      test('wipeKey zeros out key data', () {
        final key = encryptionService.generateSalt();
        final originalKey = Uint8List.fromList(key);

        encryptionService.wipeKey(key);

        expect(key, isNot(equals(originalKey)));
        expect(key.every((byte) => byte == 0), isTrue);
      });
    });
  });
}
