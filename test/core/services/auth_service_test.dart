import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:doc_scanner/core/services/auth_service.dart';
import 'package:doc_scanner/core/services/encryption_service.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage, LocalAuthentication, EncryptionService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    late AuthService authService;
    late MockFlutterSecureStorage mockSecureStorage;
    late MockLocalAuthentication mockLocalAuth;
    late MockEncryptionService mockEncryptionService;

    setUp(() {
      mockSecureStorage = MockFlutterSecureStorage();
      mockLocalAuth = MockLocalAuthentication();
      mockEncryptionService = MockEncryptionService();

      authService = AuthService(
        secureStorage: mockSecureStorage,
        localAuth: mockLocalAuth,
        encryptionService: mockEncryptionService,
      );
    });

    group('Setup and Configuration', () {
      test('isSetUp returns false when no auth method configured', () async {
        when(mockSecureStorage.read(key: 'auth_method'))
            .thenAnswer((_) async => null);

        final result = await authService.isSetUp();

        expect(result, isFalse);
      });

      test('isSetUp returns true when auth method is configured', () async {
        when(mockSecureStorage.read(key: 'auth_method'))
            .thenAnswer((_) async => 'pin');

        final result = await authService.isSetUp();

        expect(result, isTrue);
      });

      test('getAuthMethod returns null when not set up', () async {
        when(mockSecureStorage.read(key: 'auth_method'))
            .thenAnswer((_) async => null);

        final result = await authService.getAuthMethod();

        expect(result, isNull);
      });

      test('getAuthMethod returns configured method', () async {
        when(mockSecureStorage.read(key: 'auth_method'))
            .thenAnswer((_) async => 'pin');

        final result = await authService.getAuthMethod();

        expect(result, equals(AuthMethod.pin));
      });

      test('getAuthMethod returns pin for invalid stored value', () async {
        when(mockSecureStorage.read(key: 'auth_method'))
            .thenAnswer((_) async => 'invalid');

        final result = await authService.getAuthMethod();

        expect(result, equals(AuthMethod.pin));
      });
    });

    group('PIN Setup', () {
      test('setupPIN creates PIN with valid 6-digit input', () async {
        final salt = Uint8List.fromList(List.generate(32, (i) => i));
        final masterKey = Uint8List.fromList(List.generate(32, (i) => i + 100));
        final pinHash = 'test_pin_hash';
        final masterKeyHash = 'test_master_key_hash';

        when(mockEncryptionService.generateSalt()).thenReturn(salt);
        when(mockEncryptionService.deriveKey(
          password: anyNamed('password'),
          salt: anyNamed('salt'),
        )).thenReturn(masterKey);
        when(mockEncryptionService.computeChecksum(any)).thenReturn(pinHash);
        when(mockEncryptionService.computeChecksum(masterKey))
            .thenReturn(masterKeyHash);
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        await authService.setupPIN('123456');

        verify(mockEncryptionService.generateSalt()).called(1);
        verify(mockEncryptionService.deriveKey(password: '123456', salt: salt))
            .called(1);
        verify(mockSecureStorage.write(key: 'auth_method', value: 'pin'))
            .called(1);
        verify(mockSecureStorage.write(key: 'failed_attempts', value: '0'))
            .called(1);
      });

      test('setupPIN throws exception for non-6-digit PIN', () async {
        expect(
          () => authService.setupPIN('12345'),
          throwsException,
        );
        expect(
          () => authService.setupPIN('1234567'),
          throwsException,
        );
      });

      test('setupPIN throws exception for non-numeric PIN', () async {
        expect(
          () => authService.setupPIN('12345a'),
          throwsException,
        );
        expect(
          () => authService.setupPIN('abcdef'),
          throwsException,
        );
      });

      test('setupPIN stores all required data', () async {
        final salt = Uint8List.fromList(List.generate(32, (i) => i));
        final masterKey = Uint8List.fromList(List.generate(32, (i) => i + 100));

        when(mockEncryptionService.generateSalt()).thenReturn(salt);
        when(mockEncryptionService.deriveKey(
          password: anyNamed('password'),
          salt: anyNamed('salt'),
        )).thenReturn(masterKey);
        when(mockEncryptionService.computeChecksum(any)).thenReturn('hash');
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        await authService.setupPIN('999999');

        verify(mockSecureStorage.write(
                key: 'master_key', value: anyNamed('value')))
            .called(1);
        verify(mockSecureStorage.write(
                key: 'pin_salt', value: anyNamed('value')))
            .called(1);
        verify(mockSecureStorage.write(
                key: 'pin_hash', value: anyNamed('value')))
            .called(1);
        verify(mockSecureStorage.write(key: 'auth_method', value: 'pin'))
            .called(1);
        verify(mockSecureStorage.write(key: 'failed_attempts', value: '0'))
            .called(1);
      });
    });

    group('PIN Authentication', () {
      test('authenticateWithPIN returns master key for correct PIN', () async {
        final salt = Uint8List.fromList(List.generate(32, (i) => i));
        final saltHex =
            salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        final pinHash = 'test_hash';
        final masterKey = Uint8List.fromList(List.generate(32, (i) => i + 100));

        when(mockSecureStorage.read(key: 'pin_hash'))
            .thenAnswer((_) async => pinHash);
        when(mockSecureStorage.read(key: 'pin_salt'))
            .thenAnswer((_) async => saltHex);
        when(mockEncryptionService.computeChecksum(any)).thenReturn(pinHash);
        when(mockEncryptionService.deriveKey(
          password: anyNamed('password'),
          salt: anyNamed('salt'),
        )).thenReturn(masterKey);
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        final result = await authService.authenticateWithPIN('123456');

        expect(result, isNotNull);
        expect(result, equals(masterKey));
        verify(mockSecureStorage.write(key: 'failed_attempts', value: '0'))
            .called(1);
      });

      test('authenticateWithPIN returns null for incorrect PIN', () async {
        final salt = Uint8List.fromList(List.generate(32, (i) => i));
        final saltHex =
            salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

        when(mockSecureStorage.read(key: 'pin_hash'))
            .thenAnswer((_) async => 'correct_hash');
        when(mockSecureStorage.read(key: 'pin_salt'))
            .thenAnswer((_) async => saltHex);
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => '0');
        when(mockEncryptionService.computeChecksum(any))
            .thenReturn('wrong_hash');
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        final result = await authService.authenticateWithPIN('123456');

        expect(result, isNull);
        verify(mockSecureStorage.write(key: 'failed_attempts', value: '1'))
            .called(1);
      });

      test('authenticateWithPIN returns null for invalid PIN format', () async {
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => '0');
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        final result = await authService.authenticateWithPIN('12345');

        expect(result, isNull);
        verify(mockSecureStorage.write(key: 'failed_attempts', value: '1'))
            .called(1);
      });

      test('authenticateWithPIN throws when PIN not set up', () async {
        when(mockSecureStorage.read(key: 'pin_hash'))
            .thenAnswer((_) async => null);
        when(mockSecureStorage.read(key: 'pin_salt'))
            .thenAnswer((_) async => null);

        expect(
          () => authService.authenticateWithPIN('123456'),
          throwsException,
        );
      });

      test('authenticateWithPIN updates last activity on success', () async {
        final salt = Uint8List.fromList(List.generate(32, (i) => i));
        final saltHex =
            salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        final pinHash = 'test_hash';
        final masterKey = Uint8List.fromList(List.generate(32, (i) => i + 100));

        when(mockSecureStorage.read(key: 'pin_hash'))
            .thenAnswer((_) async => pinHash);
        when(mockSecureStorage.read(key: 'pin_salt'))
            .thenAnswer((_) async => saltHex);
        when(mockEncryptionService.computeChecksum(any)).thenReturn(pinHash);
        when(mockEncryptionService.deriveKey(
          password: anyNamed('password'),
          salt: anyNamed('salt'),
        )).thenReturn(masterKey);
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        await authService.authenticateWithPIN('123456');

        verify(mockSecureStorage.write(
                key: 'last_activity', value: anyNamed('value')))
            .called(1);
      });
    });

    group('Biometric Authentication', () {
      test('isBiometricAvailable returns true when biometrics supported',
          () async {
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);

        final result = await authService.isBiometricAvailable();

        expect(result, isTrue);
      });

      test('isBiometricAvailable returns false when not supported', () async {
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);

        final result = await authService.isBiometricAvailable();

        expect(result, isFalse);
      });

      test('isBiometricAvailable returns false on exception', () async {
        when(mockLocalAuth.canCheckBiometrics).thenThrow(Exception('Error'));

        final result = await authService.isBiometricAvailable();

        expect(result, isFalse);
      });

      test('getAvailableBiometrics returns list of available types', () async {
        when(mockLocalAuth.getAvailableBiometrics()).thenAnswer(
            (_) async => [BiometricType.face, BiometricType.fingerprint]);

        final result = await authService.getAvailableBiometrics();

        expect(result, hasLength(2));
        expect(result, contains(BiometricType.face));
        expect(result, contains(BiometricType.fingerprint));
      });

      test('getAvailableBiometrics returns empty list on exception', () async {
        when(mockLocalAuth.getAvailableBiometrics())
            .thenThrow(Exception('Error'));

        final result = await authService.getAvailableBiometrics();

        expect(result, isEmpty);
      });

      test('enableBiometric throws when PIN not set up', () async {
        when(mockSecureStorage.read(key: 'auth_method'))
            .thenAnswer((_) async => null);

        expect(
          () => authService.enableBiometric(),
          throwsException,
        );
      });

      test('enableBiometric throws when biometric not available', () async {
        when(mockSecureStorage.read(key: 'auth_method'))
            .thenAnswer((_) async => 'pin');
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => false);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => false);

        expect(
          () => authService.enableBiometric(),
          throwsException,
        );
      });

      test('enableBiometric sets auth method to both', () async {
        when(mockSecureStorage.read(key: 'auth_method'))
            .thenAnswer((_) async => 'pin');
        when(mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        await authService.enableBiometric();

        verify(mockSecureStorage.write(key: 'auth_method', value: 'both'))
            .called(1);
      });

      test('authenticateWithBiometric returns data on success', () async {
        when(mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => true);
        when(mockSecureStorage.read(key: 'pin_salt'))
            .thenAnswer((_) async => '00112233');
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        final result = await authService.authenticateWithBiometric(
          reason: 'Unlock app',
        );

        expect(result, isNotNull);
        verify(mockSecureStorage.write(key: 'failed_attempts', value: '0'))
            .called(1);
      });

      test('authenticateWithBiometric returns null on failure', () async {
        when(mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        )).thenAnswer((_) async => false);
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => '0');
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        final result = await authService.authenticateWithBiometric(
          reason: 'Unlock app',
        );

        expect(result, isNull);
        verify(mockSecureStorage.write(key: 'failed_attempts', value: '1'))
            .called(1);
      });

      test('authenticateWithBiometric returns null on exception', () async {
        when(mockLocalAuth.authenticate(
          localizedReason: anyNamed('localizedReason'),
          options: anyNamed('options'),
        )).thenThrow(Exception('Biometric error'));
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => '0');
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        final result = await authService.authenticateWithBiometric(
          reason: 'Unlock app',
        );

        expect(result, isNull);
      });
    });

    group('Failed Attempts Tracking', () {
      test('getFailedAttempts returns 0 when not set', () async {
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => null);

        final result = await authService.getFailedAttempts();

        expect(result, equals(0));
      });

      test('getFailedAttempts returns stored value', () async {
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => '3');

        final result = await authService.getFailedAttempts();

        expect(result, equals(3));
      });

      test('getFailedAttempts returns 0 for invalid value', () async {
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => 'invalid');

        final result = await authService.getFailedAttempts();

        expect(result, equals(0));
      });

      test('isLocked returns false when attempts below max', () async {
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => '3');

        final result = await authService.isLocked();

        expect(result, isFalse);
      });

      test('isLocked returns true when max attempts reached', () async {
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => '5');

        final result = await authService.isLocked();

        expect(result, isTrue);
      });

      test('isLocked returns true when attempts exceed max', () async {
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => '10');

        final result = await authService.isLocked();

        expect(result, isTrue);
      });
    });

    group('Session Timeout', () {
      test('hasSessionTimedOut returns true when no last activity', () async {
        when(mockSecureStorage.read(key: 'last_activity'))
            .thenAnswer((_) async => null);

        final result = await authService.hasSessionTimedOut();

        expect(result, isTrue);
      });

      test('hasSessionTimedOut returns false when within timeout period',
          () async {
        final recentTime = DateTime.now().subtract(const Duration(minutes: 5));
        when(mockSecureStorage.read(key: 'last_activity'))
            .thenAnswer((_) async => recentTime.toIso8601String());
        when(mockSecureStorage.read(key: 'inactivity_timeout'))
            .thenAnswer((_) async => null);

        final result = await authService.hasSessionTimedOut();

        expect(result, isFalse);
      });

      test('hasSessionTimedOut returns true when past timeout period',
          () async {
        final oldTime = DateTime.now().subtract(const Duration(minutes: 20));
        when(mockSecureStorage.read(key: 'last_activity'))
            .thenAnswer((_) async => oldTime.toIso8601String());
        when(mockSecureStorage.read(key: 'inactivity_timeout'))
            .thenAnswer((_) async => null);

        final result = await authService.hasSessionTimedOut();

        expect(result, isTrue);
      });

      test('getInactivityTimeout returns default value when not set', () async {
        when(mockSecureStorage.read(key: 'inactivity_timeout'))
            .thenAnswer((_) async => null);

        final result = await authService.getInactivityTimeout();

        expect(result, equals(15));
      });

      test('getInactivityTimeout returns stored value', () async {
        when(mockSecureStorage.read(key: 'inactivity_timeout'))
            .thenAnswer((_) async => '30');

        final result = await authService.getInactivityTimeout();

        expect(result, equals(30));
      });

      test('setInactivityTimeout stores valid timeout', () async {
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        await authService.setInactivityTimeout(30);

        verify(mockSecureStorage.write(key: 'inactivity_timeout', value: '30'))
            .called(1);
      });

      test('setInactivityTimeout throws for timeout less than 1', () async {
        expect(
          () => authService.setInactivityTimeout(0),
          throwsException,
        );
      });

      test('setInactivityTimeout throws for timeout greater than 60', () async {
        expect(
          () => authService.setInactivityTimeout(61),
          throwsException,
        );
      });
    });

    group('PIN Management', () {
      test('changePIN succeeds with correct old PIN', () async {
        final salt = Uint8List.fromList(List.generate(32, (i) => i));
        final saltHex =
            salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        final pinHash = 'test_hash';
        final masterKey = Uint8List.fromList(List.generate(32, (i) => i + 100));
        final newSalt = Uint8List.fromList(List.generate(32, (i) => i + 200));

        // Mock authenticateWithPIN for old PIN
        when(mockSecureStorage.read(key: 'pin_hash'))
            .thenAnswer((_) async => pinHash);
        when(mockSecureStorage.read(key: 'pin_salt'))
            .thenAnswer((_) async => saltHex);
        when(mockEncryptionService.computeChecksum(any)).thenReturn(pinHash);
        when(mockEncryptionService.deriveKey(
          password: anyNamed('password'),
          salt: anyNamed('salt'),
        )).thenReturn(masterKey);

        // Mock setupPIN for new PIN
        when(mockEncryptionService.generateSalt()).thenReturn(newSalt);
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        await authService.changePIN('123456', '999999');

        verify(mockEncryptionService.generateSalt()).called(1);
      });

      test('changePIN throws with incorrect old PIN', () async {
        when(mockSecureStorage.read(key: 'pin_hash'))
            .thenAnswer((_) async => 'correct_hash');
        when(mockSecureStorage.read(key: 'pin_salt'))
            .thenAnswer((_) async => '00112233');
        when(mockSecureStorage.read(key: 'failed_attempts'))
            .thenAnswer((_) async => '0');
        when(mockEncryptionService.computeChecksum(any))
            .thenReturn('wrong_hash');
        when(mockSecureStorage.write(
                key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async => {});

        expect(
          () => authService.changePIN('123456', '999999'),
          throwsException,
        );
      });
    });

    group('Data Management', () {
      test('clearAuthData deletes all stored data', () async {
        when(mockSecureStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async => {});

        await authService.clearAuthData();

        verify(mockSecureStorage.delete(key: 'master_key')).called(1);
        verify(mockSecureStorage.delete(key: 'pin_salt')).called(1);
        verify(mockSecureStorage.delete(key: 'pin_hash')).called(1);
        verify(mockSecureStorage.delete(key: 'auth_method')).called(1);
        verify(mockSecureStorage.delete(key: 'failed_attempts')).called(1);
        verify(mockSecureStorage.delete(key: 'last_activity')).called(1);
        verify(mockSecureStorage.delete(key: 'inactivity_timeout')).called(1);
      });
    });
  });
}
