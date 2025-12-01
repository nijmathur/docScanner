import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:doc_scanner/core/services/session_service.dart';

void main() {
  group('SessionService', () {
    late SessionService sessionService;

    setUp(() {
      sessionService = SessionService();
    });

    test('should initialize with no active session', () {
      expect(sessionService.hasActiveSession, isFalse);
      expect(sessionService.dataEncryptionKey, isNull);
    });

    test('should set data encryption key', () {
      final key = Uint8List.fromList([1, 2, 3, 4, 5]);

      sessionService.setDataEncryptionKey(key);

      expect(sessionService.hasActiveSession, isTrue);
      expect(sessionService.dataEncryptionKey, equals(key));
    });

    test('should clear session data', () {
      final key = Uint8List.fromList([1, 2, 3, 4, 5]);
      sessionService.setDataEncryptionKey(key);

      sessionService.clearSession();

      expect(sessionService.hasActiveSession, isFalse);
      expect(sessionService.dataEncryptionKey, isNull);
    });

    test('should zero out key bytes when clearing session', () {
      final key = Uint8List.fromList([1, 2, 3, 4, 5]);
      sessionService.setDataEncryptionKey(key);

      sessionService.clearSession();

      // The original key bytes should be zeroed out
      expect(key, equals(Uint8List.fromList([0, 0, 0, 0, 0])));
    });

    test('should notify listeners when setting key', () {
      final key = Uint8List.fromList([1, 2, 3, 4, 5]);
      bool notified = false;

      sessionService.addListener(() {
        notified = true;
      });

      sessionService.setDataEncryptionKey(key);

      expect(notified, isTrue);
    });

    test('should notify listeners when clearing session', () {
      final key = Uint8List.fromList([1, 2, 3, 4, 5]);
      sessionService.setDataEncryptionKey(key);

      bool notified = false;
      sessionService.addListener(() {
        notified = true;
      });

      sessionService.clearSession();

      expect(notified, isTrue);
    });

    test('should handle dispose gracefully', () {
      final key = Uint8List.fromList([1, 2, 3, 4, 5]);
      sessionService.setDataEncryptionKey(key);

      // Dispose should complete without errors
      expect(() => sessionService.dispose(), returnsNormally);

      // After dispose, the original key bytes should be zeroed out
      expect(key, equals(Uint8List.fromList([0, 0, 0, 0, 0])));
    });
  });
}
