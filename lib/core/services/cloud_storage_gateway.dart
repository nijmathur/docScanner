/// Upload progress callback
typedef UploadProgressCallback = void Function(int sent, int total);

/// Download progress callback
typedef DownloadProgressCallback = void Function(int received, int total);

/// Cloud file metadata
class CloudFileMetadata {
  final String id;
  final String name;
  final String path;
  final int sizeBytes;
  final DateTime? modifiedTime;
  final String? checksum;

  const CloudFileMetadata({
    required this.id,
    required this.name,
    required this.path,
    required this.sizeBytes,
    this.modifiedTime,
    this.checksum,
  });
}

/// Abstract cloud storage gateway interface
///
/// All cloud provider implementations must implement this interface
/// following the SOLID principles (Interface Segregation, Dependency Inversion)
abstract class CloudStorageGateway {
  /// Provider name
  String get providerName;

  /// Initialize and authenticate with the cloud provider
  Future<bool> authenticate();

  /// Check if currently authenticated
  Future<bool> isAuthenticated();

  /// Sign out and clear authentication tokens
  Future<void> signOut();

  /// Upload a file to cloud storage
  ///
  /// [localPath] - Path to local file
  /// [remotePath] - Destination path in cloud storage
  /// [onProgress] - Optional progress callback
  ///
  /// Returns: CloudFileMetadata of uploaded file
  Future<CloudFileMetadata> uploadFile({
    required String localPath,
    required String remotePath,
    UploadProgressCallback? onProgress,
  });

  /// Download a file from cloud storage
  ///
  /// [remotePath] - Path in cloud storage
  /// [localPath] - Destination path for downloaded file
  /// [onProgress] - Optional progress callback
  ///
  /// Returns: Local file path
  Future<String> downloadFile({
    required String remotePath,
    required String localPath,
    DownloadProgressCallback? onProgress,
  });

  /// List files in a directory
  ///
  /// [remotePath] - Directory path in cloud storage
  /// Returns: List of file metadata
  Future<List<CloudFileMetadata>> listFiles({String? remotePath});

  /// Delete a file from cloud storage
  Future<void> deleteFile(String remotePath);

  /// Get file metadata without downloading
  Future<CloudFileMetadata> getFileMetadata(String remotePath);

  /// Check if a file exists
  Future<bool> fileExists(String remotePath);

  /// Get available storage space (if supported)
  Future<int?> getAvailableSpace();

  /// Get used storage space (if supported)
  Future<int?> getUsedSpace();
}

/// Exception for cloud storage operations
class CloudStorageException implements Exception {
  final String message;
  final String? providerName;
  final Object? originalError;

  CloudStorageException(
    this.message, {
    this.providerName,
    this.originalError,
  });

  @override
  String toString() {
    return 'CloudStorageException: $message'
        '${providerName != null ? ' (Provider: $providerName)' : ''}'
        '${originalError != null ? ' - Original error: $originalError' : ''}';
  }
}
