import 'package:flutter/foundation.dart';

/// Service to manage the current user session
///
/// Holds the Data Encryption Key (DEK) in memory during the session
/// The DEK is cleared when the user logs out or the session times out
class SessionService extends ChangeNotifier {
  Uint8List? _dataEncryptionKey;

  /// Get the current session's data encryption key
  Uint8List? get dataEncryptionKey => _dataEncryptionKey;

  /// Check if a valid session exists
  bool get hasActiveSession => _dataEncryptionKey != null;

  /// Set the data encryption key after successful authentication
  void setDataEncryptionKey(Uint8List key) {
    _dataEncryptionKey = key;
    notifyListeners();
  }

  /// Clear the session data (logout)
  void clearSession() {
    // Zero out the key bytes for security
    if (_dataEncryptionKey != null) {
      _dataEncryptionKey!.fillRange(0, _dataEncryptionKey!.length, 0);
    }
    _dataEncryptionKey = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Zero out the key bytes for security
    if (_dataEncryptionKey != null) {
      _dataEncryptionKey!.fillRange(0, _dataEncryptionKey!.length, 0);
    }
    _dataEncryptionKey = null;
    super.dispose();
  }
}
