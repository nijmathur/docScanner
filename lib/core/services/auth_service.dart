import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'encryption_service.dart';

/// Authentication methods supported by the app
enum AuthMethod {
  pin,
  biometric,
  both,
}

/// Authentication service handling PIN and biometric authentication
///
/// Features:
/// - 6-digit PIN authentication
/// - Biometric authentication (Face ID, Touch ID, Fingerprint)
/// - Secure key storage in OS keystore
/// - PBKDF2 key derivation from PIN
/// - Inactivity timeout
/// - Failed attempt tracking
class AuthService {
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;
  final EncryptionService _encryptionService;

  static const String _masterKeyKey = 'master_key';
  static const String _pinSaltKey = 'pin_salt';
  static const String _pinHashKey = 'pin_hash';
  static const String _authMethodKey = 'auth_method';
  static const String _failedAttemptsKey = 'failed_attempts';
  static const String _lastActivityKey = 'last_activity';
  static const String _inactivityTimeoutKey = 'inactivity_timeout';

  static const int _maxFailedAttempts = 5;
  static const int _defaultInactivityTimeoutMinutes = 15;

  AuthService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
    EncryptionService? encryptionService,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication(),
        _encryptionService = encryptionService ?? EncryptionService();

  /// Check if app is set up (has authentication configured)
  Future<bool> isSetUp() async {
    final authMethod = await _secureStorage.read(key: _authMethodKey);
    return authMethod != null;
  }

  /// Get configured authentication method
  Future<AuthMethod?> getAuthMethod() async {
    final authMethodStr = await _secureStorage.read(key: _authMethodKey);
    if (authMethodStr == null) return null;

    return AuthMethod.values.firstWhere(
      (e) => e.name == authMethodStr,
      orElse: () => AuthMethod.pin,
    );
  }

  /// Set up authentication with PIN
  Future<void> setupPIN(String pin) async {
    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw Exception('PIN must be exactly 6 digits');
    }

    // Generate salt and derive master key
    final salt = _encryptionService.generateSalt();
    final masterKey = _encryptionService.deriveKey(
      password: pin,
      salt: salt,
    );

    // Hash PIN for verification
    final pinHash = _encryptionService.computeChecksum(
      Uint8List.fromList(pin.codeUnits),
    );

    // Store securely
    await _secureStorage.write(
      key: _masterKeyKey,
      value: _encryptionService.computeChecksum(masterKey),
    );
    await _secureStorage.write(key: _pinSaltKey, value: _bytesToHex(salt));
    await _secureStorage.write(key: _pinHashKey, value: pinHash);
    await _secureStorage.write(key: _authMethodKey, value: AuthMethod.pin.name);
    await _resetFailedAttempts();
  }

  /// Verify PIN and return master key if correct
  Future<Uint8List?> authenticateWithPIN(String pin) async {
    if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
      await _incrementFailedAttempts();
      return null;
    }

    final storedPinHash = await _secureStorage.read(key: _pinHashKey);
    final saltHex = await _secureStorage.read(key: _pinSaltKey);

    if (storedPinHash == null || saltHex == null) {
      throw Exception('PIN not set up');
    }

    final salt = _hexToBytes(saltHex);
    final pinHash = _encryptionService.computeChecksum(
      Uint8List.fromList(pin.codeUnits),
    );

    if (pinHash == storedPinHash) {
      await _resetFailedAttempts();
      await _updateLastActivity();

      // Derive master key from PIN
      return _encryptionService.deriveKey(password: pin, salt: salt);
    } else {
      await _incrementFailedAttempts();
      return null;
    }
  }

  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Enable biometric authentication (requires PIN to be set first)
  Future<void> enableBiometric() async {
    final authMethod = await getAuthMethod();
    if (authMethod == null) {
      throw Exception('Set up PIN first');
    }

    final isAvailable = await isBiometricAvailable();
    if (!isAvailable) {
      throw Exception('Biometric authentication not available');
    }

    await _secureStorage.write(
      key: _authMethodKey,
      value: AuthMethod.both.name,
    );
  }

  /// Authenticate with biometric
  Future<Uint8List?> authenticateWithBiometric({
    required String reason,
  }) async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        await _resetFailedAttempts();
        await _updateLastActivity();

        // Retrieve stored master key or derive from PIN
        // In a production app, you'd store the master key encrypted with biometric-protected key
        final saltHex = await _secureStorage.read(key: _pinSaltKey);
        if (saltHex == null) {
          throw Exception('Authentication data not found');
        }

        // For this implementation, we return a marker indicating biometric success
        // In production, you'd use platform-specific biometric key storage
        return Uint8List.fromList([1]); // Placeholder
      } else {
        await _incrementFailedAttempts();
        return null;
      }
    } catch (e) {
      await _incrementFailedAttempts();
      return null;
    }
  }

  /// Get failed authentication attempts count
  Future<int> getFailedAttempts() async {
    final attemptsStr = await _secureStorage.read(key: _failedAttemptsKey);
    return int.tryParse(attemptsStr ?? '0') ?? 0;
  }

  /// Check if max failed attempts reached
  Future<bool> isLocked() async {
    final attempts = await getFailedAttempts();
    return attempts >= _maxFailedAttempts;
  }

  /// Increment failed attempts counter
  Future<void> _incrementFailedAttempts() async {
    final current = await getFailedAttempts();
    await _secureStorage.write(
      key: _failedAttemptsKey,
      value: (current + 1).toString(),
    );
  }

  /// Reset failed attempts counter
  Future<void> _resetFailedAttempts() async {
    await _secureStorage.write(key: _failedAttemptsKey, value: '0');
  }

  /// Update last activity timestamp
  Future<void> _updateLastActivity() async {
    await _secureStorage.write(
      key: _lastActivityKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  /// Check if session has timed out due to inactivity
  Future<bool> hasSessionTimedOut() async {
    final lastActivityStr = await _secureStorage.read(key: _lastActivityKey);
    if (lastActivityStr == null) return true;

    final lastActivity = DateTime.parse(lastActivityStr);
    final timeoutMinutes = await getInactivityTimeout();
    final timeout = Duration(minutes: timeoutMinutes);

    return DateTime.now().difference(lastActivity) > timeout;
  }

  /// Get inactivity timeout in minutes
  Future<int> getInactivityTimeout() async {
    final timeoutStr = await _secureStorage.read(key: _inactivityTimeoutKey);
    return int.tryParse(timeoutStr ?? '') ?? _defaultInactivityTimeoutMinutes;
  }

  /// Set inactivity timeout in minutes
  Future<void> setInactivityTimeout(int minutes) async {
    if (minutes < 1 || minutes > 60) {
      throw Exception('Timeout must be between 1 and 60 minutes');
    }

    await _secureStorage.write(
      key: _inactivityTimeoutKey,
      value: minutes.toString(),
    );
  }

  /// Change PIN
  Future<void> changePIN(String oldPin, String newPin) async {
    final masterKey = await authenticateWithPIN(oldPin);
    if (masterKey == null) {
      throw Exception('Invalid current PIN');
    }

    await setupPIN(newPin);
  }

  /// Clear all authentication data (factory reset)
  Future<void> clearAuthData() async {
    await _secureStorage.delete(key: _masterKeyKey);
    await _secureStorage.delete(key: _pinSaltKey);
    await _secureStorage.delete(key: _pinHashKey);
    await _secureStorage.delete(key: _authMethodKey);
    await _secureStorage.delete(key: _failedAttemptsKey);
    await _secureStorage.delete(key: _lastActivityKey);
    await _secureStorage.delete(key: _inactivityTimeoutKey);
  }

  /// Helper: Convert bytes to hex string
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Helper: Convert hex string to bytes
  Uint8List _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(result);
  }
}
