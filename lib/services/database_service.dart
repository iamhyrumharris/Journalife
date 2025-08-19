import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/journal.dart';
import '../models/entry.dart';
import '../models/attachment.dart';
import '../models/sync_config.dart';
import '../models/sync_status.dart';
import '../providers/sync_provider.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'journal.db';
  static const int _databaseVersion = 5;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE journals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        color TEXT,
        icon TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE entries (
        id TEXT PRIMARY KEY,
        journal_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        tags TEXT,
        latitude REAL,
        longitude REAL,
        location_name TEXT,
        FOREIGN KEY (journal_id) REFERENCES journals (id) ON DELETE CASCADE
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
        created_at INTEGER NOT NULL,
        metadata TEXT,
        FOREIGN KEY (entry_id) REFERENCES entries (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_entries_journal_id ON entries(journal_id)',
    );
    await db.execute(
      'CREATE INDEX idx_entries_created_at ON entries(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_attachments_entry_id ON attachments(entry_id)',
    );

    // Create sync-related tables
    await _createSyncTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSyncTables(db);
    }
    if (oldVersion < 3) {
      // For now, we'll just log the upgrade - the database will be recreated fresh
      print('Upgrading database from version $oldVersion to $newVersion');
    }
    if (oldVersion < 4) {
      // Remove rating column - SQLite doesn't support DROP COLUMN directly,
      // so we create a new table and copy data over
      await db.execute('''
        CREATE TABLE entries_new (
          id TEXT PRIMARY KEY,
          journal_id TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          tags TEXT,
          latitude REAL,
          longitude REAL,
          location_name TEXT,
          FOREIGN KEY (journal_id) REFERENCES journals (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute('''
        INSERT INTO entries_new (id, journal_id, title, content, created_at, updated_at, tags, latitude, longitude, location_name)
        SELECT id, journal_id, title, content, created_at, updated_at, tags, latitude, longitude, location_name
        FROM entries
      ''');
      
      await db.execute('DROP TABLE entries');
      await db.execute('ALTER TABLE entries_new RENAME TO entries');
      
      // Recreate indexes
      await db.execute('CREATE INDEX idx_entries_journal_id ON entries(journal_id)');
      await db.execute('CREATE INDEX idx_entries_created_at ON entries(created_at)');
    }
    if (oldVersion < 5) {
      // Remove multi-user features: Drop users table and simplify journals
      await db.execute('DROP TABLE IF EXISTS users');
      
      // Create new journals table without user references
      await db.execute('''
        CREATE TABLE journals_new (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          color TEXT,
          icon TEXT
        )
      ''');
      
      // Copy data from old journals table, excluding user-related fields
      await db.execute('''
        INSERT INTO journals_new (id, name, description, created_at, updated_at, color, icon)
        SELECT id, name, description, created_at, updated_at, color, icon
        FROM journals
      ''');
      
      await db.execute('DROP TABLE journals');
      await db.execute('ALTER TABLE journals_new RENAME TO journals');
    }
  }

  /// Creates sync-related database tables
  Future<void> _createSyncTables(Database db) async {
    // Sync configurations table
    await db.execute('''
      CREATE TABLE sync_configs (
        id TEXT PRIMARY KEY,
        server_url TEXT NOT NULL,
        username TEXT NOT NULL,
        display_name TEXT NOT NULL,
        enabled INTEGER DEFAULT 1,
        last_sync_at TEXT NOT NULL,
        sync_frequency TEXT DEFAULT 'manual',
        sync_on_wifi_only INTEGER DEFAULT 1,
        sync_attachments INTEGER DEFAULT 1,
        encrypt_data INTEGER DEFAULT 0,
        synced_journal_ids TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Secure password storage table (encrypted passwords)
    await db.execute('''
      CREATE TABLE sync_passwords (
        config_id TEXT PRIMARY KEY,
        encrypted_password TEXT NOT NULL,
        FOREIGN KEY (config_id) REFERENCES sync_configs (id) ON DELETE CASCADE
      )
    ''');

    // Sync status tracking table
    await db.execute('''
      CREATE TABLE sync_statuses (
        config_id TEXT PRIMARY KEY,
        state TEXT DEFAULT 'idle',
        last_attempt_at TEXT NOT NULL,
        last_success_at TEXT,
        total_items INTEGER DEFAULT 0,
        completed_items INTEGER DEFAULT 0,
        failed_items INTEGER DEFAULT 0,
        current_item TEXT,
        error_message TEXT,
        bytes_transferred INTEGER DEFAULT 0,
        total_bytes INTEGER DEFAULT 0,
        FOREIGN KEY (config_id) REFERENCES sync_configs (id) ON DELETE CASCADE
      )
    ''');

    // Sync log for tracking sync history
    await db.execute('''
      CREATE TABLE sync_logs (
        id TEXT PRIMARY KEY,
        config_id TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        status TEXT NOT NULL,
        items_synced INTEGER DEFAULT 0,
        bytes_synced INTEGER DEFAULT 0,
        error_message TEXT,
        FOREIGN KEY (config_id) REFERENCES sync_configs (id) ON DELETE CASCADE
      )
    ''');

    // Sync manifest for tracking file versions
    await db.execute('''
      CREATE TABLE sync_manifests (
        config_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        item_type TEXT NOT NULL,
        local_hash TEXT NOT NULL,
        remote_hash TEXT,
        local_modified TEXT NOT NULL,
        remote_modified TEXT,
        sync_status TEXT DEFAULT 'needsSync',
        last_synced TEXT NOT NULL,
        metadata TEXT,
        PRIMARY KEY (config_id, item_id),
        FOREIGN KEY (config_id) REFERENCES sync_configs (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for sync tables
    await db.execute(
      'CREATE INDEX idx_sync_logs_config_id ON sync_logs(config_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_logs_started_at ON sync_logs(started_at)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_manifests_config_id ON sync_manifests(config_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sync_manifests_item_type ON sync_manifests(item_type)',
    );
  }


  // Journal operations
  Future<void> insertJournal(Journal journal) async {
    final db = await database;
    await db.insert(
      'journals',
      journal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Journal?> getJournal(String id) async {
    final db = await database;
    final maps = await db.query('journals', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Journal.fromMap(maps.first) : null;
  }

  Future<List<Journal>> getAllJournals() async {
    final db = await database;
    final maps = await db.query('journals', orderBy: 'created_at DESC');
    return maps.map((map) => Journal.fromMap(map)).toList();
  }

  Future<void> updateJournal(Journal journal) async {
    final db = await database;
    await db.update(
      'journals',
      journal.toMap(),
      where: 'id = ?',
      whereArgs: [journal.id],
    );
  }

  Future<void> deleteJournal(String id) async {
    final db = await database;
    await db.delete('journals', where: 'id = ?', whereArgs: [id]);
  }

  // Entry operations
  Future<void> insertEntry(Entry entry) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final attachment in entry.attachments) {
        await txn.insert(
          'attachments',
          attachment.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<Entry?> getEntry(String id) async {
    final db = await database;
    final entryMaps = await db.query(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (entryMaps.isEmpty) return null;

    final attachmentMaps = await db.query(
      'attachments',
      where: 'entry_id = ?',
      whereArgs: [id],
    );
    final attachments = attachmentMaps
        .map((map) => Attachment.fromMap(map))
        .toList();

    return Entry.fromMap(entryMaps.first, attachments: attachments);
  }

  Future<List<Entry>> getEntriesForJournal(String journalId) async {
    final db = await database;
    final entryMaps = await db.query(
      'entries',
      where: 'journal_id = ?',
      whereArgs: [journalId],
      orderBy: 'created_at DESC',
    );

    final List<Entry> entries = [];
    for (final entryMap in entryMaps) {
      final attachmentMaps = await db.query(
        'attachments',
        where: 'entry_id = ?',
        whereArgs: [entryMap['id']],
      );
      final attachments = attachmentMaps
          .map((map) => Attachment.fromMap(map))
          .toList();
      entries.add(Entry.fromMap(entryMap, attachments: attachments));
    }

    return entries;
  }

  Future<List<Entry>> getEntriesForDateRange({
    required String journalId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final entryMaps = await db.query(
      'entries',
      where: 'journal_id = ? AND created_at >= ? AND created_at <= ?',
      whereArgs: [
        journalId,
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );

    final List<Entry> entries = [];
    for (final entryMap in entryMaps) {
      final attachmentMaps = await db.query(
        'attachments',
        where: 'entry_id = ?',
        whereArgs: [entryMap['id']],
      );
      final attachments = attachmentMaps
          .map((map) => Attachment.fromMap(map))
          .toList();
      entries.add(Entry.fromMap(entryMap, attachments: attachments));
    }

    return entries;
  }

  Future<List<Entry>> searchEntries({
    required String journalId,
    required String query,
  }) async {
    final db = await database;
    final entryMaps = await db.query(
      'entries',
      where:
          'journal_id = ? AND (title LIKE ? OR content LIKE ? OR tags LIKE ?)',
      whereArgs: [journalId, '%$query%', '%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );

    final List<Entry> entries = [];
    for (final entryMap in entryMaps) {
      final attachmentMaps = await db.query(
        'attachments',
        where: 'entry_id = ?',
        whereArgs: [entryMap['id']],
      );
      final attachments = attachmentMaps
          .map((map) => Attachment.fromMap(map))
          .toList();
      entries.add(Entry.fromMap(entryMap, attachments: attachments));
    }

    return entries;
  }

  // Optimized method to get entries with photo attachments for calendar display
  Future<List<Entry>> getEntriesWithPhotosForDateRange({
    required String journalId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    
    // Query entries that have photo attachments within the date range
    final entryMaps = await db.rawQuery('''
      SELECT DISTINCT e.* 
      FROM entries e 
      INNER JOIN attachments a ON e.id = a.entry_id 
      WHERE e.journal_id = ? 
        AND e.created_at >= ? 
        AND e.created_at <= ? 
        AND a.type = 'photo'
      ORDER BY e.created_at DESC
    ''', [
      journalId,
      startDate.millisecondsSinceEpoch,
      endDate.millisecondsSinceEpoch,
    ]);

    final List<Entry> entries = [];
    for (final entryMap in entryMaps) {
      final attachmentMaps = await db.query(
        'attachments',
        where: 'entry_id = ?',
        whereArgs: [entryMap['id']],
      );
      final attachments = attachmentMaps
          .map((map) => Attachment.fromMap(map))
          .toList();
      entries.add(Entry.fromMap(entryMap, attachments: attachments));
    }

    return entries;
  }

  Future<void> updateEntry(Entry entry) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );

      await txn.delete(
        'attachments',
        where: 'entry_id = ?',
        whereArgs: [entry.id],
      );

      for (final attachment in entry.attachments) {
        await txn.insert('attachments', attachment.toMap());
      }
    });
  }

  Future<void> deleteEntry(String id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  // Sync-optimized methods for incremental updates
  Future<List<Entry>> getEntriesModifiedSince({
    required String journalId,
    required DateTime since,
  }) async {
    final db = await database;
    final entryMaps = await db.query(
      'entries',
      where: 'journal_id = ? AND updated_at > ?',
      whereArgs: [journalId, since.millisecondsSinceEpoch],
      orderBy: 'updated_at DESC',
    );

    final List<Entry> entries = [];
    for (final entryMap in entryMaps) {
      final attachmentMaps = await db.query(
        'attachments',
        where: 'entry_id = ?',
        whereArgs: [entryMap['id']],
      );
      final attachments = attachmentMaps
          .map((map) => Attachment.fromMap(map))
          .toList();
      entries.add(Entry.fromMap(entryMap, attachments: attachments));
    }

    return entries;
  }

  Future<List<Journal>> getJournalsModifiedSince(DateTime since) async {
    final db = await database;
    final maps = await db.query(
      'journals',
      where: 'updated_at > ?',
      whereArgs: [since.millisecondsSinceEpoch],
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => Journal.fromMap(map)).toList();
  }

  // Attachment operations
  Future<List<Attachment>> getAttachmentsForEntry(String entryId) async {
    final db = await database;
    final maps = await db.query(
      'attachments',
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    return maps.map((map) => Attachment.fromMap(map)).toList();
  }

  Future<List<Attachment>> getAllAttachmentsForJournal(String journalId) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT a.* FROM attachments a
      JOIN entries e ON a.entry_id = e.id
      WHERE e.journal_id = ?
      ORDER BY a.created_at DESC
    ''',
      [journalId],
    );
    return maps.map((map) => Attachment.fromMap(map)).toList();
  }

  // Utility methods
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  // Sync configuration operations
  Future<void> createSyncConfiguration(SyncConfig config) async {
    final db = await database;
    await db.insert('sync_configs', {
      'id': config.id,
      'server_url': config.serverUrl,
      'username': config.username,
      'display_name': config.displayName,
      'enabled': config.enabled ? 1 : 0,
      'last_sync_at': config.lastSyncAt.toIso8601String(),
      'sync_frequency': config.syncFrequency.name,
      'sync_on_wifi_only': config.syncOnWifiOnly ? 1 : 0,
      'sync_attachments': config.syncAttachments ? 1 : 0,
      'encrypt_data': config.encryptData ? 1 : 0,
      'synced_journal_ids': config.syncedJournalIds.join(','),
      'created_at': config.createdAt.toIso8601String(),
      'updated_at': config.updatedAt.toIso8601String(),
    });
  }

  Future<List<SyncConfig>> getSyncConfigurations() async {
    final db = await database;
    final maps = await db.query('sync_configs', orderBy: 'created_at DESC');
    return maps.map((map) => SyncConfig.fromMap(map)).toList();
  }

  Future<SyncConfig?> getSyncConfiguration(String configId) async {
    final db = await database;
    final maps = await db.query(
      'sync_configs',
      where: 'id = ?',
      whereArgs: [configId],
    );
    if (maps.isEmpty) return null;
    return SyncConfig.fromMap(maps.first);
  }

  Future<void> updateSyncConfiguration(SyncConfig config) async {
    final db = await database;
    await db.update(
      'sync_configs',
      {
        'server_url': config.serverUrl,
        'username': config.username,
        'display_name': config.displayName,
        'enabled': config.enabled ? 1 : 0,
        'last_sync_at': config.lastSyncAt.toIso8601String(),
        'sync_frequency': config.syncFrequency.name,
        'sync_on_wifi_only': config.syncOnWifiOnly ? 1 : 0,
        'sync_attachments': config.syncAttachments ? 1 : 0,
        'encrypt_data': config.encryptData ? 1 : 0,
        'synced_journal_ids': config.syncedJournalIds.join(','),
        'updated_at': config.updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [config.id],
    );
  }

  Future<void> deleteSyncConfiguration(String configId) async {
    final db = await database;
    await db.delete('sync_configs', where: 'id = ?', whereArgs: [configId]);
  }

  // Secure password storage operations
  Future<void> storeSyncPassword(String configId, String password) async {
    final db = await database;
    // In a real implementation, password should be encrypted
    // For now, storing as-is (THIS IS NOT SECURE - needs proper encryption)
    await db.insert('sync_passwords', {
      'config_id': configId,
      'encrypted_password': password, // TODO: Encrypt this
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSyncPassword(String configId) async {
    final db = await database;
    final maps = await db.query(
      'sync_passwords',
      where: 'config_id = ?',
      whereArgs: [configId],
    );
    if (maps.isEmpty) return null;
    // TODO: Decrypt the password
    return maps.first['encrypted_password'] as String;
  }

  Future<void> deleteSyncPassword(String configId) async {
    final db = await database;
    await db.delete(
      'sync_passwords',
      where: 'config_id = ?',
      whereArgs: [configId],
    );
  }

  // Sync status operations
  Future<void> saveSyncStatus(SyncStatus status) async {
    final db = await database;
    await db.insert('sync_statuses', {
      'config_id': status.configId,
      'state': status.state.name,
      'last_attempt_at': status.lastAttemptAt.toIso8601String(),
      'last_success_at': status.lastSuccessAt?.toIso8601String(),
      'total_items': status.totalItems,
      'completed_items': status.completedItems,
      'failed_items': status.failedItems,
      'current_item': status.currentItem,
      'error_message': status.errorMessage,
      'bytes_transferred': status.bytesTransferred,
      'total_bytes': status.totalBytes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SyncStatus>> getSyncStatuses() async {
    final db = await database;
    final maps = await db.query('sync_statuses');
    return maps.map((map) => _syncStatusFromMap(map)).toList();
  }

  Future<SyncStatus?> getSyncStatus(String configId) async {
    final db = await database;
    final maps = await db.query(
      'sync_statuses',
      where: 'config_id = ?',
      whereArgs: [configId],
    );
    if (maps.isEmpty) return null;
    return _syncStatusFromMap(maps.first);
  }

  SyncStatus _syncStatusFromMap(Map<String, dynamic> map) {
    return SyncStatus(
      configId: map['config_id'] as String,
      state: SyncState.values.firstWhere(
        (e) => e.name == map['state'],
        orElse: () => SyncState.idle,
      ),
      lastAttemptAt: DateTime.parse(map['last_attempt_at'] as String),
      lastSuccessAt: map['last_success_at'] != null
          ? DateTime.parse(map['last_success_at'] as String)
          : null,
      totalItems: map['total_items'] as int? ?? 0,
      completedItems: map['completed_items'] as int? ?? 0,
      failedItems: map['failed_items'] as int? ?? 0,
      currentItem: map['current_item'] as String?,
      errorMessage: map['error_message'] as String?,
      bytesTransferred: map['bytes_transferred'] as int? ?? 0,
      totalBytes: map['total_bytes'] as int? ?? 0,
    );
  }

  // Sync statistics operations
  Future<SyncStatistics> getSyncStatistics(String configId) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as total_syncs,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as successful_syncs,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_syncs,
        MAX(CASE WHEN status = 'completed' THEN completed_at END) as last_successful_sync,
        MAX(CASE WHEN status = 'failed' THEN completed_at END) as last_failed_sync,
        COALESCE(SUM(items_synced), 0) as total_items_synced,
        COALESCE(SUM(bytes_synced), 0) as total_bytes_synced
      FROM sync_logs 
      WHERE config_id = ?
    ''',
      [configId],
    );

    if (maps.isEmpty) return SyncStatistics.empty(configId);

    final map = maps.first;
    return SyncStatistics(
      configId: configId,
      totalSyncs: map['total_syncs'] as int? ?? 0,
      successfulSyncs: map['successful_syncs'] as int? ?? 0,
      failedSyncs: map['failed_syncs'] as int? ?? 0,
      lastSuccessfulSync: map['last_successful_sync'] != null
          ? DateTime.parse(map['last_successful_sync'] as String)
          : null,
      lastFailedSync: map['last_failed_sync'] != null
          ? DateTime.parse(map['last_failed_sync'] as String)
          : null,
      totalItemsSynced: map['total_items_synced'] as int? ?? 0,
      totalBytesSynced: map['total_bytes_synced'] as int? ?? 0,
    );
  }

  Future<void> clearSyncHistory(String configId) async {
    final db = await database;
    await db.delete('sync_logs', where: 'config_id = ?', whereArgs: [configId]);
  }

  // Helper methods for sync operations

  Future<void> createOrUpdateJournal(Journal journal) async {
    final db = await database;
    await db.insert(
      'journals',
      journal.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
