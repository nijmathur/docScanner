/// Audit event types for tracking all sensitive operations
enum AuditEventType {
  documentCreated,
  documentViewed,
  documentUpdated,
  documentDeleted,
  searchPerformed,
  authenticationSuccess,
  authenticationFailure,
  backupExported,
  backupRestored,
  decryptionError,
  keyAccess,
  settingsChanged,
}

/// Immutable audit event entity
class AuditEvent {
  final String id;
  final AuditEventType eventType;
  final DateTime timestamp;
  final String? userId;
  final String? deviceId;
  final String? documentId;
  final Map<String, dynamic>? payload;
  final String? errorMessage;

  const AuditEvent({
    required this.id,
    required this.eventType,
    required this.timestamp,
    this.userId,
    this.deviceId,
    this.documentId,
    this.payload,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventType': eventType.name,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'deviceId': deviceId,
      'documentId': documentId,
      'payload': payload,
      'errorMessage': errorMessage,
    };
  }

  factory AuditEvent.fromMap(Map<String, dynamic> map) {
    return AuditEvent(
      id: map['id'] as String,
      eventType: AuditEventType.values.firstWhere(
        (e) => e.name == map['eventType'],
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      userId: map['userId'] as String?,
      deviceId: map['deviceId'] as String?,
      documentId: map['documentId'] as String?,
      payload: map['payload'] as Map<String, dynamic>?,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  AuditEvent copyWith({
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
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      documentId: documentId ?? this.documentId,
      payload: payload ?? this.payload,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
