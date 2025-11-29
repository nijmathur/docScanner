# Debugging Guide

This guide covers debugging techniques and common issues for the Secure Document Scanner application.

## Table of Contents

- [Development Setup](#development-setup)
- [Debugging Tools](#debugging-tools)
- [Common Issues](#common-issues)
- [Platform-Specific Debugging](#platform-specific-debugging)
- [Performance Profiling](#performance-profiling)
- [Security Debugging](#security-debugging)

## Development Setup

### Enable Debug Mode

1. **Flutter DevTools**
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

2. **Run in Debug Mode**
```bash
flutter run --debug
# Or with specific device
flutter run -d <device-id> --debug
```

3. **Verbose Logging**
```bash
flutter run --verbose
```

### IDE Configuration

#### VS Code
Create `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter Debug",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "args": ["--debug"]
    },
    {
      "name": "Flutter Profile",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "flutterMode": "profile"
    }
  ]
}
```

#### Android Studio
1. Run → Edit Configurations
2. Add Flutter Configuration
3. Set additional arguments: `--debug`

## Debugging Tools

### 1. Flutter DevTools

**Launch DevTools:**
```bash
flutter run
# In another terminal
flutter pub global run devtools
```

**Features:**
- Inspector: UI hierarchy and properties
- Performance: Frame rendering, CPU profiling
- Memory: Memory allocation and leaks
- Network: HTTP requests and responses
- Logging: Console output

### 2. Print Debugging

```dart
// Basic print
print('Debug: Document ID = $documentId');

// Conditional debug print
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('Debug: This only prints in debug mode');
}

// Pretty print objects
debugPrint(jsonEncode(document.toMap()));
```

### 3. Breakpoints

**Dart Observatory:**
```bash
flutter run --observe
# Navigate to provided URL to access observatory
```

**Setting Breakpoints:**
- IDE: Click line number gutter
- Programmatic: `debugger()` statement

```dart
import 'dart:developer';

Future<void> processDocument() async {
  debugger(); // Execution pauses here in debug mode

  final result = await ocrService.recognize(image);
  // ...
}
```

### 4. Assert Statements

```dart
assert(() {
  // This only runs in debug mode
  print('Validating document...');
  return document.title.isNotEmpty;
}());

// With message
assert(key.length == 32, 'Key must be 32 bytes');
```

## Common Issues

### 1. Database Issues

#### Symptom: "Database not initialized"
```
Error: Database not initialized
```

**Cause**: Database not opened before use

**Solution**:
```dart
// Ensure database is initialized first
final db = await databaseService.getDatabase(password);

// Then use it
await databaseService.insertDocument(document);
```

**Debug**:
```dart
// Add logging
print('Opening database...');
final db = await databaseService.getDatabase(password);
print('Database opened: ${db != null}');
```

#### Symptom: SQLCipher decryption fails
```
Error: file is not a database
```

**Cause**: Wrong password or corrupted database

**Solution**:
```dart
try {
  final db = await openDatabase(path, password: password);
} catch (e) {
  print('Database open failed: $e');
  // Try with empty password (unencrypted)
  // Or restore from backup
}
```

**Debug**:
```bash
# Check if file exists and size
ls -lh <database_path>

# Try opening with sqlcipher CLI
sqlcipher <database_path>
> PRAGMA key = "your_password";
> SELECT * FROM sqlite_master;
```

### 2. Encryption Issues

#### Symptom: Decryption fails
```
Exception: Decryption failed: Invalid key or corrupted data
```

**Cause**: Wrong key, corrupted data, or IV mismatch

**Debug**:
```dart
// Log key info (NOT the key itself!)
print('Key length: ${key.length}');
print('Ciphertext length: ${ciphertext.length}');

// Verify IV extraction
final iv = ciphertext.sublist(0, 16);
print('IV: ${iv.length} bytes');

// Check if data is actually encrypted
final firstBytes = ciphertext.sublist(0, min(16, ciphertext.length));
print('First bytes: $firstBytes');
```

**Solution**:
```dart
// Implement checksum verification
final expectedChecksum = document.checksum;
final actualChecksum = encryptionService.computeChecksum(
  originalBytes,
);

if (expectedChecksum != actualChecksum) {
  throw Exception('Data corruption detected');
}
```

### 3. OCR Issues

#### Symptom: Empty OCR text
```
OCR result: ""
```

**Causes**:
- Poor image quality
- Insufficient lighting
- Wrong ML Kit language model
- Image preprocessing too aggressive

**Debug**:
```dart
// Save intermediate images
await File('/tmp/original.jpg').writeAsBytes(originalImage);
await File('/tmp/processed.jpg').writeAsBytes(processedImage);

// Check OCR confidence
print('OCR confidence: ${result.confidence}');
print('Block count: ${result.blocks.length}');

// Try with different preprocessing
final result1 = await ocrService.recognizeText(originalPath);
final result2 = await ocrService.recognizeText(grayscalePath);
print('Original OCR: ${result1.fullText.length} chars');
print('Grayscale OCR: ${result2.fullText.length} chars');
```

**Solution**:
```dart
// Adjust image preprocessing
final processed = await imageService.processDocumentImage(
  imagePath: path,
  quality: 90, // Higher quality
  applyGrayscale: true,
  enhanceContrast: true,
  reduceNoise: false, // Try without noise reduction
);
```

### 4. Authentication Issues

#### Symptom: Biometric not working
```
Error: Biometric authentication not available
```

**Debug**:
```dart
// Check availability
final canCheckBiometrics = await auth.canCheckBiometrics;
final isDeviceSupported = await auth.isDeviceSupported();
final biometrics = await auth.getAvailableBiometrics();

print('Can check biometrics: $canCheckBiometrics');
print('Device supported: $isDeviceSupported');
print('Available types: $biometrics');
```

**Common Causes**:
- Permission not granted
- No biometric enrolled
- Device doesn't support biometric
- iOS: Face ID usage description missing from Info.plist

**Solution**:
```dart
// Graceful fallback
try {
  final result = await authService.authenticateWithBiometric(
    reason: 'Authenticate to access documents',
  );
  if (result == null) {
    // Fall back to PIN
    showPINDialog();
  }
} catch (e) {
  print('Biometric error: $e');
  showPINDialog();
}
```

### 5. Cloud Storage Issues

#### Symptom: Upload fails
```
CloudStorageException: Upload failed
```

**Debug**:
```dart
// Enable detailed logging
try {
  await cloudGateway.uploadFile(
    localPath: localPath,
    remotePath: remotePath,
    onProgress: (sent, total) {
      print('Upload progress: $sent/$total bytes');
    },
  );
} catch (e) {
  print('Upload error type: ${e.runtimeType}');
  print('Upload error: $e');
  print('Stack trace: ${StackTrace.current}');
}
```

**Common Causes**:
- OAuth token expired
- Network connectivity
- File size limits
- Insufficient permissions

**Solution**:
```dart
// Verify authentication
final isAuthed = await cloudGateway.isAuthenticated();
if (!isAuthed) {
  await cloudGateway.authenticate();
}

// Retry with exponential backoff
int retries = 3;
for (int i = 0; i < retries; i++) {
  try {
    await cloudGateway.uploadFile(...);
    break;
  } catch (e) {
    if (i == retries - 1) rethrow;
    await Future.delayed(Duration(seconds: pow(2, i).toInt()));
  }
}
```

## Platform-Specific Debugging

### iOS Debugging

#### Xcode Console
```bash
# Open iOS project in Xcode
open ios/Runner.xcworkspace

# Run with Xcode
# View logs in Console pane
```

#### Common iOS Issues

1. **Keychain Access**
```swift
// Check keychain status in iOS
print("Keychain test:")
let status = SecItemCopyMatching(query, &result)
print("Status code: \(status)")
```

2. **Face ID Permission**
```xml
<!-- Check Info.plist has Face ID description -->
<key>NSFaceIDUsageDescription</key>
<string>Face ID is required for authentication</string>
```

3. **Sandbox Access**
```dart
// Verify file paths
final docsDir = await getApplicationDocumentsDirectory();
print('Documents directory: ${docsDir.path}');

// Check file exists and permissions
final file = File(path);
print('File exists: ${await file.exists()}');
print('Can read: ${await file.exists() && await file.readAsBytes() != null}');
```

### Android Debugging

#### Logcat
```bash
# Filter by app package
adb logcat | grep com.securescanner.doc_scanner

# Filter by Flutter
adb logcat | grep flutter

# Clear and monitor
adb logcat -c && adb logcat

# Save to file
adb logcat > app_logs.txt
```

#### Common Android Issues

1. **Keystore Access**
```kotlin
// Check keystore
val keyStore = KeyStore.getInstance("AndroidKeyStore")
keyStore.load(null)
val hasKey = keyStore.containsAlias("master_key")
```

2. **Permissions**
```bash
# Check granted permissions
adb shell dumpsys package com.securescanner.doc_scanner | grep permission
```

3. **Storage Access**
```dart
// Android storage paths
final extDir = await getExternalStorageDirectory();
final appDir = await getApplicationDocumentsDirectory();
print('External: ${extDir?.path}');
print('App: ${appDir.path}');
```

## Performance Profiling

### Flutter Performance Overlay

```dart
// Enable in app
void main() {
  runApp(
    MaterialApp(
      showPerformanceOverlay: true, // Shows FPS and GPU stats
      home: HomeScreen(),
    ),
  );
}
```

### Timeline Tracing

```dart
import 'dart:developer';

Future<void> processDocument() async {
  Timeline.startSync('ProcessDocument');

  Timeline.startSync('OCR');
  final ocrResult = await ocrService.recognize(image);
  Timeline.finishSync();

  Timeline.startSync('Encryption');
  final encrypted = encryptionService.encrypt(data);
  Timeline.finishSync();

  Timeline.finishSync();
}
```

View in DevTools Timeline tab.

### Memory Profiling

```dart
import 'dart:developer';

// Force garbage collection (debug only)
void debugGC() {
  if (kDebugMode) {
    print('Forcing GC...');
    // Note: Dart doesn't provide direct GC access
    // Use DevTools memory profiler instead
  }
}

// Track object allocations
Timeline.startSync('CreateDocuments');
for (int i = 0; i < 1000; i++) {
  final doc = Document(...);
}
Timeline.finishSync();
```

### Database Performance

```dart
// Measure query time
final stopwatch = Stopwatch()..start();
final results = await db.searchDocuments(query: 'test');
stopwatch.stop();
print('Search took ${stopwatch.elapsedMilliseconds}ms');
print('Results: ${results.length}');

// Analyze query plan
final plan = await db.rawQuery('EXPLAIN QUERY PLAN SELECT * FROM documents_fts WHERE documents_fts MATCH ?', ['test']);
print('Query plan: $plan');
```

## Security Debugging

### Key Verification

```dart
// Verify key derivation (DO NOT log actual keys!)
final salt = encryptionService.generateSalt();
final key1 = encryptionService.deriveKey(password: 'test', salt: salt);
final key2 = encryptionService.deriveKey(password: 'test', salt: salt);

print('Keys match: ${listEquals(key1, key2)}');
print('Key length: ${key1.length} bytes');

// Verify different passwords produce different keys
final key3 = encryptionService.deriveKey(password: 'different', salt: salt);
print('Different keys: ${!listEquals(key1, key3)}');
```

### Encryption Roundtrip Test

```dart
// Test encrypt/decrypt
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

assert(listEquals(plaintext, decrypted), 'Roundtrip failed!');
print('Encryption roundtrip: OK');
```

### Audit Log Verification

```dart
// Verify all operations are logged
final beforeCount = await db.getAuditEvents(limit: 1000);
print('Audit events before: ${beforeCount.length}');

// Perform operation
await documentRepo.createDocument(...);

final afterCount = await db.getAuditEvents(limit: 1000);
print('Audit events after: ${afterCount.length}');

assert(afterCount.length == beforeCount.length + 1,
       'Document creation not logged!');
```

## Debugging Best Practices

1. **Use Conditional Logging**
```dart
void debugLog(String message) {
  if (kDebugMode) {
    print('[DEBUG] $message');
  }
}
```

2. **Log Levels**
```dart
enum LogLevel { debug, info, warning, error }

void log(String message, {LogLevel level = LogLevel.info}) {
  if (!kDebugMode && level == LogLevel.debug) return;

  final prefix = {
    LogLevel.debug: '🔍',
    LogLevel.info: 'ℹ️',
    LogLevel.warning: '⚠️',
    LogLevel.error: '❌',
  }[level];

  print('$prefix $message');
}
```

3. **Exception Handling**
```dart
try {
  await riskyOperation();
} catch (e, stackTrace) {
  log('Operation failed: $e', level: LogLevel.error);
  log('Stack trace: $stackTrace', level: LogLevel.debug);

  // Report to crash analytics in production
  if (kReleaseMode) {
    await crashlytics.recordError(e, stackTrace);
  }
}
```

4. **Feature Flags for Debugging**
```dart
class DebugConfig {
  static const bool verboseLogging = kDebugMode;
  static const bool saveIntermediateImages = kDebugMode;
  static const bool skipEncryption = false; // Never true in production!
}
```

## Useful Commands

```bash
# Clear app data (Android)
adb shell pm clear com.securescanner.doc_scanner

# Uninstall app
adb uninstall com.securescanner.doc_scanner
# or iOS
xcrun simctl uninstall booted com.securescanner.doc_scanner

# List devices
flutter devices

# Hot reload
r (in flutter run console)

# Hot restart
R (in flutter run console)

# Take screenshot
s (in flutter run console)

# Quit
q (in flutter run console)

# Analyze code
flutter analyze

# Run specific test
flutter test test/encryption_service_test.dart

# Code coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Getting Help

If you encounter issues not covered here:

1. Check [Flutter DevTools](https://docs.flutter.dev/development/tools/devtools/overview)
2. Search [Flutter Issues](https://github.com/flutter/flutter/issues)
3. Review [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)
4. Check package-specific documentation
5. File an issue in this repository

---

For deployment and testing guides, see:
- [DEPLOYMENT.md](DEPLOYMENT.md)
- [TESTING.md](TESTING.md)
