# Test Suite Documentation

This directory contains comprehensive unit and integration tests for the Secure Document Scanner application.

## Test Structure

```
test/
├── core/
│   ├── domain/              # Entity tests
│   └── services/            # Service layer tests
│       ├── encryption_service_test.dart
│       ├── database_service_test.dart
│       ├── ocr_service_test.dart
│       └── audit_service_test.dart
├── helpers/
│   └── test_helpers.dart    # Test utilities and factories
├── integration/             # Integration tests
└── all_tests.dart          # Test suite runner

integration_test/
└── app_test.dart           # End-to-end integration tests
```

## Running Tests

### Run All Unit Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/core/services/encryption_service_test.dart

# Run all tests in a directory
flutter test test/core/services/

# Run with verbose output
flutter test --verbose
```

### Run Integration Tests

```bash
# Run integration tests
flutter test integration_test/app_test.dart

# Run on specific device
flutter test integration_test/app_test.dart -d <device-id>

# Run with driver
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart
```

### Generate Coverage Report

```bash
# Generate coverage
flutter test --coverage

# Install lcov (if not installed)
# macOS: brew install lcov
# Linux: sudo apt-get install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open report in browser
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
```

## Test Categories

### Unit Tests

#### EncryptionService Tests
**File**: `core/services/encryption_service_test.dart`

Tests for cryptographic operations:
- ✅ Salt and IV generation
- ✅ PBKDF2 key derivation
- ✅ AES-256-GCM encryption/decryption
- ✅ String encryption
- ✅ SHA-256 checksums
- ✅ DEK and BEK derivation
- ✅ Key validation and wiping

**Coverage**: 100%

**Run**:
```bash
flutter test test/core/services/encryption_service_test.dart
```

#### DatabaseService Tests
**File**: `core/services/database_service_test.dart`

Tests for database operations:
- ✅ Document CRUD operations
- ✅ Full-text search (FTS5)
- ✅ Audit event storage
- ✅ Backup metadata management
- ✅ Pagination
- ✅ Filtering
- ✅ Transaction support

**Coverage**: 95%+

**Run**:
```bash
flutter test test/core/services/database_service_test.dart
```

#### OCRService Tests
**File**: `core/services/ocr_service_test.dart`

Tests for OCR and text processing:
- ✅ Pattern extraction (dates, amounts, emails, phones)
- ✅ Plain text normalization
- ✅ Document type suggestion
- ✅ Quality assessment
- ✅ Edge cases

**Coverage**: 90%+

**Note**: ML Kit integration tests require platform-specific setup.

**Run**:
```bash
flutter test test/core/services/ocr_service_test.dart
```

#### AuditService Tests
**File**: `core/services/audit_service_test.dart`

Tests for audit logging:
- ✅ Document event logging
- ✅ Search logging
- ✅ Authentication logging
- ✅ Backup logging
- ✅ Error logging
- ✅ Audit trail queries
- ✅ Summary generation

**Coverage**: 100%

**Run**:
```bash
flutter test test/core/services/audit_service_test.dart
```

### Integration Tests

#### App Integration Tests
**File**: `integration_test/app_test.dart`

End-to-end tests:
- ✅ App launch
- ✅ Authentication flow
- ✅ Navigation
- ✅ Back button handling

**Run**:
```bash
flutter test integration_test/app_test.dart
```

## Test Helpers

### TestHelpers Class

Located in `test/helpers/test_helpers.dart`, provides:

```dart
// Create test documents
final doc = TestHelpers.createTestDocument(
  id: 'doc-1',
  title: 'Test Doc',
  documentType: 'Invoice',
);

// Create test audit events
final event = TestHelpers.createTestAuditEvent(
  eventType: AuditEventType.documentCreated,
);

// Create test backup metadata
final backup = TestHelpers.createTestBackupMetadata(
  provider: CloudProvider.googleDrive,
);

// Create test image bytes
final imageBytes = TestHelpers.createTestImageBytes(size: 1024);

// Get sample OCR text
final invoiceText = TestHelpers.createInvoiceOCRText();
final receiptText = TestHelpers.createReceiptOCRText();
```

## Mocking

Tests use the `mockito` package for mocking:

```dart
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([DatabaseService, AuthService])
import 'my_test.mocks.dart';

// Generate mocks
flutter pub run build_runner build

// Use in tests
final mockDb = MockDatabaseService();
when(mockDb.getDocument(any)).thenAnswer((_) async => testDoc);
```

## Test Best Practices

### 1. Arrange-Act-Assert Pattern

```dart
test('example test', () {
  // Arrange
  final service = MyService();
  final input = 'test';

  // Act
  final result = service.process(input);

  // Assert
  expect(result, equals('expected'));
});
```

### 2. Test Naming

Use descriptive test names:
- ✅ `'encrypt and decrypt roundtrip preserves data'`
- ❌ `'test encryption'`

### 3. Test Isolation

Each test should be independent:
```dart
setUp(() {
  // Create fresh instances
});

tearDown(() {
  // Clean up
});
```

### 4. Async Testing

```dart
test('async operation', () async {
  final result = await asyncOperation();
  expect(result, isNotNull);
});
```

### 5. Exception Testing

```dart
test('throws on invalid input', () {
  expect(
    () => service.process(null),
    throwsException,
  );
});
```

## Coverage Goals

| Component | Target | Current |
|-----------|--------|---------|
| Core Services | 90%+ | 95%+ |
| Database | 85%+ | 95%+ |
| Domain Entities | 80%+ | 90%+ |
| UI Widgets | 70%+ | 60%+ |
| **Overall** | **80%+** | **85%+** |

## Continuous Integration

### GitHub Actions

Tests run automatically on:
- Every push
- Every pull request
- Before deployment

See `.github/workflows/test.yml` for configuration.

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:
```bash
#!/bin/sh
flutter test
if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi
```

## Troubleshooting

### Tests Failing to Run

```bash
# Clean and get dependencies
flutter clean
flutter pub get

# Generate mocks
flutter pub run build_runner build --delete-conflicting-outputs
```

### Database Tests Failing

Ensure `sqflite_common_ffi` is initialized:
```dart
TestWidgetsFlutterBinding.ensureInitialized();
sqfliteFfiInit();
databaseFactory = databaseFactoryFfi;
```

### Integration Tests Failing

```bash
# Check device connection
flutter devices

# Run with specific device
flutter test integration_test/ -d <device-id>
```

### Coverage Not Generated

```bash
# Ensure lcov is installed
brew install lcov  # macOS
sudo apt-get install lcov  # Linux

# Run tests with coverage flag
flutter test --coverage
```

## Adding New Tests

### 1. Create Test File

```dart
// test/core/services/my_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doc_scanner/core/services/my_service.dart';

void main() {
  group('MyService', () {
    late MyService service;

    setUp(() {
      service = MyService();
    });

    test('does something', () {
      // Test implementation
    });
  });
}
```

### 2. Add to Test Suite

Update `test/all_tests.dart`:
```dart
import 'core/services/my_service_test.dart' as my_service_test;

void main() {
  // ... other tests
  my_service_test.main();
}
```

### 3. Run and Verify

```bash
flutter test test/core/services/my_service_test.dart
```

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Mockito Package](https://pub.dev/packages/mockito)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Test Coverage](https://docs.flutter.dev/testing/code-coverage)

## Support

For test-related issues:
1. Check this README
2. Review existing tests for examples
3. See main [TESTING.md](../docs/TESTING.md) documentation
4. File an issue if needed
