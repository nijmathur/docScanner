# Implementation Guide

## Overview

This document provides detailed implementation guidance for the Secure Document Scanner application. It covers architecture decisions, security implementation, and extension points.

## Architecture Details

### Clean Architecture Layers

#### 1. Domain Layer (`lib/core/domain/`)
- **Purpose**: Business logic and entities
- **Dependencies**: None (pure Dart)
- **Components**:
  - `entities/` - Core business objects (Document, AuditEvent, BackupMetadata)

#### 2. Data Layer (`lib/core/data/`)
- **Purpose**: Data access and manipulation
- **Dependencies**: Domain layer, external packages
- **Components**:
  - `datasources/` - Data sources (local, remote)
  - `models/` - Data transfer objects
  - `repositories_impl/` - Repository implementations

#### 3. Services Layer (`lib/core/services/`)
- **Purpose**: Reusable services across features
- **Key Services**:
  - `AuthService` - Authentication and session management
  - `DatabaseService` - SQLCipher database operations
  - `EncryptionService` - Cryptographic operations
  - `OCRService` - Text recognition
  - `ImageProcessingService` - Image manipulation
  - `AuditService` - Audit logging
  - `BackupService` - Backup/restore operations

#### 4. Features Layer (`lib/features/`)
- **Purpose**: UI and feature-specific logic
- **Structure**: Each feature has its own folder with screens, widgets, and state

## Security Implementation

### Encryption Flow

```
User PIN/Biometric
    ↓ (PBKDF2, 100k iterations)
Master Key (stored in OS keychain)
    ↓ (HKDF-SHA256)
Data Encryption Key (DEK)
    ↓ (AES-256-GCM)
Encrypted Documents
```

### Key Derivation Details

**Master Key Derivation:**
```dart
PBKDF2(
  password: userPIN,
  salt: randomSalt (32 bytes),
  iterations: 100000,
  keyLength: 32 bytes
)
```

**DEK Derivation:**
```dart
HKDF-SHA256(
  masterKey: masterKey,
  info: "DEK:context",
  length: 32 bytes
)
```

**Backup Encryption Key:**
```dart
PBKDF2(
  password: backupPassword,
  salt: backupSalt (32 bytes),
  iterations: 100000,
  keyLength: 32 bytes
)
```

### Database Encryption

- **Engine**: SQLCipher (based on SQLite)
- **Cipher**: AES-256 CBC
- **Key Derivation**: PBKDF2
- **Page Size**: 4096 bytes
- **KDF Iterations**: Configurable (default: 256000)

### File Encryption Format

**Encrypted File Structure:**
```
[IV (16 bytes)] [Ciphertext (variable)] [Auth Tag (16 bytes)]
```

**Backup Archive Structure:**
```
[Salt (32 bytes)] [IV (16 bytes)] [Encrypted Archive] [Auth Tag]
```

## Database Schema

### Documents Table
```sql
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  documentType TEXT NOT NULL,
  captureDate TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT,
  encryptedImagePath TEXT NOT NULL,
  encryptedThumbnailPath TEXT NOT NULL,
  ocrText TEXT NOT NULL,
  checksum TEXT NOT NULL,
  fileSizeBytes INTEGER NOT NULL,
  tags TEXT,
  metadata TEXT,
  isDeleted INTEGER NOT NULL DEFAULT 0,
  ocrConfidence REAL
);
```

### FTS5 Virtual Table
```sql
CREATE VIRTUAL TABLE documents_fts USING fts5(
  doc_id UNINDEXED,
  title,
  ocrText,
  tags,
  content='documents',
  content_rowid='rowid'
);
```

### Audit Events Table
```sql
CREATE TABLE audit_events (
  id TEXT PRIMARY KEY,
  eventType TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  userId TEXT,
  deviceId TEXT,
  documentId TEXT,
  payload TEXT,
  errorMessage TEXT
);
```

## OCR Implementation

### Google ML Kit Integration

```dart
// Initialize
final textRecognizer = TextRecognizer(
  script: TextRecognitionScript.latin
);

// Process image
final inputImage = InputImage.fromFilePath(imagePath);
final recognizedText = await textRecognizer.processImage(inputImage);

// Extract text
final fullText = recognizedText.text;
final blocks = recognizedText.blocks; // for layout info
```

### Supported Languages
- Latin script (default)
- Chinese
- Devanagari
- Japanese
- Korean

## Image Processing Pipeline

### Document Capture Flow

```
Camera Capture
    ↓
Edge Detection (OpenCV-based)
    ↓
Perspective Correction
    ↓
Grayscale Conversion
    ↓
Contrast Enhancement
    ↓
Noise Reduction
    ↓
Compression (JPEG 85% quality)
    ↓
Thumbnail Generation (300x300)
    ↓
Encryption
    ↓
Storage
```

### Document Scanning and Edge Detection

The app uses the `flutter_doc_scanner` package which provides:
- Automatic document edge detection
- Real-time camera preview with edge overlay
- Perspective transformation and cropping
- Image enhancement and optimization
- Multi-platform support (iOS, Android, Web)

## Cloud Integration

### CloudStorageGateway Interface

All cloud providers implement this interface:

```dart
abstract class CloudStorageGateway {
  Future<bool> authenticate();
  Future<CloudFileMetadata> uploadFile({...});
  Future<String> downloadFile({...});
  Future<List<CloudFileMetadata>> listFiles({...});
  Future<void> deleteFile(String remotePath);
  // ... other methods
}
```

### Implementing New Cloud Provider

Example: Implementing Dropbox Gateway

```dart
class DropboxGateway implements CloudStorageGateway {
  final DropboxClient _client;

  @override
  String get providerName => 'Dropbox';

  @override
  Future<bool> authenticate() async {
    // Implement OAuth2 flow
    // Store access token securely
    return true;
  }

  @override
  Future<CloudFileMetadata> uploadFile({...}) async {
    // Use Dropbox API to upload
    // Return metadata
  }

  // Implement other methods...
}
```

## Search Implementation

### FTS5 Query Syntax

**Simple Search:**
```sql
SELECT * FROM documents_fts WHERE documents_fts MATCH 'invoice';
```

**Boolean Operators:**
```sql
-- AND
WHERE documents_fts MATCH 'invoice AND 2024'

-- OR
WHERE documents_fts MATCH 'invoice OR receipt'

-- NOT
WHERE documents_fts MATCH 'invoice NOT paid'
```

**Phrase Search:**
```sql
WHERE documents_fts MATCH '"medical records"'
```

**Wildcard:**
```sql
WHERE documents_fts MATCH 'invoic*'
```

### Search Performance

- **Indexing**: Automatic via triggers
- **Query Time**: O(log n) with FTS5 index
- **Optimization**:
  - Use NEAR operator for proximity
  - Use column-specific search: `title:invoice`
  - Limit results with LIMIT clause

## State Management

### Provider Pattern

The app uses Provider for dependency injection and state management:

```dart
MultiProvider(
  providers: [
    Provider<EncryptionService>(...),
    Provider<AuthService>(...),
    Provider<DatabaseService>(...),
    ProxyProvider<DatabaseService, AuditService>(...),
  ],
  child: MaterialApp(...),
)
```

### Accessing Services in Widgets

```dart
// Read once (build time)
final authService = context.read<AuthService>();

// Watch for changes
final documents = context.watch<DocumentProvider>().documents;
```

## Error Handling

### Exception Hierarchy

```
Exception
  ├── CloudStorageException
  ├── EncryptionException
  ├── AuthenticationException
  └── DatabaseException
```

### Error Handling Pattern

```dart
try {
  await operation();
} on CloudStorageException catch (e) {
  // Handle cloud-specific error
  logger.error('Cloud error: ${e.message}');
  await auditService.logError(e);
} on EncryptionException catch (e) {
  // Handle encryption error
  await auditService.logDecryptionError(e);
} catch (e) {
  // Handle unexpected error
  logger.error('Unexpected error: $e');
}
```

## Testing Strategy

### Unit Tests
- Service layer methods
- Encryption/decryption
- Key derivation
- Search queries

### Integration Tests
- End-to-end document creation flow
- Backup/restore process
- Authentication flow

### Widget Tests
- UI components
- Navigation
- Form validation

### Example Unit Test

```dart
test('AES-256-GCM encryption/decryption', () async {
  final service = EncryptionService();
  final key = service.generateSalt(); // 32 bytes
  final plaintext = Uint8List.fromList('test data'.codeUnits);

  final encrypted = service.encryptBytes(
    plaintext: plaintext,
    key: key,
  );

  final decrypted = service.decryptBytes(
    ciphertext: encrypted,
    key: key,
  );

  expect(decrypted, equals(plaintext));
});
```

## Performance Optimization

### Database Optimization

```dart
// Enable WAL mode for better concurrency
PRAGMA journal_mode = WAL;

// Optimize for in-memory operations
PRAGMA temp_store = MEMORY;

// Increase cache size
PRAGMA cache_size = -64000; // 64MB
```

### Image Optimization

- Use appropriate JPEG quality (85% for full, 75% for thumbnails)
- Lazy load images in lists
- Cache thumbnails in memory
- Use Hero animations for smooth transitions

### Search Optimization

- Index frequently searched fields
- Use pagination (LIMIT/OFFSET)
- Debounce search input (300ms)
- Cache recent searches

## Extending the Application

### Adding New Document Types

1. Update `documentType` enum
2. Add type-specific icons
3. Implement type-specific OCR patterns
4. Add filtering in search

### Adding New Cloud Providers

1. Implement `CloudStorageGateway` interface
2. Add OAuth2 configuration
3. Register in `CloudProvider` enum
4. Update settings screen

### Adding PDF Export

```dart
class PDFExportService {
  Future<File> exportToPDF(Document document) async {
    final pdf = pw.Document();
    final image = await getDocumentImage(document.id);

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Image(
          pw.MemoryImage(image),
        ),
      ),
    );

    return await savePDF(pdf, document.title);
  }
}
```

## Compliance & Regulations

### GDPR Compliance
- ✅ Data minimization (only necessary data collected)
- ✅ Right to erasure (document deletion)
- ✅ Data portability (export functionality)
- ✅ Encryption at rest and in transit
- ✅ Audit logs for compliance

### HIPAA Considerations
- ✅ Encryption of PHI
- ✅ Access controls (PIN/biometric)
- ✅ Audit logging
- ⚠️ Business Associate Agreement needed for cloud providers
- ⚠️ Additional access controls may be required

## Deployment

### iOS Deployment

1. Configure code signing
2. Set deployment target (iOS 14+)
3. Configure app capabilities:
   - Camera
   - Face ID
   - Keychain Sharing

### Android Deployment

1. Configure signing keys
2. Set minimum SDK (API 29 / Android 10)
3. Configure ProGuard rules:
```
-keep class com.securescanner.doc_scanner.** { *; }
-keep class io.flutter.** { *; }
```

### App Store Requirements

**iOS:**
- Privacy policy URL
- Camera usage description
- Face ID usage description
- Encryption export compliance

**Android:**
- Privacy policy URL
- Camera permission justification
- Encryption disclosure

## Troubleshooting

### Common Issues

**Issue**: Database encryption fails
**Solution**: Ensure password is set before first database access

**Issue**: OCR returns empty text
**Solution**: Check image quality, ensure sufficient lighting

**Issue**: Biometric authentication not available
**Solution**: Check device capability, permissions granted

**Issue**: Cloud upload fails
**Solution**: Verify OAuth tokens, check network connectivity

## Best Practices

1. **Security**
   - Never log sensitive data
   - Wipe keys from memory after use
   - Use OS-level secure storage
   - Validate all inputs

2. **Performance**
   - Use async/await for I/O operations
   - Implement pagination for large datasets
   - Cache frequently accessed data
   - Optimize image sizes

3. **User Experience**
   - Provide clear error messages
   - Show progress indicators
   - Enable offline functionality
   - Minimize authentication friction

4. **Code Quality**
   - Follow SOLID principles
   - Write unit tests
   - Document public APIs
   - Use meaningful variable names

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Google ML Kit](https://developers.google.com/ml-kit)
- [SQLCipher](https://www.zetetic.net/sqlcipher/)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)

## Support & Contributing

For questions or contributions, please refer to the main README.md file.
