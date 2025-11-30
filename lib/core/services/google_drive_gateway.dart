import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart' as sign_in;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'cloud_storage_gateway.dart';

/// Google Drive implementation of CloudStorageGateway
///
/// Uses OAuth2 for authentication and Google Drive API v3
class GoogleDriveGateway implements CloudStorageGateway {
  static const List<String> _scopes = [drive.DriveApi.driveFileScope];

  final sign_in.GoogleSignIn _googleSignIn;
  drive.DriveApi? _driveApi;

  GoogleDriveGateway()
      : _googleSignIn = sign_in.GoogleSignIn(
          scopes: _scopes,
        );

  @override
  String get providerName => 'Google Drive';

  @override
  Future<bool> authenticate() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return false;
      }

      // Get authenticated HTTP client
      final authClient = await _googleSignIn.authenticatedClient();
      if (authClient == null) {
        return false;
      }

      _driveApi = drive.DriveApi(authClient);
      return true;
    } catch (e) {
      throw CloudStorageException(
        'Google Drive authentication failed',
        providerName: providerName,
        originalError: e,
      );
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    if (_driveApi == null) {
      // Try silent sign-in
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final authClient = await _googleSignIn.authenticatedClient();
        if (authClient != null) {
          _driveApi = drive.DriveApi(authClient);
          return true;
        }
      }
      return false;
    }
    return true;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _driveApi = null;
  }

  @override
  Future<CloudFileMetadata> uploadFile({
    required String localPath,
    required String remotePath,
    UploadProgressCallback? onProgress,
  }) async {
    if (_driveApi == null) {
      throw CloudStorageException(
        'Not authenticated',
        providerName: providerName,
      );
    }

    try {
      final file = File(localPath);
      final fileSize = await file.length();
      final fileName = remotePath.split('/').last;

      // Create file metadata
      final driveFile = drive.File()..name = fileName;

      // Upload file
      final media = drive.Media(file.openRead(), fileSize);
      final uploadedFile = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      return CloudFileMetadata(
        id: uploadedFile.id!,
        name: uploadedFile.name!,
        path: remotePath,
        sizeBytes: int.parse(uploadedFile.size ?? '0'),
        modifiedTime: uploadedFile.modifiedTime,
      );
    } catch (e) {
      throw CloudStorageException(
        'Upload failed: $remotePath',
        providerName: providerName,
        originalError: e,
      );
    }
  }

  @override
  Future<String> downloadFile({
    required String remotePath,
    required String localPath,
    DownloadProgressCallback? onProgress,
  }) async {
    if (_driveApi == null) {
      throw CloudStorageException(
        'Not authenticated',
        providerName: providerName,
      );
    }

    try {
      // Find file by name
      final fileName = remotePath.split('/').last;
      final fileList = await _driveApi!.files.list(
        q: "name='$fileName'",
        spaces: 'drive',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        throw CloudStorageException(
          'File not found: $remotePath',
          providerName: providerName,
        );
      }

      final fileId = fileList.files!.first.id!;

      // Download file
      final drive.Media media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Write to local file
      final localFile = File(localPath);
      final sink = localFile.openWrite();

      await for (final chunk in media.stream) {
        sink.add(chunk);
        if (onProgress != null) {
          // Note: We don't have total size here, would need separate call
          onProgress(chunk.length, -1);
        }
      }

      await sink.close();
      return localPath;
    } catch (e) {
      throw CloudStorageException(
        'Download failed: $remotePath',
        providerName: providerName,
        originalError: e,
      );
    }
  }

  @override
  Future<List<CloudFileMetadata>> listFiles({String? remotePath}) async {
    if (_driveApi == null) {
      throw CloudStorageException(
        'Not authenticated',
        providerName: providerName,
      );
    }

    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'drive',
        $fields: 'files(id, name, size, modifiedTime, md5Checksum)',
      );

      if (fileList.files == null) {
        return [];
      }

      return fileList.files!.map((file) {
        return CloudFileMetadata(
          id: file.id!,
          name: file.name!,
          path: file.name!,
          sizeBytes: int.tryParse(file.size ?? '0') ?? 0,
          modifiedTime: file.modifiedTime,
          checksum: file.md5Checksum,
        );
      }).toList();
    } catch (e) {
      throw CloudStorageException(
        'List files failed',
        providerName: providerName,
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    if (_driveApi == null) {
      throw CloudStorageException(
        'Not authenticated',
        providerName: providerName,
      );
    }

    try {
      final fileName = remotePath.split('/').last;
      final fileList = await _driveApi!.files.list(
        q: "name='$fileName'",
        spaces: 'drive',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        await _driveApi!.files.delete(fileList.files!.first.id!);
      }
    } catch (e) {
      throw CloudStorageException(
        'Delete failed: $remotePath',
        providerName: providerName,
        originalError: e,
      );
    }
  }

  @override
  Future<CloudFileMetadata> getFileMetadata(String remotePath) async {
    if (_driveApi == null) {
      throw CloudStorageException(
        'Not authenticated',
        providerName: providerName,
      );
    }

    try {
      final fileName = remotePath.split('/').last;
      final fileList = await _driveApi!.files.list(
        q: "name='$fileName'",
        spaces: 'drive',
        $fields: 'files(id, name, size, modifiedTime, md5Checksum)',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        throw CloudStorageException(
          'File not found: $remotePath',
          providerName: providerName,
        );
      }

      final file = fileList.files!.first;
      return CloudFileMetadata(
        id: file.id!,
        name: file.name!,
        path: remotePath,
        sizeBytes: int.tryParse(file.size ?? '0') ?? 0,
        modifiedTime: file.modifiedTime,
        checksum: file.md5Checksum,
      );
    } catch (e) {
      throw CloudStorageException(
        'Get metadata failed: $remotePath',
        providerName: providerName,
        originalError: e,
      );
    }
  }

  @override
  Future<bool> fileExists(String remotePath) async {
    try {
      await getFileMetadata(remotePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int?> getAvailableSpace() async {
    if (_driveApi == null) {
      return null;
    }

    try {
      final about = await _driveApi!.about.get($fields: 'storageQuota');
      final quota = about.storageQuota;
      if (quota != null && quota.limit != null && quota.usage != null) {
        final limit = int.tryParse(quota.limit!) ?? 0;
        final usage = int.tryParse(quota.usage!) ?? 0;
        return limit - usage;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int?> getUsedSpace() async {
    if (_driveApi == null) {
      return null;
    }

    try {
      final about = await _driveApi!.about.get($fields: 'storageQuota');
      final quota = about.storageQuota;
      if (quota != null && quota.usage != null) {
        return int.tryParse(quota.usage!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
