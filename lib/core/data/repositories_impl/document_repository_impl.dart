import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../../domain/entities/document.dart';
import '../../services/database_service.dart';
import '../../services/encryption_service.dart';
import '../../services/audit_service.dart';
import '../../services/ocr_service.dart';
import '../../services/image_processing_service.dart';

/// Repository implementation for document operations
///
/// Handles the complete document lifecycle:
/// - Image capture and processing
/// - OCR text extraction
/// - Encryption
/// - Database storage
/// - Full-text search indexing
/// - Audit logging
class DocumentRepositoryImpl {
  final DatabaseService _databaseService;
  final EncryptionService _encryptionService;
  final AuditService _auditService;
  final OCRService _ocrService;
  final ImageProcessingService _imageProcessingService;
  final String _documentsStoragePath;
  final Uint8List _dek; // Data Encryption Key

  static const _uuid = Uuid();

  DocumentRepositoryImpl({
    required DatabaseService databaseService,
    required EncryptionService encryptionService,
    required AuditService auditService,
    required OCRService ocrService,
    required ImageProcessingService imageProcessingService,
    required String documentsStoragePath,
    required Uint8List dataEncryptionKey,
  })  : _databaseService = databaseService,
        _encryptionService = encryptionService,
        _auditService = auditService,
        _ocrService = ocrService,
        _imageProcessingService = imageProcessingService,
        _documentsStoragePath = documentsStoragePath,
        _dek = dataEncryptionKey;

  /// Create a new document from a captured image
  ///
  /// Steps:
  /// 1. Process image (enhance, compress)
  /// 2. Generate thumbnail
  /// 3. Perform OCR
  /// 4. Encrypt image and thumbnail
  /// 5. Compute checksum
  /// 6. Store in database with FTS5 indexing
  /// 7. Log audit event
  Future<Document> createDocument({
    required String imagePath,
    required String title,
    String? description,
    required String documentType,
    List<String> tags = const [],
    Map<String, dynamic>? metadata,
  }) async {
    final documentId = _uuid.v4();
    final captureDate = DateTime.now();

    try {
      // 1. Process image
      final processedImage = await _imageProcessingService.processDocumentImage(
        imagePath: imagePath,
        quality: 85,
      );

      // 2. Generate thumbnail
      final thumbnail = await _imageProcessingService.generateThumbnail(
        imagePath: imagePath,
        maxWidth: 300,
        maxHeight: 300,
      );

      // 3. Perform OCR
      final ocrResult = await _ocrService.recognizeText(imagePath);
      final ocrText = _ocrService.extractPlainText(ocrResult);

      // 4. Compute checksum of original image
      final originalImageBytes = await File(imagePath).readAsBytes();
      final checksum = _encryptionService.computeChecksum(
        Uint8List.fromList(originalImageBytes),
      );

      // 5. Encrypt image and thumbnail
      final encryptedImage = _encryptionService.encryptBytes(
        plaintext: processedImage.imageBytes,
        key: _dek,
      );

      final encryptedThumbnail = _encryptionService.encryptBytes(
        plaintext: thumbnail.imageBytes,
        key: _dek,
      );

      // 6. Save encrypted files
      final imageFileName = '${documentId}_image.enc';
      final thumbnailFileName = '${documentId}_thumb.enc';

      final imagePath = path.join(_documentsStoragePath, imageFileName);
      final thumbnailPath = path.join(_documentsStoragePath, thumbnailFileName);

      await File(imagePath).writeAsBytes(encryptedImage);
      await File(thumbnailPath).writeAsBytes(encryptedThumbnail);

      // 7. Create document entity
      final document = Document(
        id: documentId,
        title: title,
        description: description,
        documentType: documentType,
        captureDate: captureDate,
        createdAt: DateTime.now(),
        encryptedImagePath: imagePath,
        encryptedThumbnailPath: thumbnailPath,
        ocrText: ocrText,
        checksum: checksum,
        fileSizeBytes: processedImage.sizeBytes,
        tags: tags,
        metadata: metadata,
        ocrConfidence: ocrResult.confidence,
      );

      // 8. Store in database (includes FTS5 indexing via triggers)
      await _databaseService.insertDocument(document);

      // 9. Log audit event
      await _auditService.logDocumentCreated(
        documentId: documentId,
        additionalData: {
          'title': title,
          'documentType': documentType,
          'ocrLength': ocrText.length,
        },
      );

      return document;
    } catch (e) {
      throw Exception('Failed to create document: $e');
    }
  }

  /// Get a document by ID with decryption
  Future<Document?> getDocument(String documentId) async {
    final document = await _databaseService.getDocument(documentId);

    if (document != null) {
      // Log view event
      await _auditService.logDocumentViewed(documentId: documentId);
    }

    return document;
  }

  /// Get decrypted document image
  Future<Uint8List> getDocumentImage(String documentId) async {
    final document = await _databaseService.getDocument(documentId);
    if (document == null) {
      throw Exception('Document not found');
    }

    try {
      final encryptedBytes = await File(document.encryptedImagePath).readAsBytes();
      return _encryptionService.decryptBytes(
        ciphertext: encryptedBytes,
        key: _dek,
      );
    } catch (e) {
      await _auditService.logDecryptionError(
        documentId: documentId,
        errorMessage: e.toString(),
      );
      throw Exception('Failed to decrypt document image: $e');
    }
  }

  /// Get decrypted thumbnail image
  Future<Uint8List> getDocumentThumbnail(String documentId) async {
    final document = await _databaseService.getDocument(documentId);
    if (document == null) {
      throw Exception('Document not found');
    }

    try {
      final encryptedBytes =
          await File(document.encryptedThumbnailPath).readAsBytes();
      return _encryptionService.decryptBytes(
        ciphertext: encryptedBytes,
        key: _dek,
      );
    } catch (e) {
      throw Exception('Failed to decrypt thumbnail: $e');
    }
  }

  /// List documents with pagination
  Future<List<Document>> listDocuments({
    int limit = 50,
    int offset = 0,
    String? documentType,
  }) async {
    return _databaseService.getDocuments(
      limit: limit,
      offset: offset,
      documentType: documentType,
    );
  }

  /// Search documents using full-text search
  Future<List<Document>> searchDocuments({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    // Log search query
    final results = await _databaseService.searchDocuments(
      query: query,
      limit: limit,
      offset: offset,
    );

    await _auditService.logSearchPerformed(
      query: query,
      resultCount: results.length,
    );

    return results;
  }

  /// Update document metadata
  Future<void> updateDocument({
    required String documentId,
    String? title,
    String? description,
    String? documentType,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    final document = await _databaseService.getDocument(documentId);
    if (document == null) {
      throw Exception('Document not found');
    }

    final updatedDocument = document.copyWith(
      title: title,
      description: description,
      documentType: documentType,
      tags: tags,
      metadata: metadata,
      updatedAt: DateTime.now(),
    );

    await _databaseService.updateDocument(updatedDocument);

    await _auditService.logDocumentUpdated(
      documentId: documentId,
      changes: {
        'title': title,
        'description': description,
        'documentType': documentType,
        'tags': tags,
      },
    );
  }

  /// Delete a document (soft delete)
  Future<void> deleteDocument(String documentId) async {
    await _databaseService.deleteDocument(documentId);

    await _auditService.logDocumentDeleted(documentId: documentId);
  }

  /// Permanently delete a document and its files
  Future<void> permanentlyDeleteDocument(String documentId) async {
    final document = await _databaseService.getDocument(documentId);
    if (document == null) {
      return;
    }

    // Delete encrypted files
    try {
      await File(document.encryptedImagePath).delete();
      await File(document.encryptedThumbnailPath).delete();
    } catch (e) {
      // Files may already be deleted
    }

    // Note: In production, implement hard delete from database
    await _databaseService.deleteDocument(documentId);

    await _auditService.logDocumentDeleted(
      documentId: documentId,
      additionalData: {'permanent': true},
    );
  }

  /// Get document count
  Future<int> getDocumentCount() async {
    return _databaseService.getDocumentCount();
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStatistics() async {
    final documents = await _databaseService.getDocuments(limit: 10000);

    int totalSize = 0;
    final typeCounts = <String, int>{};

    for (final doc in documents) {
      totalSize += doc.fileSizeBytes;
      typeCounts[doc.documentType] =
          (typeCounts[doc.documentType] ?? 0) + 1;
    }

    return {
      'totalDocuments': documents.length,
      'totalSizeBytes': totalSize,
      'typeCounts': typeCounts,
    };
  }
}
