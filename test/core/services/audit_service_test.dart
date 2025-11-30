import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:doc_scanner/core/services/audit_service.dart';
import 'package:doc_scanner/core/services/database_service.dart';
import 'package:doc_scanner/core/domain/entities/audit_event.dart';

@GenerateMocks([DatabaseService])
import 'audit_service_test.mocks.dart';

void main() {
  group('AuditService', () {
    late AuditService auditService;
    late MockDatabaseService mockDatabaseService;

    setUp(() {
      mockDatabaseService = MockDatabaseService();
      auditService = AuditService(
        databaseService: mockDatabaseService,
        userId: 'test-user',
        deviceId: 'test-device',
      );
    });

    group('Document Logging', () {
      test('logDocumentCreated creates audit event', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logDocumentCreated(
          documentId: 'doc-1',
          additionalData: {'title': 'Test Doc'},
        );

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        expect(captured.length, equals(1));
        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.documentCreated));
        expect(event.documentId, equals('doc-1'));
        expect(event.userId, equals('test-user'));
        expect(event.deviceId, equals('test-device'));
        expect(event.payload!['title'], equals('Test Doc'));
      });

      test('logDocumentViewed creates audit event', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logDocumentViewed(documentId: 'doc-1');

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.documentViewed));
        expect(event.documentId, equals('doc-1'));
      });

      test('logDocumentUpdated creates audit event with changes', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logDocumentUpdated(
          documentId: 'doc-1',
          changes: {'title': 'New Title'},
        );

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.documentUpdated));
        expect(event.documentId, equals('doc-1'));
        expect(event.payload!['title'], equals('New Title'));
      });

      test('logDocumentDeleted creates audit event', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logDocumentDeleted(documentId: 'doc-1');

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.documentDeleted));
        expect(event.documentId, equals('doc-1'));
      });
    });

    group('Search Logging', () {
      test('logSearchPerformed creates audit event with query details',
          () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logSearchPerformed(
          query: 'test query',
          resultCount: 5,
          filters: {'type': 'Invoice'},
        );

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.searchPerformed));
        expect(event.payload!['query'], equals('test query'));
        expect(event.payload!['resultCount'], equals(5));
        expect(event.payload!['filters'], isNotNull);
      });
    });

    group('Authentication Logging', () {
      test('logAuthenticationSuccess creates audit event', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logAuthenticationSuccess(method: 'PIN');

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.authenticationSuccess));
        expect(event.payload!['method'], equals('PIN'));
      });

      test('logAuthenticationFailure creates audit event with reason',
          () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logAuthenticationFailure(
          method: 'Biometric',
          reason: 'Fingerprint not recognized',
        );

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.authenticationFailure));
        expect(event.payload!['method'], equals('Biometric'));
        expect(event.payload!['reason'], equals('Fingerprint not recognized'));
      });
    });

    group('Backup Logging', () {
      test('logBackupExported creates audit event', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logBackupExported(
          provider: 'GoogleDrive',
          documentCount: 100,
          sizeBytes: 1024000,
        );

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.backupExported));
        expect(event.payload!['provider'], equals('GoogleDrive'));
        expect(event.payload!['documentCount'], equals(100));
        expect(event.payload!['sizeBytes'], equals(1024000));
      });

      test('logBackupRestored creates audit event', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logBackupRestored(
          provider: 'GoogleDrive',
          documentCount: 100,
        );

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.backupRestored));
        expect(event.payload!['provider'], equals('GoogleDrive'));
        expect(event.payload!['documentCount'], equals(100));
      });
    });

    group('Error Logging', () {
      test('logDecryptionError creates audit event with error message',
          () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logDecryptionError(
          documentId: 'doc-1',
          errorMessage: 'Invalid key',
        );

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.decryptionError));
        expect(event.documentId, equals('doc-1'));
        expect(event.errorMessage, equals('Invalid key'));
      });

      test('logKeyAccess creates audit event', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logKeyAccess(
          keyType: 'DEK',
          operation: 'derive',
        );

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.keyAccess));
        expect(event.payload!['keyType'], equals('DEK'));
        expect(event.payload!['operation'], equals('derive'));
      });
    });

    group('Settings Logging', () {
      test('logSettingsChanged creates audit event with changes', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logSettingsChanged(
          changes: {'theme': 'dark', 'timeout': 15},
        );

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.eventType, equals(AuditEventType.settingsChanged));
        expect(event.payload!['theme'], equals('dark'));
        expect(event.payload!['timeout'], equals(15));
      });
    });

    group('Audit Trail Queries', () {
      test('getDocumentAuditTrail retrieves events for document', () async {
        final mockEvents = [
          AuditEvent(
            id: 'event-1',
            eventType: AuditEventType.documentCreated,
            timestamp: DateTime.now(),
            documentId: 'doc-1',
          ),
          AuditEvent(
            id: 'event-2',
            eventType: AuditEventType.documentViewed,
            timestamp: DateTime.now(),
            documentId: 'doc-1',
          ),
        ];

        when(mockDatabaseService.getAuditEvents(documentId: 'doc-1'))
            .thenAnswer((_) async => mockEvents);

        final events = await auditService.getDocumentAuditTrail('doc-1');

        expect(events.length, equals(2));
        expect(events, equals(mockEvents));
      });

      test('getEventsByType retrieves filtered events', () async {
        final mockEvents = [
          AuditEvent(
            id: 'event-1',
            eventType: AuditEventType.documentCreated,
            timestamp: DateTime.now(),
          ),
        ];

        when(mockDatabaseService.getAuditEvents(
          eventType: AuditEventType.documentCreated,
        )).thenAnswer((_) async => mockEvents);

        final events = await auditService.getEventsByType(
          AuditEventType.documentCreated,
        );

        expect(events, equals(mockEvents));
      });

      test('getEventsByDateRange retrieves events in range', () async {
        final startDate = DateTime(2024, 1, 1);
        final endDate = DateTime(2024, 1, 31);
        final mockEvents = [
          AuditEvent(
            id: 'event-1',
            eventType: AuditEventType.documentCreated,
            timestamp: DateTime(2024, 1, 15),
          ),
        ];

        when(mockDatabaseService.getAuditEvents(
          startDate: startDate,
          endDate: endDate,
          limit: 100,
        )).thenAnswer((_) async => mockEvents);

        final events = await auditService.getEventsByDateRange(
          startDate: startDate,
          endDate: endDate,
        );

        expect(events, equals(mockEvents));
      });
    });

    group('Audit Summary', () {
      test('generateAuditSummary creates comprehensive summary', () async {
        final mockEvents = [
          AuditEvent(
            id: 'event-1',
            eventType: AuditEventType.documentCreated,
            timestamp: DateTime.now(),
            documentId: 'doc-1',
          ),
          AuditEvent(
            id: 'event-2',
            eventType: AuditEventType.documentViewed,
            timestamp: DateTime.now(),
            documentId: 'doc-1',
          ),
          AuditEvent(
            id: 'event-3',
            eventType: AuditEventType.authenticationSuccess,
            timestamp: DateTime.now(),
          ),
          AuditEvent(
            id: 'event-4',
            eventType: AuditEventType.authenticationFailure,
            timestamp: DateTime.now(),
          ),
        ];

        when(mockDatabaseService.getAuditEvents(
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
          limit: 10000,
        )).thenAnswer((_) async => mockEvents);

        final summary = await auditService.generateAuditSummary();

        expect(summary['totalEvents'], equals(4));
        expect(summary['eventCounts']['documentCreated'], equals(1));
        expect(summary['eventCounts']['documentViewed'], equals(1));
        expect(summary['documentActivity']['doc-1'], equals(2));
        expect(summary['authenticationAttempts']['success'], equals(1));
        expect(summary['authenticationAttempts']['failure'], equals(1));
      });
    });

    group('Error Handling', () {
      test('logging continues even if database insert fails', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenThrow(Exception('Database error'));

        // Should not throw
        await auditService.logDocumentCreated(documentId: 'doc-1');

        verify(mockDatabaseService.insertAuditEvent(any)).called(1);
      });
    });

    group('User and Device Tracking', () {
      test('audit events include user and device IDs', () async {
        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await auditService.logDocumentCreated(documentId: 'doc-1');

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.userId, equals('test-user'));
        expect(event.deviceId, equals('test-device'));
      });

      test('audit service works without user or device ID', () async {
        final serviceWithoutIds = AuditService(
          databaseService: mockDatabaseService,
        );

        when(mockDatabaseService.insertAuditEvent(any))
            .thenAnswer((_) async => {});

        await serviceWithoutIds.logDocumentCreated(documentId: 'doc-1');

        final captured = verify(
          mockDatabaseService.insertAuditEvent(captureAny),
        ).captured;

        final event = captured[0] as AuditEvent;
        expect(event.userId, isNull);
        expect(event.deviceId, isNull);
      });
    });
  });
}
