/// Cloud storage provider types
enum CloudProvider {
  googleDrive,
  oneDrive,
  dropbox,
  local,
}

/// Backup metadata entity
class BackupMetadata {
  final String id;
  final CloudProvider provider;
  final DateTime timestamp;
  final String checksum; // SHA-256 checksum of encrypted backup
  final int sizeBytes;
  final String? remotePath;
  final String? localPath;
  final bool isEncrypted;
  final int documentCount;
  final String? version; // App version that created the backup
  final Map<String, dynamic>? additionalMetadata;

  const BackupMetadata({
    required this.id,
    required this.provider,
    required this.timestamp,
    required this.checksum,
    required this.sizeBytes,
    this.remotePath,
    this.localPath,
    this.isEncrypted = true,
    required this.documentCount,
    this.version,
    this.additionalMetadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'provider': provider.name,
      'timestamp': timestamp.toIso8601String(),
      'checksum': checksum,
      'sizeBytes': sizeBytes,
      'remotePath': remotePath,
      'localPath': localPath,
      'isEncrypted': isEncrypted ? 1 : 0,
      'documentCount': documentCount,
      'version': version,
      'additionalMetadata': additionalMetadata,
    };
  }

  factory BackupMetadata.fromMap(Map<String, dynamic> map) {
    return BackupMetadata(
      id: map['id'] as String,
      provider: CloudProvider.values.firstWhere(
        (p) => p.name == map['provider'],
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      checksum: map['checksum'] as String,
      sizeBytes: map['sizeBytes'] as int,
      remotePath: map['remotePath'] as String?,
      localPath: map['localPath'] as String?,
      isEncrypted: (map['isEncrypted'] as int) == 1,
      documentCount: map['documentCount'] as int,
      version: map['version'] as String?,
      additionalMetadata: map['additionalMetadata'] as Map<String, dynamic>?,
    );
  }

  BackupMetadata copyWith({
    String? id,
    CloudProvider? provider,
    DateTime? timestamp,
    String? checksum,
    int? sizeBytes,
    String? remotePath,
    String? localPath,
    bool? isEncrypted,
    int? documentCount,
    String? version,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return BackupMetadata(
      id: id ?? this.id,
      provider: provider ?? this.provider,
      timestamp: timestamp ?? this.timestamp,
      checksum: checksum ?? this.checksum,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      remotePath: remotePath ?? this.remotePath,
      localPath: localPath ?? this.localPath,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      documentCount: documentCount ?? this.documentCount,
      version: version ?? this.version,
      additionalMetadata: additionalMetadata ?? this.additionalMetadata,
    );
  }
}
