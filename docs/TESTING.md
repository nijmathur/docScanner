# Testing Guide

Comprehensive testing guide for the Secure Document Scanner application.

## Table of Contents

- [Testing Strategy](#testing-strategy)
- [Unit Testing](#unit-testing)
- [Widget Testing](#widget-testing)
- [Integration Testing](#integration-testing)
- [Security Testing](#security-testing)
- [Performance Testing](#performance-testing)
- [Manual Testing Checklist](#manual-testing-checklist)
- [Test Coverage](#test-coverage)

## Testing Strategy

### Test Pyramid

```
        /\
       /  \  E2E Tests (5%)
      /----\
     /      \ Integration Tests (15%)
    /--------\
   /          \ Unit Tests (80%)
  /____________\
```

### Test Types

1. **Unit Tests** - Test individual functions and classes
2. **Widget Tests** - Test UI components in isolation
3. **Integration Tests** - Test complete user flows
4. **Security Tests** - Test encryption, authentication, access control
5. **Performance Tests** - Test app speed and resource usage

## Unit Testing

### Setup

`pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.6
```

### Test Structure

`test/core/services/encryption_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doc_scanner/core/services/encryption_service.dart';
import 'dart:typed_data';

void main() {
  group('EncryptionService', () {
    late EncryptionService encryptionService;

    setUp(() {
      encryptionService = EncryptionService();
    });

    test('generates salt of correct length', () {
      final salt = encryptionService.generateSalt();
      expect(salt.length, equals(32));
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

    test('computeChecksum produces consistent SHA-256 hash', () {
      final data = Uint8List.fromList('test data'.codeUnits);

      final checksum1 = encryptionService.computeChecksum(data);
      final checksum2 = encryptionService.computeChecksum(data);

      expect(checksum1, equals(checksum2));
      expect(checksum1.length, equals(64)); // SHA-256 hex string
    });
  });
}
```

### Run Unit Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/services/encryption_service_test.dart

# Run with coverage
flutter test --coverage

# Watch mode (reruns on file change)
flutter test --watch
```

### Testing Database Service

`test/core/services/database_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:doc_scanner/core/services/database_service.dart';
import 'package:doc_scanner/core/domain/entities/document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('DatabaseService', () {
    late DatabaseService databaseService;

    setUp(() async {
      databaseService = DatabaseService();
      databaseFactory = databaseFactoryFfi;
      await databaseService.getDatabase('test_password');
    });

    tearDown(() async {
      await databaseService.close();
    });

    test('insertDocument and getDocument work correctly', () async {
      final document = Document(
        id: 'test-id',
        title: 'Test Document',
        documentType: 'Receipt',
        captureDate: DateTime.now(),
        createdAt: DateTime.now(),
        encryptedImagePath: '/path/to/image',
        encryptedThumbnailPath: '/path/to/thumb',
        ocrText: 'Test OCR text',
        checksum: 'abc123',
        fileSizeBytes: 1024,
      );

      await databaseService.insertDocument(document);
      final retrieved = await databaseService.getDocument('test-id');

      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Test Document'));
      expect(retrieved.ocrText, equals('Test OCR text'));
    });

    test('searchDocuments finds matching documents', () async {
      final doc1 = Document(
        id: 'doc-1',
        title: 'Invoice for Mangoes',
        documentType: 'Invoice',
        captureDate: DateTime.now(),
        createdAt: DateTime.now(),
        encryptedImagePath: '/path/1',
        encryptedThumbnailPath: '/path/1/thumb',
        ocrText: 'Invoice Total: \$50 for mangoes',
        checksum: 'check1',
        fileSizeBytes: 1024,
      );

      final doc2 = Document(
        id: 'doc-2',
        title: 'Receipt for Apples',
        documentType: 'Receipt',
        captureDate: DateTime.now(),
        createdAt: DateTime.now(),
        encryptedImagePath: '/path/2',
        encryptedThumbnailPath: '/path/2/thumb',
        ocrText: 'Receipt Total: \$30 for apples',
        checksum: 'check2',
        fileSizeBytes: 512,
      );

      await databaseService.insertDocument(doc1);
      await databaseService.insertDocument(doc2);

      final results = await databaseService.searchDocuments(
        query: 'mangoes',
      );

      expect(results.length, equals(1));
      expect(results.first.title, contains('Mangoes'));
    });
  });
}
```

### Testing OCR Service

`test/core/services/ocr_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doc_scanner/core/services/ocr_service.dart';
// Note: OCR testing requires real images or mocks

void main() {
  group('OCRService', () {
    test('extractPatterns finds dates', () {
      final service = OCRService();
      final text = 'Invoice Date: 2024-01-15\nAmount: \$100.00';

      final patterns = service.extractPatterns(text);

      expect(patterns['dates'], isNotEmpty);
      expect(patterns['dates']!.first, equals('2024-01-15'));
    });

    test('extractPatterns finds amounts', () {
      final service = OCRService();
      final text = 'Total: \$1,234.56';

      final patterns = service.extractPatterns(text);

      expect(patterns['amounts'], isNotEmpty);
      expect(patterns['amounts']!.first, contains('1,234.56'));
    });

    test('suggestDocumentType identifies invoices', () {
      final service = OCRService();
      final text = 'INVOICE\nBill To: John Doe\nTotal Amount: \$500';

      final type = service.suggestDocumentType(text);

      expect(type, equals('Invoice'));
    });
  });
}
```

## Widget Testing

### Setup

Widget tests verify UI components render correctly.

### Example Widget Test

`test/features/auth/auth_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:doc_scanner/features/auth/screens/auth_screen.dart';
import 'package:doc_scanner/core/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([AuthService, AuditService])
import 'auth_screen_test.mocks.dart';

void main() {
  group('AuthScreen Widget Tests', () {
    late MockAuthService mockAuthService;
    late MockAuditService mockAuditService;

    setUp(() {
      mockAuthService = MockAuthService();
      mockAuditService = MockAuditService();
    });

    testWidgets('displays PIN input fields in setup mode',
        (WidgetTester tester) async {
      when(mockAuthService.isSetUp()).thenAnswer((_) async => false);
      when(mockAuthService.getFailedAttempts()).thenAnswer((_) async => 0);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuthService),
            Provider<AuditService>.value(value: mockAuditService),
          ],
          child: const MaterialApp(home: AuthScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Set Up PIN'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Confirm PIN'), findsOneWidget);
    });

    testWidgets('displays error message for mismatched PINs',
        (WidgetTester tester) async {
      when(mockAuthService.isSetUp()).thenAnswer((_) async => false);
      when(mockAuthService.getFailedAttempts()).thenAnswer((_) async => 0);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthService>.value(value: mockAuthService),
            Provider<AuditService>.value(value: mockAuditService),
          ],
          child: const MaterialApp(home: AuthScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Enter different PINs
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.enterText(find.byType(TextField).last, '654321');
      await tester.tap(find.text('Set Up PIN'));
      await tester.pumpAndSettle();

      expect(find.text('PINs do not match'), findsOneWidget);
    });
  });
}
```

### Generate Mocks

```bash
flutter pub run build_runner build
```

## Integration Testing

### Setup

`integration_test/` directory:
```bash
mkdir integration_test
```

`integration_test/app_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:doc_scanner/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Test', () {
    testWidgets('complete document creation flow',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Setup PIN
      expect(find.text('Set Up PIN'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.tap(find.text('Set Up PIN'));
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Navigate to home screen
      expect(find.text('Secure Document Scanner'), findsOneWidget);

      // Tap camera button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify camera screen (or mock)
      // Add document capture flow...
    });

    testWidgets('search functionality works', (WidgetTester tester) async {
      // Setup and create some documents
      // ...

      // Test search
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'invoice');
      await tester.pumpAndSettle(Duration(milliseconds: 500));

      // Verify results
      expect(find.text('Invoice'), findsWidgets);
    });
  });
}
```

### Run Integration Tests

```bash
# Android
flutter test integration_test/app_test.dart

# iOS
flutter test integration_test/app_test.dart -d iPhone

# With driver
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart
```

## Security Testing

### Encryption Tests

`test/security/encryption_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doc_scanner/core/services/encryption_service.dart';
import 'dart:typed_data';

void main() {
  group('Security - Encryption', () {
    final service = EncryptionService();

    test('AES-256-GCM provides confidentiality', () {
      final plaintext = Uint8List.fromList('sensitive data'.codeUnits);
      final key = service.generateSalt();

      final ciphertext = service.encryptBytes(
        plaintext: plaintext,
        key: key,
      );

      // Ciphertext should not contain plaintext
      final ciphertextString = String.fromCharCodes(ciphertext);
      expect(ciphertextString, isNot(contains('sensitive')));
    });

    test('encryption uses unique IV for each operation', () {
      final plaintext = Uint8List.fromList('test'.codeUnits);
      final key = service.generateSalt();

      final ciphertext1 = service.encryptBytes(
        plaintext: plaintext,
        key: key,
      );
      final ciphertext2 = service.encryptBytes(
        plaintext: plaintext,
        key: key,
      );

      // Same plaintext + key but different IVs = different ciphertexts
      expect(ciphertext1, isNot(equals(ciphertext2)));
    });

    test('tampering with ciphertext causes decryption failure', () {
      final plaintext = Uint8List.fromList('test'.codeUnits);
      final key = service.generateSalt();

      final ciphertext = service.encryptBytes(
        plaintext: plaintext,
        key: key,
      );

      // Tamper with ciphertext
      ciphertext[20] ^= 0xFF;

      expect(
        () => service.decryptBytes(ciphertext: ciphertext, key: key),
        throwsException,
      );
    });

    test('PBKDF2 iterations are computationally expensive', () {
      final stopwatch = Stopwatch()..start();

      service.deriveKey(
        password: 'password',
        salt: service.generateSalt(),
        iterations: 100000,
      );

      stopwatch.stop();

      // Should take at least 50ms (prevents easy brute force)
      expect(stopwatch.elapsedMilliseconds, greaterThan(50));
    });
  });
}
```

### Authentication Tests

`test/security/auth_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doc_scanner/core/services/auth_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([FlutterSecureStorage])
import 'auth_test.mocks.dart';

void main() {
  group('Security - Authentication', () {
    test('PIN must be exactly 6 digits', () async {
      final authService = AuthService();

      expect(
        () => authService.setupPIN('12345'),
        throwsException,
      );

      expect(
        () => authService.setupPIN('1234567'),
        throwsException,
      );

      expect(
        () => authService.setupPIN('abcdef'),
        throwsException,
      );
    });

    test('failed attempts are tracked', () async {
      // Test that failed authentication increments counter
      // Test that max attempts locks account
    });

    test('session timeout works correctly', () async {
      // Test that session expires after timeout
    });
  });
}
```

## Performance Testing

### Benchmark Tests

`test/performance/search_benchmark.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doc_scanner/core/services/database_service.dart';

void main() {
  group('Performance Benchmarks', () {
    test('search performs well with 10k documents', () async {
      final dbService = DatabaseService();
      await dbService.getDatabase('test');

      // Insert 10,000 documents
      for (int i = 0; i < 10000; i++) {
        await dbService.insertDocument(createTestDocument(i));
      }

      // Measure search time
      final stopwatch = Stopwatch()..start();
      final results = await dbService.searchDocuments(query: 'test');
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500));
      print('Search took ${stopwatch.elapsedMilliseconds}ms');
    });

    test('OCR processes image within 10 seconds', () async {
      final ocrService = OCRService();
      final stopwatch = Stopwatch()..start();

      await ocrService.recognizeText('/path/to/test/image.jpg');

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));
    });
  });
}
```

### Memory Leak Detection

```dart
import 'dart:developer';

test('no memory leaks in document creation', () async {
  // Force GC before
  await Future.delayed(Duration(seconds: 1));

  final beforeMemory = await ServiceExtensions.getMemoryUsage();

  // Create and destroy 100 documents
  for (int i = 0; i < 100; i++) {
    final doc = await createDocument();
    // Dispose
  }

  // Force GC after
  await Future.delayed(Duration(seconds: 1));

  final afterMemory = await ServiceExtensions.getMemoryUsage();

  // Memory should not grow significantly
  final growth = afterMemory.current - beforeMemory.current;
  expect(growth, lessThan(10000000)); // < 10MB
});
```

## Manual Testing Checklist

### Authentication Flow
- [ ] PIN setup accepts 6-digit PIN
- [ ] PIN setup rejects invalid PINs (< 6, > 6, non-numeric)
- [ ] PIN confirmation must match
- [ ] Authentication succeeds with correct PIN
- [ ] Authentication fails with incorrect PIN
- [ ] Failed attempts are counted
- [ ] Account locks after 5 failed attempts
- [ ] Biometric authentication works (Face ID, Touch ID, Fingerprint)
- [ ] Biometric fallback to PIN works
- [ ] Session timeout works correctly

### Document Capture
- [ ] Camera opens successfully
- [ ] Document edges detected correctly
- [ ] Perspective correction applied
- [ ] Image preview shows processed image
- [ ] User can retake photo
- [ ] Metadata fields accept input
- [ ] Document saves successfully
- [ ] OCR text extracted correctly
- [ ] Thumbnail generated

### Search
- [ ] Simple search finds documents
- [ ] Boolean operators work (AND, OR, NOT)
- [ ] Phrase search works
- [ ] Wildcard search works
- [ ] Search results display correctly
- [ ] Tapping result opens document
- [ ] Search performance is acceptable
- [ ] Empty results handled gracefully

### Document Management
- [ ] Document list loads
- [ ] Document detail opens
- [ ] Image decrypts and displays
- [ ] OCR text displays
- [ ] Edit metadata works
- [ ] Delete document works
- [ ] Document types filter correctly

### Backup & Restore
- [ ] Cloud provider authentication works
- [ ] Backup password accepts input
- [ ] Backup creation succeeds
- [ ] Backup upload completes
- [ ] Backup list displays
- [ ] Restore prompts for password
- [ ] Restore with correct password succeeds
- [ ] Restore with incorrect password fails
- [ ] Data intact after restore

### Settings
- [ ] Change PIN works
- [ ] Enable/disable biometric works
- [ ] Inactivity timeout changes
- [ ] Cloud provider selection works
- [ ] View audit log works

### Edge Cases
- [ ] App handles low storage gracefully
- [ ] App handles network errors
- [ ] App handles camera permission denial
- [ ] App handles biometric enrollment changes
- [ ] App handles app backgrounding
- [ ] App handles app termination
- [ ] App handles device rotation

## Test Coverage

### Generate Coverage Report

```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html
```

### Coverage Goals

| Component | Target Coverage |
|-----------|----------------|
| Core Services | 90%+ |
| Repositories | 85%+ |
| UI Screens | 70%+ |
| Overall | 80%+ |

### View Coverage

```bash
# Install lcov
brew install lcov  # macOS
sudo apt-get install lcov  # Linux

# Generate report
lcov --list coverage/lcov.info
```

## Continuous Integration

### GitHub Actions

`.github/workflows/test.yml`:
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze code
        run: flutter analyze

      - name: Run tests
        run: flutter test --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: coverage/lcov.info
```

## Testing Tools & Resources

- **Flutter Test**: Built-in testing framework
- **Mockito**: Mocking library
- **Integration Test**: E2E testing
- **Patrol**: Advanced integration testing
- **Golden Toolkit**: Pixel-perfect widget tests
- **Bloc Test**: Testing state management

---

For debugging and deployment guides:
- [DEBUGGING.md](DEBUGGING.md)
- [DEPLOYMENT.md](DEPLOYMENT.md)
