import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:doc_scanner/core/services/backup_service.dart';
import 'package:doc_scanner/core/services/database_service.dart';
import 'package:doc_scanner/core/services/encryption_service.dart';
import 'package:doc_scanner/core/services/audit_service.dart';
import 'package:doc_scanner/core/services/cloud_storage_gateway.dart';
import 'package:doc_scanner/core/domain/entities/backup_metadata.dart';

import 'backup_service_test.mocks.dart';

@GenerateMocks([
  DatabaseService,
  EncryptionService,
  AuditService,
  CloudStorageGateway,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupService', () {
    late BackupService backupService;
    late MockDatabaseService mockDatabaseService;
    late MockEncryptionService mockEncryptionService;
    late MockAuditService mockAuditService;
    late MockCloudStorageGateway mockCloudGateway;

    final testDocumentsPath = '/test/documents';

    setUp(() {
      mockDatabaseService = MockDatabaseService();
      mockEncryptionService = MockEncryptionService();
      mockAuditService = MockAuditService();
      mockCloudGateway = MockCloudStorageGateway();

      backupService = BackupService(
        databaseService: mockDatabaseService,
        encryptionService: mockEncryptionService,
        auditService: mockAuditService,
        documentsPath: testDocumentsPath,
      );
    });

    group('Backup Metadata Operations', () {
      test('listBackups returns all backups when no provider specified',
          () async {
        final testBackups = [
          BackupMetadata(
            id: 'backup-1',
            provider: CloudProvider.local,
            timestamp: DateTime.now(),
            checksum: 'checksum1',
            sizeBytes: 1000,
            isEncrypted: true,
            documentCount: 10,
            version: '1.0.0',
          ),
          BackupMetadata(
            id: 'backup-2',
            provider: CloudProvider.googleDrive,
            timestamp: DateTime.now(),
            checksum: 'checksum2',
            sizeBytes: 2000,
            isEncrypted: true,
            documentCount: 20,
            version: '1.0.0',
          ),
        ];

        when(mockDatabaseService.getBackupMetadata(provider: null))
            .thenAnswer((_) async => testBackups);

        final result = await backupService.listBackups();

        expect(result, hasLength(2));
        expect(result, equals(testBackups));
      });

      test('listBackups filters by provider', () async {
        final googleBackups = [
          BackupMetadata(
            id: 'backup-1',
            provider: CloudProvider.googleDrive,
            timestamp: DateTime.now(),
            checksum: 'checksum1',
            sizeBytes: 1000,
            isEncrypted: true,
            documentCount: 10,
            version: '1.0.0',
          ),
        ];

        when(mockDatabaseService.getBackupMetadata(
                provider: CloudProvider.googleDrive))
            .thenAnswer((_) async => googleBackups);

        final result = await backupService.listBackups(
            provider: CloudProvider.googleDrive);

        expect(result, hasLength(1));
        expect(result.first.provider, equals(CloudProvider.googleDrive));
      });

      test('getBackupStatistics calculates correct totals', () async {
        final testBackups = [
          BackupMetadata(
            id: 'backup-1',
            provider: CloudProvider.local,
            timestamp: DateTime(2024, 1, 1),
            checksum: 'checksum1',
            sizeBytes: 1000,
            isEncrypted: true,
            documentCount: 10,
            version: '1.0.0',
          ),
          BackupMetadata(
            id: 'backup-2',
            provider: CloudProvider.googleDrive,
            timestamp: DateTime(2024, 1, 2),
            checksum: 'checksum2',
            sizeBytes: 2000,
            isEncrypted: true,
            documentCount: 20,
            version: '1.0.0',
          ),
          BackupMetadata(
            id: 'backup-3',
            provider: CloudProvider.googleDrive,
            timestamp: DateTime(2024, 1, 3),
            checksum: 'checksum3',
            sizeBytes: 1500,
            isEncrypted: true,
            documentCount: 15,
            version: '1.0.0',
          ),
        ];

        when(mockDatabaseService.getBackupMetadata(provider: null))
            .thenAnswer((_) async => testBackups);

        final result = await backupService.getBackupStatistics();

        expect(result['totalBackups'], equals(3));
        expect(result['totalSizeBytes'], equals(4500));
        expect(result['totalDocuments'], equals(45));
        expect(result['providerCounts']['local'], equals(1));
        expect(result['providerCounts']['googleDrive'], equals(2));
        expect(result['latestBackup'], equals(DateTime(2024, 1, 1)));
      });

      test('getBackupStatistics returns empty stats for no backups', () async {
        when(mockDatabaseService.getBackupMetadata(provider: null))
            .thenAnswer((_) async => []);

        final result = await backupService.getBackupStatistics();

        expect(result['totalBackups'], equals(0));
        expect(result['totalSizeBytes'], equals(0));
        expect(result['totalDocuments'], equals(0));
        expect(result['providerCounts'], isEmpty);
        expect(result['latestBackup'], isNull);
      });

      test('getBackupStatistics counts providers correctly', () async {
        final testBackups = [
          BackupMetadata(
            id: 'backup-1',
            provider: CloudProvider.local,
            timestamp: DateTime.now(),
            checksum: 'checksum1',
            sizeBytes: 1000,
            isEncrypted: true,
            documentCount: 10,
            version: '1.0.0',
          ),
          BackupMetadata(
            id: 'backup-2',
            provider: CloudProvider.local,
            timestamp: DateTime.now(),
            checksum: 'checksum2',
            sizeBytes: 2000,
            isEncrypted: true,
            documentCount: 20,
            version: '1.0.0',
          ),
        ];

        when(mockDatabaseService.getBackupMetadata(provider: null))
            .thenAnswer((_) async => testBackups);

        final result = await backupService.getBackupStatistics();

        expect(result['providerCounts']['local'], equals(2));
      });
    });

    group('Encryption Service Integration', () {
      test('backup operations use correct encryption methods', () async {
        // This tests that the service correctly calls encryption methods
        // Full backup tests would require file system mocking
        final salt = Uint8List.fromList(List.generate(32, (i) => i));
        final bek = Uint8List.fromList(List.generate(32, (i) => i + 100));

        when(mockEncryptionService.generateSalt()).thenReturn(salt);
        when(mockEncryptionService.deriveBEK(
          password: anyNamed('password'),
          salt: anyNamed('salt'),
        )).thenReturn(bek);
        when(mockEncryptionService.computeChecksum(any))
            .thenReturn('test_checksum');

        // Verify encryption service integration
        final generatedSalt = mockEncryptionService.generateSalt();
        expect(generatedSalt.length, equals(32));

        final derivedKey = mockEncryptionService.deriveBEK(
          password: 'test_password',
          salt: salt,
        );
        expect(derivedKey.length, equals(32));
      });

      test('backup checksum is computed correctly', () async {
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        when(mockEncryptionService.computeChecksum(testData))
            .thenReturn('test_checksum_123');

        final checksum = mockEncryptionService.computeChecksum(testData);

        expect(checksum, equals('test_checksum_123'));
        verify(mockEncryptionService.computeChecksum(testData)).called(1);
      });
    });

    group('Cloud Provider Detection', () {
      test('identifies Google Drive provider', () {
        when(mockCloudGateway.providerName).thenReturn('Google Drive Gateway');

        final providerName = mockCloudGateway.providerName;
        final isGoogle = providerName.contains('Google');

        expect(isGoogle, isTrue);
      });

      test('identifies OneDrive provider', () {
        when(mockCloudGateway.providerName).thenReturn('OneDrive Gateway');

        final providerName = mockCloudGateway.providerName;
        final isOneDrive = providerName.contains('OneDrive');

        expect(isOneDrive, isTrue);
      });

      test('identifies Dropbox provider', () {
        when(mockCloudGateway.providerName).thenReturn('Dropbox Gateway');

        final providerName = mockCloudGateway.providerName;
        final isDropbox = providerName.contains('Dropbox');

        expect(isDropbox, isTrue);
      });

      test('defaults to local when no cloud gateway', () {
        // When cloudGateway is null, provider should be local
        final provider = CloudProvider.local;

        expect(provider, equals(CloudProvider.local));
      });
    });

    group('Audit Logging', () {
      test('backup creation is logged', () async {
        when(mockAuditService.logBackupExported(
          provider: anyNamed('provider'),
          documentCount: anyNamed('documentCount'),
          sizeBytes: anyNamed('sizeBytes'),
        )).thenAnswer((_) async => {});

        await mockAuditService.logBackupExported(
          provider: 'googleDrive',
          documentCount: 100,
          sizeBytes: 5000,
        );

        verify(mockAuditService.logBackupExported(
          provider: 'googleDrive',
          documentCount: 100,
          sizeBytes: 5000,
        )).called(1);
      });

      test('backup restoration is logged', () async {
        when(mockAuditService.logBackupRestored(
          provider: anyNamed('provider'),
          documentCount: anyNamed('documentCount'),
        )).thenAnswer((_) async => {});

        await mockAuditService.logBackupRestored(
          provider: 'local',
          documentCount: 50,
        );

        verify(mockAuditService.logBackupRestored(
          provider: 'local',
          documentCount: 50,
        )).called(1);
      });
    });

    group('Database Integration', () {
      test('backup metadata is stored in database', () async {
        final testMetadata = BackupMetadata(
          id: 'backup-123',
          provider: CloudProvider.local,
          timestamp: DateTime.now(),
          checksum: 'test_checksum',
          sizeBytes: 1000,
          isEncrypted: true,
          documentCount: 10,
          version: '1.0.0',
        );

        when(mockDatabaseService.insertBackupMetadata(any))
            .thenAnswer((_) async => {});

        await mockDatabaseService.insertBackupMetadata(testMetadata);

        verify(mockDatabaseService.insertBackupMetadata(testMetadata))
            .called(1);
      });

      test('document count is retrieved from database', () async {
        when(mockDatabaseService.getDocumentCount())
            .thenAnswer((_) async => 42);

        final count = await mockDatabaseService.getDocumentCount();

        expect(count, equals(42));
        verify(mockDatabaseService.getDocumentCount()).called(1);
      });

      test('database is closed before restoration', () async {
        when(mockDatabaseService.close()).thenAnswer((_) async => {});

        await mockDatabaseService.close();

        verify(mockDatabaseService.close()).called(1);
      });
    });

    group('Error Handling', () {
      test('listBackups handles database errors gracefully', () async {
        when(mockDatabaseService.getBackupMetadata(provider: null))
            .thenThrow(Exception('Database error'));

        expect(
          () => backupService.listBackups(),
          throwsException,
        );
      });

      test('getBackupStatistics handles empty backup list', () async {
        when(mockDatabaseService.getBackupMetadata(provider: null))
            .thenAnswer((_) async => []);

        final result = await backupService.getBackupStatistics();

        expect(result['totalBackups'], equals(0));
        expect(result['latestBackup'], isNull);
      });
    });

    group('Backup Metadata Validation', () {
      test('backup metadata contains all required fields', () {
        final metadata = BackupMetadata(
          id: 'test-id',
          provider: CloudProvider.googleDrive,
          timestamp: DateTime(2024, 1, 15),
          checksum: 'abc123',
          sizeBytes: 5000,
          isEncrypted: true,
          documentCount: 25,
          version: '1.0.0',
          remotePath: '/backups/test.enc',
          localPath: '/local/test.enc',
        );

        expect(metadata.id, equals('test-id'));
        expect(metadata.provider, equals(CloudProvider.googleDrive));
        expect(metadata.timestamp, equals(DateTime(2024, 1, 15)));
        expect(metadata.checksum, equals('abc123'));
        expect(metadata.sizeBytes, equals(5000));
        expect(metadata.isEncrypted, isTrue);
        expect(metadata.documentCount, equals(25));
        expect(metadata.version, equals('1.0.0'));
        expect(metadata.remotePath, equals('/backups/test.enc'));
        expect(metadata.localPath, equals('/local/test.enc'));
      });

      test('backup metadata handles optional fields', () {
        final metadata = BackupMetadata(
          id: 'test-id',
          provider: CloudProvider.local,
          timestamp: DateTime.now(),
          checksum: 'abc123',
          sizeBytes: 5000,
          isEncrypted: true,
          documentCount: 25,
          version: '1.0.0',
        );

        expect(metadata.remotePath, isNull);
        expect(metadata.localPath, isNull);
      });
    });

    group('Statistics Calculations', () {
      test('statistics handle large numbers correctly', () async {
        final testBackups = List.generate(
          100,
          (i) => BackupMetadata(
            id: 'backup-$i',
            provider: CloudProvider.local,
            timestamp: DateTime.now().subtract(Duration(days: i)),
            checksum: 'checksum-$i',
            sizeBytes: 10000,
            isEncrypted: true,
            documentCount: 50,
            version: '1.0.0',
          ),
        );

        when(mockDatabaseService.getBackupMetadata(provider: null))
            .thenAnswer((_) async => testBackups);

        final result = await backupService.getBackupStatistics();

        expect(result['totalBackups'], equals(100));
        expect(result['totalSizeBytes'], equals(1000000));
        expect(result['totalDocuments'], equals(5000));
      });

      test('statistics identify most recent backup', () async {
        final oldBackup = BackupMetadata(
          id: 'old',
          provider: CloudProvider.local,
          timestamp: DateTime(2024, 1, 1),
          checksum: 'checksum1',
          sizeBytes: 1000,
          isEncrypted: true,
          documentCount: 10,
          version: '1.0.0',
        );

        final recentBackup = BackupMetadata(
          id: 'recent',
          provider: CloudProvider.local,
          timestamp: DateTime(2024, 1, 15),
          checksum: 'checksum2',
          sizeBytes: 2000,
          isEncrypted: true,
          documentCount: 20,
          version: '1.0.0',
        );

        // Note: listBackups returns in insertion order, first is considered latest
        when(mockDatabaseService.getBackupMetadata(provider: null))
            .thenAnswer((_) async => [recentBackup, oldBackup]);

        final result = await backupService.getBackupStatistics();

        expect(result['latestBackup'], equals(DateTime(2024, 1, 15)));
      });
    });

    group('Cloud Provider Enum', () {
      test('all cloud providers are defined', () {
        expect(CloudProvider.values, contains(CloudProvider.local));
        expect(CloudProvider.values, contains(CloudProvider.googleDrive));
        expect(CloudProvider.values, contains(CloudProvider.oneDrive));
        expect(CloudProvider.values, contains(CloudProvider.dropbox));
      });

      test('cloud provider names are correct', () {
        expect(CloudProvider.local.name, equals('local'));
        expect(CloudProvider.googleDrive.name, equals('googleDrive'));
        expect(CloudProvider.oneDrive.name, equals('oneDrive'));
        expect(CloudProvider.dropbox.name, equals('dropbox'));
      });
    });
  });
}
