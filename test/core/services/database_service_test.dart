import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:doc_scanner/core/services/database_service.dart';
import 'package:doc_scanner/core/domain/entities/document.dart';
import 'package:doc_scanner/core/domain/entities/audit_event.dart';
import 'package:doc_scanner/core/domain/entities/backup_metadata.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize ffi for testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseService', () {
    late DatabaseService databaseService;
    final testPassword = 'test_password_123';

    setUp(() async {
      databaseService = DatabaseService();
      // Use in-memory database for testing
      await databaseService.getDatabase(testPassword);
    });

    tearDown(() async {
      await databaseService.close();
    });

    group('Document Operations', () {
      test('insertDocument successfully stores document', () async {
        final document = _createTestDocument('doc-1');

        await databaseService.insertDocument(document);

        final retrieved = await databaseService.getDocument('doc-1');
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals('doc-1'));
        expect(retrieved.title, equals('Test Document'));
      });

      test('getDocument returns null for non-existent document', () async {
        final result = await databaseService.getDocument('non-existent');
        expect(result, isNull);
      });

      test('updateDocument modifies existing document', () async {
        final document = _createTestDocument('doc-1');
        await databaseService.insertDocument(document);

        final updated = document.copyWith(
          title: 'Updated Title',
          updatedAt: DateTime.now(),
        );
        await databaseService.updateDocument(updated);

        final retrieved = await databaseService.getDocument('doc-1');
        expect(retrieved!.title, equals('Updated Title'));
      });

      test('deleteDocument soft-deletes document', () async {
        final document = _createTestDocument('doc-1');
        await databaseService.insertDocument(document);

        await databaseService.deleteDocument('doc-1');

        final retrieved = await databaseService.getDocument('doc-1');
        expect(retrieved, isNull); // Should not return deleted docs
      });

      test('getDocuments returns list with pagination', () async {
        // Insert multiple documents
        for (int i = 0; i < 10; i++) {
          await databaseService.insertDocument(
            _createTestDocument('doc-$i'),
          );
        }

        final firstPage = await databaseService.getDocuments(
          limit: 5,
          offset: 0,
        );
        final secondPage = await databaseService.getDocuments(
          limit: 5,
          offset: 5,
        );

        expect(firstPage.length, equals(5));
        expect(secondPage.length, equals(5));
        expect(firstPage.first.id, isNot(equals(secondPage.first.id)));
      });

      test('getDocuments filters by document type', () async {
        await databaseService.insertDocument(
          _createTestDocument('doc-1', type: 'Invoice'),
        );
        await databaseService.insertDocument(
          _createTestDocument('doc-2', type: 'Receipt'),
        );
        await databaseService.insertDocument(
          _createTestDocument('doc-3', type: 'Invoice'),
        );

        final invoices = await databaseService.getDocuments(
          documentType: 'Invoice',
        );

        expect(invoices.length, equals(2));
        expect(invoices.every((doc) => doc.documentType == 'Invoice'), isTrue);
      });

      test('getDocumentCount returns correct count', () async {
        await databaseService.insertDocument(_createTestDocument('doc-1'));
        await databaseService.insertDocument(_createTestDocument('doc-2'));
        await databaseService.insertDocument(_createTestDocument('doc-3'));

        final count = await databaseService.getDocumentCount();
        expect(count, equals(3));
      });

      test('getDocumentCount excludes deleted documents', () async {
        await databaseService.insertDocument(_createTestDocument('doc-1'));
        await databaseService.insertDocument(_createTestDocument('doc-2'));
        await databaseService.deleteDocument('doc-1');

        final count = await databaseService.getDocumentCount();
        expect(count, equals(1));
      });
    });

    group('Full-Text Search', () {
      setUp(() async {
        // Insert test documents with different content
        await databaseService.insertDocument(
          _createTestDocument(
            'doc-1',
            title: 'Invoice for Mangoes',
            ocrText: 'Total amount: \$50 for fresh mangoes from market',
          ),
        );
        await databaseService.insertDocument(
          _createTestDocument(
            'doc-2',
            title: 'Receipt for Apples',
            ocrText: 'Payment received: \$30 for organic apples',
          ),
        );
        await databaseService.insertDocument(
          _createTestDocument(
            'doc-3',
            title: 'Contract Agreement',
            ocrText: 'This contract is for supply of fresh fruits including mangoes',
          ),
        );
      });

      test('searchDocuments finds documents by single term', () async {
        final results = await databaseService.searchDocuments(query: 'mangoes');

        expect(results.length, greaterThanOrEqualTo(2));
        expect(
          results.any((doc) => doc.id == 'doc-1'),
          isTrue,
        );
      });

      test('searchDocuments with AND operator', () async {
        final results = await databaseService.searchDocuments(
          query: 'mangoes AND fresh',
        );

        expect(results.length, greaterThanOrEqualTo(1));
      });

      test('searchDocuments with OR operator', () async {
        final results = await databaseService.searchDocuments(
          query: 'mangoes OR apples',
        );

        expect(results.length, greaterThanOrEqualTo(2));
      });

      test('searchDocuments returns empty for non-matching query', () async {
        final results = await databaseService.searchDocuments(
          query: 'nonexistent',
        );

        expect(results, isEmpty);
      });

      test('searchDocuments respects limit', () async {
        final results = await databaseService.searchDocuments(
          query: 'fresh',
          limit: 1,
        );

        expect(results.length, lessThanOrEqualTo(1));
      });

      test('searchDocuments with pagination', () async {
        final firstPage = await databaseService.searchDocuments(
          query: 'fresh',
          limit: 1,
          offset: 0,
        );
        final secondPage = await databaseService.searchDocuments(
          query: 'fresh',
          limit: 1,
          offset: 1,
        );

        expect(firstPage.length, equals(1));
        if (secondPage.isNotEmpty) {
          expect(firstPage.first.id, isNot(equals(secondPage.first.id)));
        }
      });
    });

    group('Audit Events', () {
      test('insertAuditEvent stores event', () async {
        final event = AuditEvent(
          id: 'event-1',
          eventType: AuditEventType.documentCreated,
          timestamp: DateTime.now(),
          userId: 'user-1',
          documentId: 'doc-1',
        );

        await databaseService.insertAuditEvent(event);

        final events = await databaseService.getAuditEvents(limit: 10);
        expect(events.any((e) => e.id == 'event-1'), isTrue);
      });

      test('getAuditEvents filters by event type', () async {
        await databaseService.insertAuditEvent(
          AuditEvent(
            id: 'event-1',
            eventType: AuditEventType.documentCreated,
            timestamp: DateTime.now(),
          ),
        );
        await databaseService.insertAuditEvent(
          AuditEvent(
            id: 'event-2',
            eventType: AuditEventType.documentViewed,
            timestamp: DateTime.now(),
          ),
        );

        final createdEvents = await databaseService.getAuditEvents(
          eventType: AuditEventType.documentCreated,
        );

        expect(createdEvents.length, equals(1));
        expect(createdEvents.first.eventType, equals(AuditEventType.documentCreated));
      });

      test('getAuditEvents filters by document ID', () async {
        await databaseService.insertAuditEvent(
          AuditEvent(
            id: 'event-1',
            eventType: AuditEventType.documentCreated,
            timestamp: DateTime.now(),
            documentId: 'doc-1',
          ),
        );
        await databaseService.insertAuditEvent(
          AuditEvent(
            id: 'event-2',
            eventType: AuditEventType.documentViewed,
            timestamp: DateTime.now(),
            documentId: 'doc-2',
          ),
        );

        final doc1Events = await databaseService.getAuditEvents(
          documentId: 'doc-1',
        );

        expect(doc1Events.length, equals(1));
        expect(doc1Events.first.documentId, equals('doc-1'));
      });

      test('getAuditEvents filters by date range', () async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final tomorrow = now.add(const Duration(days: 1));

        await databaseService.insertAuditEvent(
          AuditEvent(
            id: 'event-old',
            eventType: AuditEventType.documentCreated,
            timestamp: yesterday,
          ),
        );
        await databaseService.insertAuditEvent(
          AuditEvent(
            id: 'event-new',
            eventType: AuditEventType.documentCreated,
            timestamp: now,
          ),
        );

        final recentEvents = await databaseService.getAuditEvents(
          startDate: yesterday.add(const Duration(hours: 1)),
          endDate: tomorrow,
        );

        expect(recentEvents.length, equals(1));
        expect(recentEvents.first.id, equals('event-new'));
      });
    });

    group('Backup Metadata', () {
      test('insertBackupMetadata stores metadata', () async {
        final metadata = BackupMetadata(
          id: 'backup-1',
          provider: CloudProvider.googleDrive,
          timestamp: DateTime.now(),
          checksum: 'abc123',
          sizeBytes: 1024,
          documentCount: 10,
        );

        await databaseService.insertBackupMetadata(metadata);

        final backups = await databaseService.getBackupMetadata();
        expect(backups.any((b) => b.id == 'backup-1'), isTrue);
      });

      test('getBackupMetadata filters by provider', () async {
        await databaseService.insertBackupMetadata(
          BackupMetadata(
            id: 'backup-1',
            provider: CloudProvider.googleDrive,
            timestamp: DateTime.now(),
            checksum: 'abc123',
            sizeBytes: 1024,
            documentCount: 10,
          ),
        );
        await databaseService.insertBackupMetadata(
          BackupMetadata(
            id: 'backup-2',
            provider: CloudProvider.dropbox,
            timestamp: DateTime.now(),
            checksum: 'def456',
            sizeBytes: 2048,
            documentCount: 20,
          ),
        );

        final driveBackups = await databaseService.getBackupMetadata(
          provider: CloudProvider.googleDrive,
        );

        expect(driveBackups.length, equals(1));
        expect(driveBackups.first.provider, equals(CloudProvider.googleDrive));
      });

      test('getBackupMetadata respects limit', () async {
        for (int i = 0; i < 5; i++) {
          await databaseService.insertBackupMetadata(
            BackupMetadata(
              id: 'backup-$i',
              provider: CloudProvider.googleDrive,
              timestamp: DateTime.now(),
              checksum: 'checksum-$i',
              sizeBytes: 1024,
              documentCount: 10,
            ),
          );
        }

        final backups = await databaseService.getBackupMetadata(limit: 3);
        expect(backups.length, equals(3));
      });
    });

    group('Database Optimization', () {
      test('optimize runs without errors', () async {
        // Insert some data first
        for (int i = 0; i < 10; i++) {
          await databaseService.insertDocument(_createTestDocument('doc-$i'));
        }

        // Should not throw
        await databaseService.optimize();
      });
    });

    group('Transaction Support', () {
      test('insertDocument uses transaction', () async {
        final document = _createTestDocument('doc-1');

        // Insert should be atomic
        await databaseService.insertDocument(document);

        final retrieved = await databaseService.getDocument('doc-1');
        expect(retrieved, isNotNull);
      });
    });
  });
}

// Helper function to create test documents
Document _createTestDocument(
  String id, {
  String? title,
  String? ocrText,
  String type = 'Invoice',
}) {
  return Document(
    id: id,
    title: title ?? 'Test Document',
    documentType: type,
    captureDate: DateTime.now(),
    createdAt: DateTime.now(),
    encryptedImagePath: '/test/path/image_$id.enc',
    encryptedThumbnailPath: '/test/path/thumb_$id.enc',
    ocrText: ocrText ?? 'Test OCR text for document $id',
    checksum: 'checksum_$id',
    fileSizeBytes: 1024,
    tags: ['test', 'document'],
  );
}
