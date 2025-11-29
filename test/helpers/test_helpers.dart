import 'dart:typed_data';
import 'package:doc_scanner/core/domain/entities/document.dart';
import 'package:doc_scanner/core/domain/entities/audit_event.dart';
import 'package:doc_scanner/core/domain/entities/backup_metadata.dart';

/// Helper class for creating test data
class TestHelpers {
  /// Creates a test document with customizable properties
  static Document createTestDocument({
    String? id,
    String? title,
    String? description,
    String documentType = 'Invoice',
    DateTime? captureDate,
    DateTime? createdAt,
    String? encryptedImagePath,
    String? encryptedThumbnailPath,
    String? ocrText,
    String? checksum,
    int fileSizeBytes = 1024,
    List<String> tags = const [],
    Map<String, dynamic>? metadata,
    bool isDeleted = false,
    double? ocrConfidence,
  }) {
    final docId = id ?? 'test-doc-${DateTime.now().millisecondsSinceEpoch}';
    return Document(
      id: docId,
      title: title ?? 'Test Document',
      description: description,
      documentType: documentType,
      captureDate: captureDate ?? DateTime.now(),
      createdAt: createdAt ?? DateTime.now(),
      encryptedImagePath: encryptedImagePath ?? '/test/path/image_$docId.enc',
      encryptedThumbnailPath:
          encryptedThumbnailPath ?? '/test/path/thumb_$docId.enc',
      ocrText: ocrText ?? 'Test OCR text for document',
      checksum: checksum ?? 'checksum_$docId',
      fileSizeBytes: fileSizeBytes,
      tags: tags,
      metadata: metadata,
      isDeleted: isDeleted,
      ocrConfidence: ocrConfidence,
    );
  }

  /// Creates a test audit event
  static AuditEvent createTestAuditEvent({
    String? id,
    AuditEventType? eventType,
    DateTime? timestamp,
    String? userId,
    String? deviceId,
    String? documentId,
    Map<String, dynamic>? payload,
    String? errorMessage,
  }) {
    return AuditEvent(
      id: id ?? 'test-event-${DateTime.now().millisecondsSinceEpoch}',
      eventType: eventType ?? AuditEventType.documentCreated,
      timestamp: timestamp ?? DateTime.now(),
      userId: userId,
      deviceId: deviceId,
      documentId: documentId,
      payload: payload,
      errorMessage: errorMessage,
    );
  }

  /// Creates a test backup metadata
  static BackupMetadata createTestBackupMetadata({
    String? id,
    CloudProvider provider = CloudProvider.local,
    DateTime? timestamp,
    String? checksum,
    int sizeBytes = 1024000,
    String? remotePath,
    String? localPath,
    bool isEncrypted = true,
    int documentCount = 10,
    String? version,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return BackupMetadata(
      id: id ?? 'test-backup-${DateTime.now().millisecondsSinceEpoch}',
      provider: provider,
      timestamp: timestamp ?? DateTime.now(),
      checksum: checksum ?? 'test_checksum',
      sizeBytes: sizeBytes,
      remotePath: remotePath,
      localPath: localPath,
      isEncrypted: isEncrypted,
      documentCount: documentCount,
      version: version,
      additionalMetadata: additionalMetadata,
    );
  }

  /// Creates test image data
  static Uint8List createTestImageBytes({int size = 1024}) {
    final bytes = Uint8List(size);
    for (int i = 0; i < size; i++) {
      bytes[i] = i % 256;
    }
    return bytes;
  }

  /// Creates a sample invoice OCR text
  static String createInvoiceOCRText() {
    return '''
INVOICE
Invoice #: INV-2024-001
Date: 2024-01-15

Bill To:
John Doe
123 Main Street
City, State 12345

Items:
1. Service A    \$100.00
2. Service B    \$200.00

Subtotal:       \$300.00
Tax (10%):      \$30.00
Total:          \$330.00

Payment Due: 2024-02-15
''';
  }

  /// Creates a sample receipt OCR text
  static String createReceiptOCRText() {
    return '''
RECEIPT
Store: Test Store
Date: 2024-01-15 14:30

Items:
Coffee          \$3.50
Sandwich        \$6.00

Subtotal:       \$9.50
Tax:            \$0.95
Total:          \$10.45

Payment: Credit Card
Transaction ID: TXN123456
''';
  }

  /// Creates a sample contract OCR text
  static String createContractOCRText() {
    return '''
CONTRACT AGREEMENT

This agreement is made on 2024-01-15 between:
Party A: Company Inc.
Party B: Client LLC

Terms and Conditions:
1. Services to be provided
2. Payment terms
3. Confidentiality clause

This contract is valid for 12 months.

Signatures:
_________________  _________________
Party A            Party B
''';
  }

  /// Waits for async operations with timeout
  static Future<void> waitForAsync({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Creates a temporary test directory path
  static String createTempPath(String filename) {
    return '/tmp/test_${DateTime.now().millisecondsSinceEpoch}_$filename';
  }
}
