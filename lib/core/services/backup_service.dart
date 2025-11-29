import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../domain/entities/backup_metadata.dart';
import 'database_service.dart';
import 'encryption_service.dart';
import 'cloud_storage_gateway.dart';
import 'audit_service.dart';

/// Backup Service for creating and restoring encrypted backups
///
/// Features:
/// - Creates encrypted tar.gz archives of database + document blobs
/// - Password-based backup encryption (separate from app PIN)
/// - Multi-cloud provider support
/// - Integrity verification with SHA-256 checksums
/// - Automatic backup metadata tracking
class BackupService {
  final DatabaseService _databaseService;
  final EncryptionService _encryptionService;
  final AuditService _auditService;
  final String _documentsPath;

  static const _uuid = Uuid();

  BackupService({
    required DatabaseService databaseService,
    required EncryptionService encryptionService,
    required AuditService auditService,
    required String documentsPath,
  })  : _databaseService = databaseService,
        _encryptionService = encryptionService,
        _auditService = auditService,
        _documentsPath = documentsPath;

  /// Create an encrypted backup
  ///
  /// Steps:
  /// 1. Close/checkpoint database
  /// 2. Create tar.gz archive of database + encrypted document files
  /// 3. Encrypt archive with user-provided password
  /// 4. Compute checksum
  /// 5. Upload to cloud provider (optional)
  /// 6. Store backup metadata
  Future<BackupMetadata> createBackup({
    required String password,
    required String backupDirectory,
    CloudStorageGateway? cloudGateway,
    String? remotePath,
    Function(int, int)? onProgress,
  }) async {
    final backupId = _uuid.v4();
    final timestamp = DateTime.now();

    try {
      // 1. Get document count
      final documentCount = await _databaseService.getDocumentCount();

      // 2. Create temporary archive directory
      final tempDir = Directory.systemTemp.createTempSync('backup_$backupId');
      final archivePath = path.join(tempDir.path, 'archive.tar.gz');

      // 3. Create tar.gz archive
      await _createArchive(archivePath);

      // 4. Derive backup encryption key from password
      final salt = _encryptionService.generateSalt();
      final bek = _encryptionService.deriveBEK(
        password: password,
        salt: salt,
      );

      // 5. Encrypt archive
      final encryptedArchivePath = '$archivePath.enc';
      await _encryptArchive(
        sourcePath: archivePath,
        destinationPath: encryptedArchivePath,
        key: bek,
        salt: salt,
      );

      // 6. Compute checksum
      final encryptedFile = File(encryptedArchivePath);
      final encryptedBytes = await encryptedFile.readAsBytes();
      final checksum = _encryptionService.computeChecksum(encryptedBytes);
      final sizeBytes = encryptedBytes.length;

      // 7. Move to backup directory
      final backupFileName = 'backup_$backupId.enc';
      final finalBackupPath = path.join(backupDirectory, backupFileName);
      await encryptedFile.copy(finalBackupPath);

      String? cloudPath;
      CloudProvider provider = CloudProvider.local;

      // 8. Upload to cloud if gateway provided
      if (cloudGateway != null && remotePath != null) {
        final cloudRemotePath = path.join(remotePath, backupFileName);
        await cloudGateway.uploadFile(
          localPath: finalBackupPath,
          remotePath: cloudRemotePath,
          onProgress: onProgress,
        );
        cloudPath = cloudRemotePath;

        // Determine provider type
        if (cloudGateway.providerName.contains('Google')) {
          provider = CloudProvider.googleDrive;
        } else if (cloudGateway.providerName.contains('OneDrive')) {
          provider = CloudProvider.oneDrive;
        } else if (cloudGateway.providerName.contains('Dropbox')) {
          provider = CloudProvider.dropbox;
        }
      }

      // 9. Create backup metadata
      final metadata = BackupMetadata(
        id: backupId,
        provider: provider,
        timestamp: timestamp,
        checksum: checksum,
        sizeBytes: sizeBytes,
        remotePath: cloudPath,
        localPath: finalBackupPath,
        isEncrypted: true,
        documentCount: documentCount,
        version: '1.0.0', // App version
      );

      // 10. Store metadata in database
      await _databaseService.insertBackupMetadata(metadata);

      // 11. Log audit event
      await _auditService.logBackupExported(
        provider: provider.name,
        documentCount: documentCount,
        sizeBytes: sizeBytes,
      );

      // 12. Cleanup temporary files
      await tempDir.delete(recursive: true);

      return metadata;
    } catch (e) {
      throw Exception('Backup creation failed: $e');
    }
  }

  /// Restore from an encrypted backup
  ///
  /// Steps:
  /// 1. Download backup from cloud if needed
  /// 2. Verify checksum
  /// 3. Decrypt with user password
  /// 4. Extract archive
  /// 5. Replace local database and documents
  /// 6. Log audit event
  Future<void> restoreBackup({
    required BackupMetadata backupMetadata,
    required String password,
    required String restoreDirectory,
    CloudStorageGateway? cloudGateway,
    Function(int, int)? onProgress,
  }) async {
    try {
      String backupPath = backupMetadata.localPath ?? '';

      // 1. Download from cloud if needed
      if (backupMetadata.remotePath != null && cloudGateway != null) {
        final tempDir = Directory.systemTemp.createTempSync('restore_');
        backupPath = path.join(tempDir.path, 'backup.enc');

        await cloudGateway.downloadFile(
          remotePath: backupMetadata.remotePath!,
          localPath: backupPath,
          onProgress: onProgress,
        );
      }

      // 2. Verify checksum
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found');
      }

      final backupBytes = await backupFile.readAsBytes();
      final checksum = _encryptionService.computeChecksum(backupBytes);

      if (checksum != backupMetadata.checksum) {
        throw Exception('Backup integrity check failed: checksum mismatch');
      }

      // 3. Derive BEK and decrypt
      final salt = backupBytes.sublist(0, 32); // First 32 bytes are salt
      final bek = _encryptionService.deriveBEK(
        password: password,
        salt: Uint8List.fromList(salt),
      );

      final tempDir = Directory.systemTemp.createTempSync('restore_decrypt_');
      final decryptedPath = path.join(tempDir.path, 'archive.tar.gz');

      await _decryptArchive(
        sourcePath: backupPath,
        destinationPath: decryptedPath,
        key: bek,
      );

      // 4. Extract archive
      final extractDir = path.join(tempDir.path, 'extracted');
      await _extractArchive(decryptedPath, extractDir);

      // 5. Close current database
      await _databaseService.close();

      // 6. Replace database and documents
      // Note: This is destructive! User should be warned.
      await _replaceData(extractDir, restoreDirectory);

      // 7. Log audit event
      await _auditService.logBackupRestored(
        provider: backupMetadata.provider.name,
        documentCount: backupMetadata.documentCount,
      );

      // 8. Cleanup
      await tempDir.delete(recursive: true);
    } catch (e) {
      throw Exception('Backup restoration failed: $e');
    }
  }

  /// Create tar.gz archive of database and documents
  Future<void> _createArchive(String archivePath) async {
    final encoder = TarFileEncoder();
    encoder.create(archivePath);

    // Add database file (if accessible)
    // Note: You may need to checkpoint/close the database first
    // For now, this is a placeholder

    // Add all encrypted document files
    final documentsDir = Directory(_documentsPath);
    if (await documentsDir.exists()) {
      final files = documentsDir.listSync(recursive: true);
      for (final file in files) {
        if (file is File) {
          encoder.addFile(file);
        }
      }
    }

    encoder.close();
  }

  /// Encrypt archive with BEK
  Future<void> _encryptArchive({
    required String sourcePath,
    required String destinationPath,
    required Uint8List key,
    required Uint8List salt,
  }) async {
    final sourceFile = File(sourcePath);
    final plaintext = await sourceFile.readAsBytes();

    final encrypted = _encryptionService.encryptBytes(
      plaintext: plaintext,
      key: key,
    );

    // Prepend salt to encrypted data (salt || encrypted_data)
    final output = Uint8List(salt.length + encrypted.length);
    output.setAll(0, salt);
    output.setAll(salt.length, encrypted);

    final destFile = File(destinationPath);
    await destFile.writeAsBytes(output);
  }

  /// Decrypt archive with BEK
  Future<void> _decryptArchive({
    required String sourcePath,
    required String destinationPath,
    required Uint8List key,
  }) async {
    final sourceFile = File(sourcePath);
    final encryptedWithSalt = await sourceFile.readAsBytes();

    // Extract salt and encrypted data
    final salt = encryptedWithSalt.sublist(0, 32);
    final encrypted = encryptedWithSalt.sublist(32);

    final decrypted = _encryptionService.decryptBytes(
      ciphertext: encrypted,
      key: key,
    );

    final destFile = File(destinationPath);
    await destFile.writeAsBytes(decrypted);
  }

  /// Extract tar.gz archive
  Future<void> _extractArchive(String archivePath, String extractPath) async {
    await Directory(extractPath).create(recursive: true);
    await extractFileToDisk(archivePath, extractPath);
  }

  /// Replace current data with restored data
  Future<void> _replaceData(String sourceDir, String targetDir) async {
    final source = Directory(sourceDir);
    final target = Directory(targetDir);

    if (!await target.exists()) {
      await target.create(recursive: true);
    }

    // Copy all files from source to target
    await for (final entity in source.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: sourceDir);
        final targetPath = path.join(targetDir, relativePath);

        final targetFile = File(targetPath);
        await targetFile.parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  /// List available backups
  Future<List<BackupMetadata>> listBackups({
    CloudProvider? provider,
  }) async {
    return _databaseService.getBackupMetadata(provider: provider);
  }

  /// Delete a backup
  Future<void> deleteBackup(BackupMetadata metadata) async {
    // Delete local file if exists
    if (metadata.localPath != null) {
      final file = File(metadata.localPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Note: Cloud deletion would require cloud gateway
    // This is left for implementation when deleting from cloud
  }

  /// Get backup statistics
  Future<Map<String, dynamic>> getBackupStatistics() async {
    final backups = await listBackups();

    int totalSize = 0;
    int totalDocuments = 0;
    final providerCounts = <String, int>{};

    for (final backup in backups) {
      totalSize += backup.sizeBytes;
      totalDocuments += backup.documentCount;

      final providerName = backup.provider.name;
      providerCounts[providerName] = (providerCounts[providerName] ?? 0) + 1;
    }

    return {
      'totalBackups': backups.length,
      'totalSizeBytes': totalSize,
      'totalDocuments': totalDocuments,
      'providerCounts': providerCounts,
      'latestBackup': backups.isNotEmpty ? backups.first.timestamp : null,
    };
  }
}
