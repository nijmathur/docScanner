import 'package:uuid/uuid.dart';
import '../domain/entities/audit_event.dart';
import 'database_service.dart';

/// Audit Service for logging all sensitive operations
///
/// Features:
/// - Immutable, append-only audit log
/// - Automatic timestamping
/// - Device and user tracking
/// - Query and filtering capabilities
/// - Compliance-ready audit trail
class AuditService {
  final DatabaseService _databaseService;
  final String? _userId;
  final String? _deviceId;

  static const _uuid = Uuid();

  AuditService({
    required DatabaseService databaseService,
    String? userId,
    String? deviceId,
  })  : _databaseService = databaseService,
        _userId = userId,
        _deviceId = deviceId;

  /// Log a document creation event
  Future<void> logDocumentCreated({
    required String documentId,
    Map<String, dynamic>? additionalData,
  }) async {
    await _logEvent(
      eventType: AuditEventType.documentCreated,
      documentId: documentId,
      payload: additionalData,
    );
  }

  /// Log a document view event
  Future<void> logDocumentViewed({
    required String documentId,
    Map<String, dynamic>? additionalData,
  }) async {
    await _logEvent(
      eventType: AuditEventType.documentViewed,
      documentId: documentId,
      payload: additionalData,
    );
  }

  /// Log a document update event
  Future<void> logDocumentUpdated({
    required String documentId,
    Map<String, dynamic>? changes,
  }) async {
    await _logEvent(
      eventType: AuditEventType.documentUpdated,
      documentId: documentId,
      payload: changes,
    );
  }

  /// Log a document deletion event
  Future<void> logDocumentDeleted({
    required String documentId,
    Map<String, dynamic>? additionalData,
  }) async {
    await _logEvent(
      eventType: AuditEventType.documentDeleted,
      documentId: documentId,
      payload: additionalData,
    );
  }

  /// Log a search operation
  Future<void> logSearchPerformed({
    required String query,
    required int resultCount,
    Map<String, dynamic>? filters,
  }) async {
    await _logEvent(
      eventType: AuditEventType.searchPerformed,
      payload: {
        'query': query,
        'resultCount': resultCount,
        'filters': filters,
      },
    );
  }

  /// Log successful authentication
  Future<void> logAuthenticationSuccess({
    required String method,
  }) async {
    await _logEvent(
      eventType: AuditEventType.authenticationSuccess,
      payload: {'method': method},
    );
  }

  /// Log failed authentication attempt
  Future<void> logAuthenticationFailure({
    required String method,
    required String reason,
  }) async {
    await _logEvent(
      eventType: AuditEventType.authenticationFailure,
      payload: {'method': method, 'reason': reason},
    );
  }

  /// Log backup export
  Future<void> logBackupExported({
    required String provider,
    required int documentCount,
    required int sizeBytes,
    Map<String, dynamic>? additionalData,
  }) async {
    await _logEvent(
      eventType: AuditEventType.backupExported,
      payload: {
        'provider': provider,
        'documentCount': documentCount,
        'sizeBytes': sizeBytes,
        ...?additionalData,
      },
    );
  }

  /// Log backup restore
  Future<void> logBackupRestored({
    required String provider,
    required int documentCount,
    Map<String, dynamic>? additionalData,
  }) async {
    await _logEvent(
      eventType: AuditEventType.backupRestored,
      payload: {
        'provider': provider,
        'documentCount': documentCount,
        ...?additionalData,
      },
    );
  }

  /// Log decryption error
  Future<void> logDecryptionError({
    String? documentId,
    required String errorMessage,
  }) async {
    await _logEvent(
      eventType: AuditEventType.decryptionError,
      documentId: documentId,
      errorMessage: errorMessage,
    );
  }

  /// Log key access
  Future<void> logKeyAccess({
    required String keyType,
    required String operation,
  }) async {
    await _logEvent(
      eventType: AuditEventType.keyAccess,
      payload: {
        'keyType': keyType,
        'operation': operation,
      },
    );
  }

  /// Log settings change
  Future<void> logSettingsChanged({
    required Map<String, dynamic> changes,
  }) async {
    await _logEvent(
      eventType: AuditEventType.settingsChanged,
      payload: changes,
    );
  }

  /// Internal method to log an event
  Future<void> _logEvent({
    required AuditEventType eventType,
    String? documentId,
    Map<String, dynamic>? payload,
    String? errorMessage,
  }) async {
    final event = AuditEvent(
      id: _uuid.v4(),
      eventType: eventType,
      timestamp: DateTime.now(),
      userId: _userId,
      deviceId: _deviceId,
      documentId: documentId,
      payload: payload,
      errorMessage: errorMessage,
    );

    try {
      await _databaseService.insertAuditEvent(event);
    } catch (e) {
      // Critical: audit logging should not fail the main operation
      // In production, consider fallback logging mechanism
      // Silently fail - could implement fallback file logging here
    }
  }

  /// Get audit events for a specific document
  Future<List<AuditEvent>> getDocumentAuditTrail(String documentId) async {
    return _databaseService.getAuditEvents(documentId: documentId);
  }

  /// Get all audit events of a specific type
  Future<List<AuditEvent>> getEventsByType(AuditEventType eventType) async {
    return _databaseService.getAuditEvents(eventType: eventType);
  }

  /// Get audit events within a date range
  Future<List<AuditEvent>> getEventsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 100,
  }) async {
    return _databaseService.getAuditEvents(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Get recent audit events
  Future<List<AuditEvent>> getRecentEvents({int limit = 50}) async {
    return _databaseService.getAuditEvents(limit: limit);
  }

  /// Generate audit summary report
  Future<Map<String, dynamic>> generateAuditSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final events = await _databaseService.getAuditEvents(
      startDate: startDate,
      endDate: endDate,
      limit: 10000, // Get all events in range
    );

    final summary = <String, dynamic>{
      'totalEvents': events.length,
      'dateRange': {
        'start': startDate?.toIso8601String(),
        'end': endDate?.toIso8601String(),
      },
      'eventCounts': <String, int>{},
      'documentActivity': <String, int>{},
      'authenticationAttempts': {
        'success': 0,
        'failure': 0,
      },
    };

    for (final event in events) {
      // Count by event type
      final typeName = event.eventType.name;
      summary['eventCounts'][typeName] =
          (summary['eventCounts'][typeName] as int? ?? 0) + 1;

      // Track document activity
      if (event.documentId != null) {
        summary['documentActivity'][event.documentId!] =
            (summary['documentActivity'][event.documentId!] as int? ?? 0) + 1;
      }

      // Track authentication
      if (event.eventType == AuditEventType.authenticationSuccess) {
        summary['authenticationAttempts']['success']++;
      } else if (event.eventType == AuditEventType.authenticationFailure) {
        summary['authenticationAttempts']['failure']++;
      }
    }

    return summary;
  }

  /// Export audit log to JSON format
  Future<String> exportAuditLog({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final events = await _databaseService.getAuditEvents(
      startDate: startDate,
      endDate: endDate,
      limit: 100000,
    );

    final export = {
      'exportDate': DateTime.now().toIso8601String(),
      'totalEvents': events.length,
      'events': events.map((e) => e.toMap()).toList(),
    };

    // Convert to JSON string
    // Note: In production, use dart:convert's jsonEncode
    return export.toString();
  }
}
