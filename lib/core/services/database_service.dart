import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../domain/entities/document.dart';
import '../domain/entities/audit_event.dart';
import '../domain/entities/backup_metadata.dart';

/// Database service implementing SQLCipher encryption and FTS5 full-text search
///
/// Features:
/// - SQLCipher for database encryption at rest
/// - FTS5 for high-performance full-text search
/// - Transaction support for atomicity
/// - Optimized for 100,000+ documents
class DatabaseService {
  static const String _databaseName = 'doc_scanner.db';
  static const int _databaseVersion = 1;

  Database? _database;

  /// Initializes and opens the encrypted database
  Future<Database> getDatabase(String password) async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      password: password,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );

    return _database!;
  }

  /// Configure database settings
  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');

    // Optimize for performance
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA temp_store = MEMORY');
    await db.execute('PRAGMA mmap_size = 30000000000');
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    // Documents table
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        documentType TEXT NOT NULL,
        captureDate TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        encryptedImagePath TEXT NOT NULL,
        encryptedThumbnailPath TEXT NOT NULL,
        ocrText TEXT NOT NULL,
        checksum TEXT NOT NULL,
        fileSizeBytes INTEGER NOT NULL,
        tags TEXT,
        metadata TEXT,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        ocrConfidence REAL
      )
    ''');

    // FTS5 virtual table for full-text search
    await db.execute('''
      CREATE VIRTUAL TABLE documents_fts USING fts5(
        doc_id UNINDEXED,
        title,
        ocrText,
        tags,
        content='documents',
        content_rowid='rowid'
      )
    ''');

    // Triggers to keep FTS5 in sync
    await db.execute('''
      CREATE TRIGGER documents_ai AFTER INSERT ON documents BEGIN
        INSERT INTO documents_fts(doc_id, title, ocrText, tags)
        VALUES (new.id, new.title, new.ocrText, new.tags);
      END
    ''');

    await db.execute('''
      CREATE TRIGGER documents_ad AFTER DELETE ON documents BEGIN
        DELETE FROM documents_fts WHERE doc_id = old.id;
      END
    ''');

    await db.execute('''
      CREATE TRIGGER documents_au AFTER UPDATE ON documents BEGIN
        UPDATE documents_fts
        SET title = new.title, ocrText = new.ocrText, tags = new.tags
        WHERE doc_id = new.id;
      END
    ''');

    // Audit events table (append-only)
    await db.execute('''
      CREATE TABLE audit_events (
        id TEXT PRIMARY KEY,
        eventType TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        userId TEXT,
        deviceId TEXT,
        documentId TEXT,
        payload TEXT,
        errorMessage TEXT
      )
    ''');

    // Backup metadata table
    await db.execute('''
      CREATE TABLE backup_metadata (
        id TEXT PRIMARY KEY,
        provider TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        checksum TEXT NOT NULL,
        sizeBytes INTEGER NOT NULL,
        remotePath TEXT,
        localPath TEXT,
        isEncrypted INTEGER NOT NULL DEFAULT 1,
        documentCount INTEGER NOT NULL,
        version TEXT,
        additionalMetadata TEXT
      )
    ''');

    // Indexes for performance
    await db.execute(
        'CREATE INDEX idx_documents_captureDate ON documents(captureDate)');
    await db.execute(
        'CREATE INDEX idx_documents_documentType ON documents(documentType)');
    await db.execute(
        'CREATE INDEX idx_documents_isDeleted ON documents(isDeleted)');
    await db.execute(
        'CREATE INDEX idx_audit_events_timestamp ON audit_events(timestamp)');
    await db.execute(
        'CREATE INDEX idx_audit_events_eventType ON audit_events(eventType)');
    await db.execute(
        'CREATE INDEX idx_audit_events_documentId ON audit_events(documentId)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations here in future versions
  }

  /// Insert a document with transaction support
  Future<void> insertDocument(Document document) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    await db.transaction((txn) async {
      await txn.insert(
        'documents',
        document.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Update a document
  Future<void> updateDocument(Document document) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    await db.update(
      'documents',
      document.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  /// Get document by ID
  Future<Document?> getDocument(String id) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    final results = await db.query(
      'documents',
      where: 'id = ? AND isDeleted = 0',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return Document.fromMap(results.first);
  }

  /// Get all documents with pagination
  Future<List<Document>> getDocuments({
    int limit = 50,
    int offset = 0,
    String? documentType,
    bool includeDeleted = false,
  }) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    String where = includeDeleted ? '' : 'isDeleted = 0';
    List<dynamic> whereArgs = [];

    if (documentType != null) {
      where += (where.isEmpty ? '' : ' AND ') + 'documentType = ?';
      whereArgs.add(documentType);
    }

    final results = await db.query(
      'documents',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'captureDate DESC',
      limit: limit,
      offset: offset,
    );

    return results.map((map) => Document.fromMap(map)).toList();
  }

  /// Full-text search using FTS5
  Future<List<Document>> searchDocuments({
    required String query,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    // Escape query for FTS5
    final escapedQuery = query.replaceAll('"', '""');

    final results = await db.rawQuery('''
      SELECT d.*
      FROM documents d
      INNER JOIN documents_fts fts ON d.id = fts.doc_id
      WHERE documents_fts MATCH ? AND d.isDeleted = 0
      ORDER BY rank
      LIMIT ? OFFSET ?
    ''', [escapedQuery, limit, offset]);

    return results.map((map) => Document.fromMap(map)).toList();
  }

  /// Soft delete a document
  Future<void> deleteDocument(String id) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    await db.update(
      'documents',
      {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Insert audit event
  Future<void> insertAuditEvent(AuditEvent event) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    await db.insert(
      'audit_events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get audit events with filtering
  Future<List<AuditEvent>> getAuditEvents({
    AuditEventType? eventType,
    String? documentId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    String where = '';
    List<dynamic> whereArgs = [];

    if (eventType != null) {
      where += 'eventType = ?';
      whereArgs.add(eventType.name);
    }

    if (documentId != null) {
      where += (where.isEmpty ? '' : ' AND ') + 'documentId = ?';
      whereArgs.add(documentId);
    }

    if (startDate != null) {
      where += (where.isEmpty ? '' : ' AND ') + 'timestamp >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where += (where.isEmpty ? '' : ' AND ') + 'timestamp <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final results = await db.query(
      'audit_events',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return results.map((map) => AuditEvent.fromMap(map)).toList();
  }

  /// Insert backup metadata
  Future<void> insertBackupMetadata(BackupMetadata metadata) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    await db.insert(
      'backup_metadata',
      metadata.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get backup metadata list
  Future<List<BackupMetadata>> getBackupMetadata({
    CloudProvider? provider,
    int limit = 20,
  }) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    final results = await db.query(
      'backup_metadata',
      where: provider != null ? 'provider = ?' : null,
      whereArgs: provider != null ? [provider.name] : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return results.map((map) => BackupMetadata.fromMap(map)).toList();
  }

  /// Get document count
  Future<int> getDocumentCount({bool includeDeleted = false}) async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM documents WHERE isDeleted = ?',
      [includeDeleted ? 1 : 0],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Optimize database (vacuum and analyze)
  Future<void> optimize() async {
    final db = _database;
    if (db == null) throw Exception('Database not initialized');

    await db.execute('VACUUM');
    await db.execute('ANALYZE');
    await db
        .execute('INSERT INTO documents_fts(documents_fts) VALUES("optimize")');
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
