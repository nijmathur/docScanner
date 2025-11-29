# Secure Document Scanner

A privacy-first, completely offline document scanner and OCR application built with Flutter. All document processing, OCR, encryption, and storage happens entirely on your device with optional encrypted cloud backup.

## Features

### Core Functionality
- **Document Capture & Processing**
  - Camera integration for document scanning
  - Edge detection and automatic cropping
  - Perspective correction (deskew)
  - Image enhancement (contrast, grayscale, noise reduction)
  - Thumbnail generation

- **On-Device OCR**
  - Google ML Kit Text Recognition
  - Multi-language support
  - Text block and line-level recognition
  - Pattern extraction (dates, amounts, emails, phone numbers)
  - Auto document type detection

- **Security & Encryption**
  - AES-256-GCM encryption for all documents
  - SQLCipher encrypted database
  - PBKDF2 key derivation (100,000 iterations)
  - PIN and biometric authentication
  - Secure key storage in OS keychain
  - SHA-256 integrity checksums

- **Search & Organization**
  - Full-text search using SQLite FTS5
  - Boolean operators (AND, OR, NOT)
  - Phrase matching and wildcards
  - Tag-based organization
  - Document type filtering
  - Date range queries

- **Audit Logging**
  - Immutable, append-only audit trail
  - Tracks all sensitive operations
  - Document lifecycle tracking
  - Authentication attempts
  - Search queries
  - Backup/restore events

- **Encrypted Cloud Backup**
  - Password-protected backups (separate from app PIN)
  - Multi-cloud support (Google Drive, OneDrive, Dropbox)
  - End-to-end encryption
  - Integrity verification
  - Backup metadata tracking

## Architecture

### Clean Architecture (TOGAF-Compliant)
```
lib/
├── core/
│   ├── domain/
│   │   └── entities/          # Domain models
│   ├── data/
│   │   ├── datasources/       # Data sources
│   │   ├── models/            # Data models
│   │   └── repositories_impl/ # Repository implementations
│   ├── services/              # Core services
│   │   ├── auth_service.dart
│   │   ├── database_service.dart
│   │   ├── encryption_service.dart
│   │   ├── ocr_service.dart
│   │   ├── image_processing_service.dart
│   │   ├── audit_service.dart
│   │   ├── backup_service.dart
│   │   └── cloud_storage_gateway.dart
│   ├── constants/
│   ├── errors/
│   └── utils/
├── features/
│   ├── auth/
│   │   └── screens/
│   ├── camera/
│   │   └── screens/
│   ├── documents/
│   │   └── screens/
│   ├── search/
│   │   └── screens/
│   ├── settings/
│   │   └── screens/
│   └── backup/
│       └── screens/
└── shared/
```

### SOLID Principles Applied
- **Single Responsibility**: Each service has one clear purpose
- **Open/Closed**: Extensible cloud storage gateways
- **Liskov Substitution**: CloudStorageGateway interface
- **Interface Segregation**: Focused, minimal interfaces
- **Dependency Inversion**: Services depend on abstractions

## Security Specifications

### Encryption
- **Algorithm**: AES-256-GCM (authenticated encryption)
- **Key Derivation**: PBKDF2-HMAC-SHA256 with 100,000 iterations
- **Master Key Storage**: OS-level secure storage (Keychain/Keystore)
- **Database**: SQLCipher with AES-256 encryption
- **Backup Encryption**: Separate password-derived key (BEK)

### Authentication
- **Methods**: 6-digit PIN and/or biometric (Face ID, Touch ID, Fingerprint)
- **Failed Attempts**: Max 5 failures before lockout
- **Session Timeout**: Configurable (default 15 minutes)
- **Re-authentication**: Required after timeout or app restart

### Data Privacy
- **Offline-First**: All processing happens on-device
- **No Telemetry**: No usage data collection
- **Cloud Backup**: Optional and fully encrypted
- **Zero-Knowledge**: Cloud providers cannot access document contents

## Performance

### Targets (Mid-Range Device)
- Document capture to OCR: ≤10 seconds/page
- Full-text search (100k docs): ≤500 ms
- App startup: ≤3 seconds
- Thumbnail generation: ≤2 seconds
- Backup upload: ≥10 MB/min

### Optimizations
- SQLite WAL mode for concurrency
- FTS5 indexes for fast search
- Lazy loading and pagination
- Image compression and optimization
- Asynchronous OCR processing

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Dart 3.0+
- iOS 14+ or Android 10+
- Xcode 14+ (for iOS development)
- Android Studio or VS Code

### Installation

1. Clone the repository:
```bash
cd docScanner
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure iOS (if developing for iOS):
```bash
cd ios
pod install
cd ..
```

4. Run the app:
```bash
flutter run
```

### Platform-Specific Setup

#### iOS
Add the following to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required to import documents</string>
<key>NSFaceIDUsageDescription</key>
<string>Face ID is required for secure authentication</string>
```

#### Android
Add the following to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<uses-permission android:name="android.permission.USE_FINGERPRINT" />
```

### Google Drive Integration Setup

1. Create a Google Cloud project
2. Enable Google Drive API
3. Configure OAuth consent screen
4. Create OAuth 2.0 credentials
5. Add the OAuth client ID to your app configuration

## Usage

### First Launch
1. Open the app
2. Set up a 6-digit PIN
3. Optionally enable biometric authentication

### Scanning Documents
1. Tap the camera button
2. Position document in frame
3. Capture image
4. Review and adjust crop/deskew
5. Add metadata (title, type, tags)
6. Save (automatic OCR processing)

### Searching Documents
1. Tap search icon
2. Enter search query
3. Use filters (date, type, tags)
4. Tap result to view document

### Creating Backups
1. Go to Settings → Backup
2. Select cloud provider
3. Authenticate with provider
4. Enter backup password
5. Confirm backup creation

### Restoring Backups
1. Go to Settings → Restore
2. Select provider and backup
3. Enter backup password
4. Confirm restore (warning: destructive)
5. App will restart after restore

## Documentation

Comprehensive documentation is available in the `docs/` directory:

### Technical Documentation
- 📖 **[Implementation Guide](IMPLEMENTATION_GUIDE.md)** - Detailed architecture, implementation patterns, and extension guides
- 🔒 **[Security Architecture](SECURITY.md)** - Complete security specifications, threat model, and best practices
- 🐛 **[Debugging Guide](docs/DEBUGGING.md)** - Troubleshooting, common issues, and debugging techniques
- 🚀 **[Deployment Guide](docs/DEPLOYMENT.md)** - iOS/Android deployment, CI/CD, and app store submission
- 🧪 **[Testing Guide](docs/TESTING.md)** - Unit tests, integration tests, security tests, and test coverage

### Quick Links
- **Architecture**: See [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for clean architecture details
- **Security**: See [SECURITY.md](SECURITY.md) for encryption, authentication, and compliance
- **Debugging**: See [docs/DEBUGGING.md](docs/DEBUGGING.md) for troubleshooting
- **Deployment**: See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for app store deployment
- **Testing**: See [docs/TESTING.md](docs/TESTING.md) for test strategy and examples

## Development

### Running Tests
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/core/services/encryption_service_test.dart
```

See [Testing Guide](docs/TESTING.md) for comprehensive testing documentation.

### Code Generation (if using freezed/json_serializable)
```bash
flutter pub run build_runner build
```

### Linting
```bash
flutter analyze
```

### Debugging
```bash
# Run in debug mode
flutter run --debug

# Enable verbose logging
flutter run --verbose

# Launch DevTools
flutter pub global run devtools
```

See [Debugging Guide](docs/DEBUGGING.md) for detailed debugging instructions.

## Dependencies

### Core
- `flutter` - UI framework
- `provider` - State management
- `sqflite_sqlcipher` - Encrypted database
- `encrypt` - AES encryption
- `crypto` - Cryptographic functions

### Authentication & Security
- `local_auth` - Biometric authentication
- `flutter_secure_storage` - Secure key storage
- `pointycastle` - PBKDF2 implementation

### Camera & Image Processing
- `camera` - Camera access
- `image` - Image manipulation
- `edge_detection` - Document edge detection

### OCR
- `google_mlkit_text_recognition` - On-device OCR

### Cloud Integration
- `googleapis` - Google Drive API
- `google_sign_in` - Google authentication

### Utilities
- `path_provider` - File system paths
- `archive` - Tar/gzip compression
- `uuid` - UUID generation
- `intl` - Internationalization

## Limitations & Known Issues

1. **Database Password**: Currently requires initialization before use
2. **Camera Feature**: UI implementation in progress
3. **OneDrive/Dropbox**: Gateway interfaces defined, implementations pending
4. **Settings Screen**: Full settings UI in progress
5. **Document Viewer**: Decryption and display pending
6. **Export Formats**: PDF export not yet implemented

## Roadmap

- [ ] Complete camera integration with edge detection
- [ ] Implement document viewer with decryption
- [ ] Add search screen with advanced filters
- [ ] Complete settings screen
- [ ] Implement OneDrive and Dropbox gateways
- [ ] Add PDF export functionality
- [ ] Implement batch document operations
- [ ] Add document sharing (encrypted links)
- [ ] Multi-language UI support
- [ ] Dark mode theme

## License

This project is provided as-is for educational and evaluation purposes.

## Security Disclosure

If you discover a security vulnerability, please email: [your-email]

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Follow SOLID principles and clean architecture
4. Add tests for new functionality
5. Submit a pull request

## Acknowledgments

- Google ML Kit for on-device OCR
- SQLCipher for encrypted database
- Flutter and Dart teams
- Open source community

## Support

For issues and questions:
- GitHub Issues: [repository URL]
- Documentation: [docs URL]

---

**Built with Flutter** | **Privacy First** | **Offline Capable** | **End-to-End Encrypted**
