import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:journal_new/models/attachment.dart';
import 'package:journal_new/models/entry.dart';
import 'package:journal_new/models/journal.dart';
import 'package:journal_new/models/user.dart';

/// Helper class for managing test databases in isolation
class TestDatabaseHelper {
  static Database? _testDatabase;
  static String? _testDatabasePath;

  /// Creates and initializes a temporary test database
  static Future<Database> createTestDatabase({String? name}) async {
    final testDbName = name ?? 'test_db_${DateTime.now().millisecondsSinceEpoch}.db';
    final databasesPath = await getDatabasesPath();
    _testDatabasePath = path.join(databasesPath, testDbName);

    // Delete if exists
    if (await File(_testDatabasePath!).exists()) {
      await File(_testDatabasePath!).delete();
    }

    _testDatabase = await openDatabase(
      _testDatabasePath!,
      version: 1,
      onCreate: _createTestTables,
    );

    return _testDatabase!;
  }

  /// Creates all necessary tables for testing
  static Future<void> _createTestTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE journals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        shared_with_user_ids TEXT,
        is_shared INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (owner_id) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE entries (
        id TEXT PRIMARY KEY,
        journal_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        tags TEXT,
        latitude REAL,
        longitude REAL,
        location_name TEXT,
        rating INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (journal_id) REFERENCES journals (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE attachments (
        id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL,
        type TEXT NOT NULL,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        size INTEGER,
        mime_type TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES entries (id)
      )
    ''');
  }

  /// Inserts test data into the database
  static Future<void> insertTestData(Database db, {
    List<User>? users,
    List<Journal>? journals,
    List<Entry>? entries,
    List<Attachment>? attachments,
  }) async {
    // Insert users
    if (users != null) {
      for (final user in users) {
        await db.insert('users', {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'created_at': user.createdAt.toIso8601String(),
          'updated_at': user.updatedAt.toIso8601String(),
        });
      }
    }

    // Insert journals
    if (journals != null) {
      for (final journal in journals) {
        await db.insert('journals', {
          'id': journal.id,
          'name': journal.name,
          'description': journal.description,
          'owner_id': journal.ownerId,
          'shared_with_user_ids': journal.sharedWithUserIds.join(','),
          'is_shared': journal.isShared ? 1 : 0,
          'created_at': journal.createdAt.toIso8601String(),
          'updated_at': journal.updatedAt.toIso8601String(),
        });
      }
    }

    // Insert entries
    if (entries != null) {
      for (final entry in entries) {
        await db.insert('entries', {
          'id': entry.id,
          'journal_id': entry.journalId,
          'title': entry.title,
          'content': entry.content,
          'tags': entry.tags.join(','),
          'latitude': entry.latitude,
          'longitude': entry.longitude,
          'location_name': entry.locationName,
          'rating': entry.rating,
          'created_at': entry.createdAt.toIso8601String(),
          'updated_at': entry.updatedAt.toIso8601String(),
        });
      }
    }

    // Insert attachments
    if (attachments != null) {
      for (final attachment in attachments) {
        await db.insert('attachments', {
          'id': attachment.id,
          'entry_id': attachment.entryId,
          'type': attachment.type.name,
          'name': attachment.name,
          'path': attachment.path,
          'size': attachment.size,
          'mime_type': attachment.mimeType,
          'metadata': attachment.metadata?.toString(),
          'created_at': attachment.createdAt.toIso8601String(),
          'updated_at': attachment.updatedAt?.toIso8601String() ?? attachment.createdAt.toIso8601String(),
        });
      }
    }
  }

  /// Gets all attachments from test database
  static Future<List<Attachment>> getAllAttachments(Database db) async {
    final maps = await db.query('attachments');
    return maps.map((map) => Attachment.fromMap(map)).toList();
  }

  /// Gets attachments with legacy paths (absolute paths)
  static Future<List<Attachment>> getLegacyAttachments(Database db) async {
    final maps = await db.rawQuery('''
      SELECT * FROM attachments 
      WHERE path LIKE '/%' OR path LIKE '_:%'
    ''');
    return maps.map((map) => Attachment.fromMap(map)).toList();
  }

  /// Gets attachments with modern paths (relative paths)
  static Future<List<Attachment>> getModernAttachments(Database db) async {
    final maps = await db.rawQuery('''
      SELECT * FROM attachments 
      WHERE path NOT LIKE '/%' AND path NOT LIKE '_:%'
    ''');
    return maps.map((map) => Attachment.fromMap(map)).toList();
  }

  /// Updates an attachment's path
  static Future<void> updateAttachmentPath(Database db, String attachmentId, String newPath) async {
    await db.update(
      'attachments',
      {
        'path': newPath,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
  }

  /// Counts attachments by type
  static Future<Map<String, int>> countAttachmentsByType(Database db) async {
    final result = await db.rawQuery('''
      SELECT type, COUNT(*) as count 
      FROM attachments 
      GROUP BY type
    ''');
    
    final counts = <String, int>{};
    for (final row in result) {
      counts[row['type'] as String] = row['count'] as int;
    }
    return counts;
  }

  /// Gets migration statistics
  static Future<Map<String, int>> getMigrationStats(Database db) async {
    final legacyResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM attachments 
      WHERE path LIKE '/%' OR path LIKE '_:%'
    ''');
    final legacyCount = legacyResult.first['count'] as int;

    final modernResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM attachments 
      WHERE path NOT LIKE '/%' AND path NOT LIKE '_:%'
    ''');
    final modernCount = modernResult.first['count'] as int;

    return {
      'legacy': legacyCount,
      'modern': modernCount,
      'total': legacyCount + modernCount,
    };
  }

  /// Creates a backup of current database state
  static Future<String> createDatabaseSnapshot(Database db) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final snapshotPath = path.join(
      path.dirname(_testDatabasePath!), 
      'snapshot_$timestamp.db'
    );
    
    await File(_testDatabasePath!).copy(snapshotPath);
    return snapshotPath;
  }

  /// Restores database from a snapshot
  static Future<void> restoreFromSnapshot(String snapshotPath) async {
    if (_testDatabase != null) {
      await _testDatabase!.close();
    }
    
    await File(snapshotPath).copy(_testDatabasePath!);
    _testDatabase = await openDatabase(_testDatabasePath!);
  }

  /// Executes a raw SQL query for testing
  static Future<List<Map<String, dynamic>>> executeRawQuery(Database db, String sql, [List<dynamic>? arguments]) async {
    return await db.rawQuery(sql, arguments);
  }

  /// Cleans up the test database
  static Future<void> cleanup() async {
    if (_testDatabase != null) {
      await _testDatabase!.close();
      _testDatabase = null;
    }
    
    if (_testDatabasePath != null && await File(_testDatabasePath!).exists()) {
      await File(_testDatabasePath!).delete();
      _testDatabasePath = null;
    }
  }

  /// Sets up a fresh test database with sample migration data
  static Future<Database> setupMigrationTestDb({
    int legacyAttachmentCount = 10,
    int modernAttachmentCount = 5,
  }) async {
    final db = await createTestDatabase(name: 'migration_test.db');
    
    // Create test users and journals
    final user = User(
      id: 'test-user-1',
      name: 'Test User',
      email: 'test@example.com',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    final journal = Journal(
      id: 'test-journal-1',
      name: 'Test Journal',
      description: 'Test journal for migration',
      ownerId: user.id,
      sharedWithUserIds: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final entry = Entry(
      id: 'test-entry-1',
      journalId: journal.id,
      title: 'Test Entry',
      content: 'Test entry content',
      tags: ['test'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      attachments: [],
    );

    // Create test attachments
    final attachments = <Attachment>[];
    
    // Legacy attachments
    for (int i = 0; i < legacyAttachmentCount; i++) {
      final attachment = Attachment(
        id: 'legacy-attachment-$i',
        entryId: entry.id,
        type: AttachmentType.photo,
        name: 'legacy_image_$i.jpg',
        path: '/Users/testuser/Pictures/legacy_image_$i.jpg', // Absolute path
        size: 1024 * (i + 1),
        mimeType: 'image/jpeg',
        createdAt: DateTime.now().subtract(Duration(days: i)),
        metadata: {'legacy': true},
      );
      attachments.add(attachment);
    }

    // Modern attachments
    for (int i = 0; i < modernAttachmentCount; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final attachment = Attachment(
        id: 'modern-attachment-$i',
        entryId: entry.id,
        type: AttachmentType.photo,
        name: 'modern_image_$i.jpg',
        path: 'images/${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${entry.id}/modern_image_$i.jpg', // Relative path
        size: 1024 * (i + 1),
        mimeType: 'image/jpeg',
        createdAt: date,
        metadata: {'migrated': true},
      );
      attachments.add(attachment);
    }

    await insertTestData(db, 
      users: [user], 
      journals: [journal], 
      entries: [entry], 
      attachments: attachments
    );
    
    return db;
  }
}