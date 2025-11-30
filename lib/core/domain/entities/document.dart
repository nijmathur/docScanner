/// Document entity representing a scanned and OCR-processed document
class Document {
  final String id;
  final String title;
  final String? description;
  final String documentType;
  final DateTime captureDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String encryptedImagePath;
  final String encryptedThumbnailPath;
  final String ocrText;
  final String checksum; // SHA-256 checksum of original image
  final int fileSizeBytes;
  final List<String> tags;
  final Map<String, dynamic>? metadata;
  final bool isDeleted;
  final double? ocrConfidence;

  const Document({
    required this.id,
    required this.title,
    this.description,
    required this.documentType,
    required this.captureDate,
    required this.createdAt,
    this.updatedAt,
    required this.encryptedImagePath,
    required this.encryptedThumbnailPath,
    required this.ocrText,
    required this.checksum,
    required this.fileSizeBytes,
    this.tags = const [],
    this.metadata,
    this.isDeleted = false,
    this.ocrConfidence,
  });

  Document copyWith({
    String? id,
    String? title,
    String? description,
    String? documentType,
    DateTime? captureDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? encryptedImagePath,
    String? encryptedThumbnailPath,
    String? ocrText,
    String? checksum,
    int? fileSizeBytes,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    bool? isDeleted,
    double? ocrConfidence,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      documentType: documentType ?? this.documentType,
      captureDate: captureDate ?? this.captureDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      encryptedImagePath: encryptedImagePath ?? this.encryptedImagePath,
      encryptedThumbnailPath:
          encryptedThumbnailPath ?? this.encryptedThumbnailPath,
      ocrText: ocrText ?? this.ocrText,
      checksum: checksum ?? this.checksum,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      isDeleted: isDeleted ?? this.isDeleted,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'documentType': documentType,
      'captureDate': captureDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'encryptedImagePath': encryptedImagePath,
      'encryptedThumbnailPath': encryptedThumbnailPath,
      'ocrText': ocrText,
      'checksum': checksum,
      'fileSizeBytes': fileSizeBytes,
      'tags': tags.join(','),
      'metadata': metadata,
      'isDeleted': isDeleted ? 1 : 0,
      'ocrConfidence': ocrConfidence,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      documentType: map['documentType'] as String,
      captureDate: DateTime.parse(map['captureDate'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      encryptedImagePath: map['encryptedImagePath'] as String,
      encryptedThumbnailPath: map['encryptedThumbnailPath'] as String,
      ocrText: map['ocrText'] as String,
      checksum: map['checksum'] as String,
      fileSizeBytes: map['fileSizeBytes'] as int,
      tags: (map['tags'] as String)
          .split(',')
          .where((t) => t.isNotEmpty)
          .toList(),
      metadata: map['metadata'] as Map<String, dynamic>?,
      isDeleted: (map['isDeleted'] as int) == 1,
      ocrConfidence: map['ocrConfidence'] as double?,
    );
  }
}
