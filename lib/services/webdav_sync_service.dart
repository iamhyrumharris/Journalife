import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import '../models/sync_config.dart';
import '../models/sync_status.dart';
import '../models/sync_manifest.dart';
import '../models/journal.dart';
import '../models/entry.dart';
import '../models/attachment.dart';
import 'database_service.dart';
import 'local_file_storage_service.dart';

/// Core service for WebDAV synchronization operations
class WebDAVSyncService {
  static final WebDAVSyncService _instance = WebDAVSyncService._internal();
  factory WebDAVSyncService() => _instance;
  WebDAVSyncService._internal();

  late webdav.Client _client;
  SyncConfig? _currentConfig;
  final DatabaseService _databaseService = DatabaseService();
  final LocalFileStorageService _fileService = LocalFileStorageService();
  bool _directoriesCreated = false; // Track if directories were already created

  /// Initializes the WebDAV client with configuration
  Future<void> initialize(SyncConfig config, String password) async {
    _currentConfig = config;
    _directoriesCreated = false; // Reset flag for new config

    _client = webdav.newClient(
      config.serverUrl,
      user: config.username,
      password: password,
      debug: false,
    );

    try {
      // Test connection and create base directory structure (only once per config)
      await _ensureDirectoryStructure();
    } catch (e) {
      throw SyncException('Failed to initialize WebDAV connection: $e');
    }
  }

  /// Ensures the required directory structure exists on the server with date-based organization
  Future<void> _ensureDirectoryStructure() async {
    if (_currentConfig == null) throw SyncException('Not initialized');

    // Skip if directories were already created for this config
    if (_directoriesCreated) {
      debugPrint('📁 Directories already created, skipping...');
      return;
    }

    debugPrint('Creating organized WebDAV directory structure...');
    final directories = _currentConfig!.getRequiredDirectories();

    for (final dir in directories) {
      try {
        await _client.mkdir(dir);
        debugPrint('✓ Directory created/verified: $dir');
      } catch (e) {
        // Directory might already exist, that's okay
        debugPrint('Directory creation note for $dir: $e');
      }
    }

    // Create current year/month directories for better organization
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');

    final dateDirectories = [
      '${_currentConfig!.basePath}/entries/$year',
      '${_currentConfig!.basePath}/entries/$year/$month',
      '${_currentConfig!.basePath}/attachments/$year',
      '${_currentConfig!.basePath}/attachments/$year/$month',
      '${_currentConfig!.basePath}/photos/$year',
      '${_currentConfig!.basePath}/photos/$year/$month',
      '${_currentConfig!.basePath}/audio/$year',
      '${_currentConfig!.basePath}/audio/$year/$month',
    ];

    for (final dir in dateDirectories) {
      try {
        await _client.mkdir(dir);
        debugPrint('✓ Date directory created/verified: $dir');
      } catch (e) {
        debugPrint('Date directory creation note for $dir: $e');
      }
    }

    debugPrint('✅ WebDAV directory structure complete');
    _directoriesCreated = true; // Mark directories as created
  }

  /// Tests the connection to the WebDAV server with comprehensive validation
  Future<bool> testConnection(SyncConfig config, String password) async {
    try {
      debugPrint('Testing WebDAV connection to: ${config.serverUrl}');

      final testClient = webdav.newClient(
        config.serverUrl,
        user: config.username,
        password: password,
        debug: true, // Enable debug for better error reporting
      );

      // Step 1: Try basic ping
      debugPrint('Step 1: Ping server...');
      await testClient.ping();
      debugPrint('✓ Server ping successful');

      // Step 2: Try to create test directory structure
      final testBasePath = config.basePath;
      debugPrint('Step 2: Creating test directory: $testBasePath');

      try {
        await testClient.mkdir(testBasePath);
        debugPrint('✓ Test directory created or already exists');
      } catch (e) {
        // Directory might already exist, that's okay
        debugPrint('Directory creation note: $e');
      }

      // Step 3: Test write operation
      debugPrint('Step 3: Testing write operation...');
      final testFilePath = '$testBasePath/connection_test.txt';
      final testContent =
          'WebDAV connection test - ${DateTime.now().toIso8601String()}';
      await testClient.write(
        testFilePath,
        Uint8List.fromList(utf8.encode(testContent)),
      );
      debugPrint('✓ Test file written successfully');

      // Step 4: Test read operation
      debugPrint('Step 4: Testing read operation...');
      final readBytes = await testClient.read(testFilePath);
      final readContent = utf8.decode(readBytes);
      debugPrint(
        '✓ Test file read successfully: ${readContent.substring(0, 20)}...',
      );

      // Step 5: Clean up test file
      debugPrint('Step 5: Cleaning up test file...');
      try {
        await testClient.remove(testFilePath);
        debugPrint('✓ Test file cleaned up');
      } catch (e) {
        debugPrint('Cleanup note (non-critical): $e');
      }

      debugPrint('🎉 WebDAV connection test completed successfully!');
      return true;
    } catch (e) {
      debugPrint('❌ WebDAV connection test failed at: $e');
      debugPrint('Server URL: ${config.serverUrl}');
      debugPrint('Username: ${config.username}');
      debugPrint('Base Path: ${config.basePath}');

      // Log specific error types for better debugging
      if (e.toString().contains('401')) {
        debugPrint(
          '💡 Error suggests authentication failure - check username/password',
        );
      } else if (e.toString().contains('403')) {
        debugPrint(
          '💡 Error suggests permission denied - check user permissions',
        );
      } else if (e.toString().contains('404')) {
        debugPrint(
          '💡 Error suggests server path not found - check server URL',
        );
      } else if (e.toString().contains('timeout')) {
        debugPrint(
          '💡 Error suggests network timeout - check network connectivity',
        );
      }

      return false;
    }
  }

  /// Performs a full bidirectional sync
  Future<SyncStatus> performSync({
    void Function(SyncStatus)? onStatusUpdate,
  }) async {
    if (_currentConfig == null) {
      throw SyncException('WebDAV client not initialized');
    }

    var status = SyncStatus(
      configId: _currentConfig!.id,
      state: SyncState.checking,
      lastAttemptAt: DateTime.now(),
    );
    onStatusUpdate?.call(status);

    try {
      debugPrint('🔧 Sync Config Debug: ${_currentConfig!.displayName}');
      debugPrint('🔧 Synced Journal IDs: ${_currentConfig!.syncedJournalIds}');

      // Load local manifest
      final localManifest = await _loadLocalManifest();

      // Download remote manifest
      final remoteManifest = await _downloadRemoteManifest();

      // Calculate what needs to be synced
      final syncPlan = _calculateSyncPlan(localManifest, remoteManifest);

      status = status.copyWith(
        state: SyncState.syncing,
        totalItems: syncPlan.totalItems,
      );
      onStatusUpdate?.call(status);

      // Execute sync plan
      var completedItems = 0;

      // Upload local changes
      debugPrint(
        'Starting upload of ${syncPlan.itemsToUpload.length} items...',
      );
      for (final item in syncPlan.itemsToUpload) {
        status = status.copyWith(
          state: SyncState.uploading,
          currentItem: item.id,
          completedItems: completedItems,
        );
        onStatusUpdate?.call(status);

        debugPrint('Uploading ${item.type.name}: ${item.id}');
        try {
          await _uploadItem(item);
          completedItems++;
        } catch (e) {
          debugPrint('❌ Failed to upload ${item.type.name} ${item.id}: $e');
          rethrow;
        }

        status = status.copyWith(completedItems: completedItems);
        onStatusUpdate?.call(status);
      }

      // Download remote changes
      for (final item in syncPlan.itemsToDownload) {
        status = status.copyWith(
          state: SyncState.downloading,
          currentItem: item.id,
          completedItems: completedItems,
        );
        onStatusUpdate?.call(status);

        await _downloadItem(item);
        completedItems++;

        status = status.copyWith(completedItems: completedItems);
        onStatusUpdate?.call(status);
      }

      // Handle conflicts
      if (syncPlan.conflictItems.isNotEmpty) {
        status = status.copyWith(
          state: SyncState.resolving,
          currentItem: 'conflicts',
        );
        onStatusUpdate?.call(status);

        // For now, use last-writer-wins strategy
        for (final conflict in syncPlan.conflictItems) {
          await _resolveConflict(conflict);
          completedItems++;

          status = status.copyWith(completedItems: completedItems);
          onStatusUpdate?.call(status);
        }
      }

      // Upload updated manifest
      debugPrint('🔄 Merging manifests...');
      final updatedManifest = _mergeManifests(
        localManifest,
        remoteManifest,
        syncPlan,
      );
      debugPrint('📤 Uploading manifest to server...');
      await _uploadManifest(updatedManifest);
      debugPrint('💾 Saving manifest locally...');
      await _saveLocalManifest(updatedManifest);

      // Complete
      status = status.copyWith(
        state: SyncState.completed,
        lastSuccessAt: DateTime.now(),
        currentItem: null,
      );
      onStatusUpdate?.call(status);

      return status;
    } catch (e) {
      debugPrint('❌ Sync failed with error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      status = status.copyWith(
        state: SyncState.failed,
        errorMessage: e.toString(),
      );
      onStatusUpdate?.call(status);
      rethrow;
    }
  }

  /// Calculates what items need to be synced
  SyncPlan _calculateSyncPlan(SyncManifest local, SyncManifest? remote) {
    final itemsToUpload = <SyncItem>[];
    final itemsToDownload = <SyncItem>[];
    final conflictItems = <SyncConflict>[];

    // Check local items
    for (final localItem in local.items.values) {
      final remoteItem = remote?.getItem(localItem.id);

      if (remoteItem == null) {
        // New local item - upload it
        itemsToUpload.add(localItem);
      } else {
        // Item exists in both - check for conflicts
        final remoteModified = remoteItem.remoteModified;
        if (remoteModified == null) {
          // Remote item has no modification date, treat as new upload
          itemsToUpload.add(localItem);
        } else if (localItem.localModified.isAfter(remoteModified) &&
            remoteModified.isAfter(localItem.lastSynced)) {
          // Conflict: both sides modified since last sync
          conflictItems.add(
            SyncConflict(
              item: localItem,
              localItem: localItem,
              remoteItem: remoteItem,
              type: ConflictType.bothModified,
            ),
          );
        } else if (localItem.localModified.isAfter(remoteModified)) {
          // Local is newer - upload
          itemsToUpload.add(localItem);
        } else if (remoteModified.isAfter(localItem.localModified)) {
          // Remote is newer - download
          itemsToDownload.add(remoteItem);
        }
      }
    }

    // Check for remote items not in local
    if (remote != null) {
      for (final remoteItem in remote.items.values) {
        if (local.getItem(remoteItem.id) == null) {
          // New remote item - download it
          itemsToDownload.add(remoteItem);
        }
      }
    }

    return SyncPlan(
      itemsToUpload: itemsToUpload,
      itemsToDownload: itemsToDownload,
      conflictItems: conflictItems,
    );
  }

  /// Uploads an item to the WebDAV server
  Future<void> _uploadItem(SyncItem item) async {
    switch (item.type) {
      case SyncItemType.journal:
        await _uploadJournal(item);
        break;
      case SyncItemType.entry:
        await _uploadEntry(item);
        break;
      case SyncItemType.attachment:
        await _uploadAttachment(item);
        break;
      default:
        throw SyncException('Unknown item type: ${item.type}');
    }
  }

  /// Downloads an item from the WebDAV server
  Future<void> _downloadItem(SyncItem item) async {
    switch (item.type) {
      case SyncItemType.journal:
        await _downloadJournal(item);
        break;
      case SyncItemType.entry:
        await _downloadEntry(item);
        break;
      case SyncItemType.attachment:
        await _downloadAttachment(item);
        break;
      default:
        throw SyncException('Unknown item type: ${item.type}');
    }
  }

  /// Uploads a journal to the WebDAV server
  Future<void> _uploadJournal(SyncItem item) async {
    final journal = await _databaseService.getJournal(item.id);
    if (journal == null) throw SyncException('Journal not found: ${item.id}');

    final remotePath = '${_currentConfig!.getJournalPath(journal.id)}.json';
    final jsonContent = jsonEncode(journal.toJson());

    debugPrint('Uploading journal: ${journal.name} to $remotePath');
    await _client.write(remotePath, utf8.encode(jsonContent));
    debugPrint('✓ Journal uploaded successfully: ${journal.name}');
  }

  /// Downloads a journal from the WebDAV server
  Future<void> _downloadJournal(SyncItem item) async {
    final remotePath = '${_currentConfig!.getJournalPath(item.id)}.json';
    final bytes = await _client.read(remotePath);
    final jsonContent = utf8.decode(bytes);
    final journalData = jsonDecode(jsonContent) as Map<String, dynamic>;
    final journal = Journal.fromJson(journalData);

    // Save to local database
    await _databaseService.insertJournal(journal);
  }

  /// Uploads an entry to the WebDAV server
  Future<void> _uploadEntry(SyncItem item) async {
    final entry = await _databaseService.getEntry(item.id);
    if (entry == null) throw SyncException('Entry not found: ${item.id}');

    final year = entry.createdAt.year.toString();
    final month = entry.createdAt.month.toString().padLeft(2, '0');
    final remotePath =
        '${_currentConfig!.basePath}/entries/$year/$month/${entry.id}.json';
    final jsonContent = jsonEncode(entry.toJson());

    debugPrint('Uploading entry: ${entry.title} to $remotePath');
    await _client.write(remotePath, utf8.encode(jsonContent));
    debugPrint('✓ Entry uploaded successfully: ${entry.title}');
  }

  /// Downloads an entry from the WebDAV server
  Future<void> _downloadEntry(SyncItem item) async {
    // Use the path stored in the item
    final remotePath = item.path;
    final bytes = await _client.read(remotePath);
    final jsonContent = utf8.decode(bytes);
    final entryData = jsonDecode(jsonContent) as Map<String, dynamic>;
    final entry = Entry.fromJson(entryData);

    // Save to local database
    await _databaseService.insertEntry(entry);
  }

  /// Uploads an attachment to the WebDAV server
  Future<void> _uploadAttachment(SyncItem item) async {
    final relativePath = item.metadata?['relativePath'] as String?;
    if (relativePath == null) {
      throw SyncException('Missing relative path for attachment: ${item.id}');
    }

    // Get the local file using the file storage service
    final localFile = await _fileService.getFile(relativePath);
    if (localFile == null || !await localFile.exists()) {
      throw SyncException('Attachment file not found: $relativePath');
    }

    final remotePath = _currentConfig!.getAttachmentPath(relativePath);
    final bytes = await localFile.readAsBytes();

    debugPrint('Uploading attachment: $relativePath to $remotePath');
    await _client.write(remotePath, bytes);
    debugPrint('✓ Attachment uploaded successfully: $relativePath');
  }

  /// Downloads an attachment from the WebDAV server
  Future<void> _downloadAttachment(SyncItem item) async {
    final relativePath = item.metadata?['relativePath'] as String?;
    if (relativePath == null) {
      throw SyncException('Missing relative path for attachment: ${item.id}');
    }

    final remotePath = _currentConfig!.getAttachmentPath(relativePath);
    final localFile = await _fileService.getFile(relativePath);

    if (localFile == null) {
      throw SyncException('Could not create local file for: $relativePath');
    }

    final bytes = await _client.read(remotePath);
    await localFile.writeAsBytes(bytes);
  }

  /// Resolves a sync conflict using last-writer-wins strategy
  Future<void> _resolveConflict(SyncConflict conflict) async {
    // For now, implement simple last-writer-wins
    if (conflict.remoteItem.remoteModified!.isAfter(
      conflict.localItem.localModified,
    )) {
      // Remote wins - download the remote version
      await _downloadItem(conflict.remoteItem);
    } else {
      // Local wins - upload the local version
      await _uploadItem(conflict.localItem);
    }
  }

  /// Loads the local sync manifest and updates it with new/modified items
  Future<SyncManifest> _loadLocalManifest() async {
    SyncManifest? existingManifest;

    try {
      final manifestFile = await _getLocalManifestFile();

      if (await manifestFile.exists()) {
        debugPrint('📋 Loading existing manifest from: ${manifestFile.path}');
        final jsonContent = await manifestFile.readAsString();
        final manifestData = jsonDecode(jsonContent) as Map<String, dynamic>;
        existingManifest = SyncManifest.fromJson(manifestData);
        debugPrint(
          '📋 Loaded manifest with ${existingManifest.items.length} items',
        );
      } else {
        debugPrint('📋 No existing manifest found, will generate new one');
      }
    } catch (e) {
      debugPrint('Failed to load existing manifest: $e');
    }

    // Always update the manifest with new/modified items since last sync
    return await _updateManifestWithNewItems(existingManifest);
  }

  /// Generates initial manifest by scanning the local database
  Future<SyncManifest> _generateInitialManifest() async {
    debugPrint('Generating initial sync manifest from database...');

    var manifest = SyncManifest(
      configId: _currentConfig!.id,
      lastUpdated: DateTime.now(),
    );

    try {
      final databaseService = DatabaseService();

      // Get all journals that are configured to sync
      final allJournals = await databaseService.getJournalsForUser(
        'default-user',
      );
      final syncedJournals = allJournals
          .where(
            (journal) => _currentConfig!.syncedJournalIds.contains(journal.id),
          )
          .toList();

      debugPrint(
        'Found ${syncedJournals.length} journals to sync: ${syncedJournals.map((j) => j.name).join(', ')}',
      );
      debugPrint(
        'Configured journal IDs for sync: ${_currentConfig!.syncedJournalIds}',
      );
      debugPrint(
        'All available journals: ${allJournals.map((j) => '${j.name} (${j.id})').join(', ')}',
      );

      for (final journal in syncedJournals) {
        // Add journal to manifest
        final journalItem = SyncItem(
          id: journal.id,
          type: SyncItemType.journal,
          localModified: journal.updatedAt,
          syncStatus: SyncItemStatus.needsSync,
          path: '${_currentConfig!.basePath}/journals/${journal.id}.json',
          localHash: await _calculateContentHash(jsonEncode(journal.toJson())),
          lastSynced: DateTime.now(),
        );
        manifest = manifest.addItem(journalItem);

        // Get all entries for this journal
        final entries = await databaseService.getEntriesForJournal(journal.id);
        debugPrint('Journal "${journal.name}" has ${entries.length} entries');

        for (final entry in entries) {
          // Add entry to manifest
          final year = entry.createdAt.year.toString();
          final month = entry.createdAt.month.toString().padLeft(2, '0');
          final entryPath =
              '${_currentConfig!.basePath}/entries/$year/$month/${entry.id}.json';

          final entryItem = SyncItem(
            id: entry.id,
            type: SyncItemType.entry,
            localModified: entry.updatedAt,
            syncStatus: SyncItemStatus.needsSync,
            path: entryPath,
            localHash: await _calculateContentHash(jsonEncode(entry.toJson())),
            lastSynced: DateTime.now(),
            metadata: {'parentId': journal.id},
          );
          manifest = manifest.addItem(entryItem);

          // Add attachments to manifest
          for (final attachment in entry.attachments) {
            if (attachment.path.isNotEmpty) {
              final attachmentItem = SyncItem(
                id: attachment.id,
                type: SyncItemType.attachment,
                localModified: attachment.createdAt,
                syncStatus: SyncItemStatus.needsSync,
                path: _currentConfig!.getAttachmentPath(attachment.path),
                localHash: await _calculateAttachmentHash(attachment),
                lastSynced: DateTime.now(),
                metadata: {
                  'parentId': entry.id,
                  'relativePath': attachment.path,
                },
              );
              manifest = manifest.addItem(attachmentItem);
            }
          }
        }
      }

      final totalItems = manifest.items.length;
      debugPrint('Generated initial manifest with $totalItems items');

      // Save the generated manifest
      await _saveLocalManifest(manifest);

      return manifest;
    } catch (e) {
      debugPrint('Failed to generate initial manifest: $e');
      // Return empty manifest as fallback
      return SyncManifest(
        configId: _currentConfig!.id,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Updates manifest with new/modified items since last sync (incremental approach)
  Future<SyncManifest> _updateManifestWithNewItems(
    SyncManifest? existingManifest,
  ) async {
    debugPrint('🔄 Updating manifest with new/modified items...');

    // Start with existing manifest or create new one
    var manifest =
        existingManifest ??
        SyncManifest(configId: _currentConfig!.id, lastUpdated: DateTime.now());

    try {
      final databaseService = DatabaseService();

      // Get the timestamp from the last update (or use epoch for first sync)
      final lastSyncTime =
          existingManifest?.lastUpdated ??
          DateTime.fromMillisecondsSinceEpoch(0);
      debugPrint('🕒 Checking for changes since: $lastSyncTime');

      // Get journals that are configured to sync
      final allJournals = await databaseService.getJournalsForUser(
        'default-user',
      );
      final syncedJournals = allJournals
          .where(
            (journal) => _currentConfig!.syncedJournalIds.contains(journal.id),
          )
          .toList();

      debugPrint(
        '📚 Scanning ${syncedJournals.length} journals for changes...',
      );

      for (final journal in syncedJournals) {
        // Check if journal was modified since last sync
        if (journal.updatedAt.isAfter(lastSyncTime)) {
          debugPrint(
            '📓 Journal "${journal.name}" was modified, updating manifest',
          );
          final journalItem = SyncItem(
            id: journal.id,
            type: SyncItemType.journal,
            localModified: journal.updatedAt,
            syncStatus: SyncItemStatus.needsSync,
            path: '${_currentConfig!.basePath}/journals/${journal.id}.json',
            localHash: await _calculateContentHash(
              jsonEncode(journal.toJson()),
            ),
            lastSynced:
                existingManifest?.getItem(journal.id)?.lastSynced ??
                DateTime.now(),
          );
          manifest = manifest.addItem(journalItem);
        }

        // Get entries modified since last sync (much more efficient than loading all entries)
        final modifiedEntries = await databaseService.getEntriesModifiedSince(
          journalId: journal.id,
          since: lastSyncTime,
        );

        debugPrint(
          '📝 Found ${modifiedEntries.length} modified entries in "${journal.name}"',
        );

        for (final entry in modifiedEntries) {
          // Add entry to manifest
          final year = entry.createdAt.year.toString();
          final month = entry.createdAt.month.toString().padLeft(2, '0');
          final entryPath =
              '${_currentConfig!.basePath}/entries/$year/$month/${entry.id}.json';

          final entryItem = SyncItem(
            id: entry.id,
            type: SyncItemType.entry,
            localModified: entry.updatedAt,
            syncStatus: SyncItemStatus.needsSync,
            path: entryPath,
            localHash: await _calculateContentHash(jsonEncode(entry.toJson())),
            lastSynced:
                existingManifest?.getItem(entry.id)?.lastSynced ??
                DateTime.now(),
            metadata: {'parentId': journal.id},
          );
          manifest = manifest.addItem(entryItem);

          // Add attachments to manifest
          for (final attachment in entry.attachments) {
            if (attachment.path.isNotEmpty) {
              // Only add attachment if it's new or the entry was modified
              final existingAttachmentItem = existingManifest?.getItem(
                attachment.id,
              );
              if (existingAttachmentItem == null ||
                  entry.updatedAt.isAfter(lastSyncTime)) {
                final attachmentItem = SyncItem(
                  id: attachment.id,
                  type: SyncItemType.attachment,
                  localModified: attachment.createdAt,
                  syncStatus: SyncItemStatus.needsSync,
                  path: _currentConfig!.getAttachmentPath(attachment.path),
                  localHash: await _calculateAttachmentHash(attachment),
                  lastSynced:
                      existingAttachmentItem?.lastSynced ?? DateTime.now(),
                  metadata: {
                    'parentId': entry.id,
                    'relativePath': attachment.path,
                  },
                );
                manifest = manifest.addItem(attachmentItem);
                debugPrint(
                  '📎 Added attachment: ${attachment.name} (${attachment.path})',
                );
              }
            }
          }
        }
      }

      // Update manifest timestamp
      manifest = manifest.copyWith(lastUpdated: DateTime.now());

      final totalItems = manifest.items.length;
      final newItemsCount = manifest.items.values
          .where((item) => item.syncStatus == SyncItemStatus.needsSync)
          .length;

      debugPrint(
        '✅ Manifest updated: $totalItems total items, $newItemsCount need sync',
      );

      return manifest;
    } catch (e) {
      debugPrint('❌ Failed to update manifest: $e');
      // Return existing manifest or empty one as fallback
      return existingManifest ??
          SyncManifest(
            configId: _currentConfig!.id,
            lastUpdated: DateTime.now(),
          );
    }
  }

  /// Calculates content hash for sync item
  Future<String> _calculateContentHash(String content) async {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Calculates hash for attachment file
  Future<String> _calculateAttachmentHash(Attachment attachment) async {
    try {
      // Try to read the local file and calculate hash
      final localStorageService = LocalFileStorageService();
      final file = await localStorageService.getFile(attachment.path);
      if (file != null && await file.exists()) {
        final fileBytes = await file.readAsBytes();
        final digest = sha256.convert(fileBytes);
        return digest.toString();
      }

      // Fallback to metadata-based hash if file not found
      final metadataJson = jsonEncode({
        'id': attachment.id,
        'name': attachment.name,
        'size': attachment.size,
        'mimeType': attachment.mimeType,
        'createdAt': attachment.createdAt.toIso8601String(),
      });
      return await _calculateContentHash(metadataJson);
    } catch (e) {
      debugPrint(
        'Failed to calculate attachment hash for ${attachment.name}: $e',
      );
      // Fallback hash based on metadata
      final metadataJson = jsonEncode({
        'id': attachment.id,
        'name': attachment.name,
        'size': attachment.size ?? 0,
      });
      return await _calculateContentHash(metadataJson);
    }
  }

  /// Downloads the remote sync manifest
  Future<SyncManifest?> _downloadRemoteManifest() async {
    try {
      final remotePath = '${_currentConfig!.basePath}/manifest.json';
      final bytes = await _client.read(remotePath);
      final jsonContent = utf8.decode(bytes);
      final manifestData = jsonDecode(jsonContent) as Map<String, dynamic>;
      return SyncManifest.fromJson(manifestData);
    } catch (e) {
      // Manifest doesn't exist yet - that's okay for first sync
      return null;
    }
  }

  /// Uploads the sync manifest to the WebDAV server
  Future<void> _uploadManifest(SyncManifest manifest) async {
    try {
      final remotePath = '${_currentConfig!.basePath}/manifest.json';
      final jsonContent = jsonEncode(manifest.toJson());
      debugPrint(
        '📤 Uploading manifest to: $remotePath (${jsonContent.length} bytes)',
      );
      await _client.write(remotePath, utf8.encode(jsonContent));
      debugPrint('✅ Manifest uploaded successfully');
    } catch (e) {
      debugPrint('❌ Failed to upload manifest: $e');
      throw SyncException('Failed to upload manifest to server: $e');
    }
  }

  /// Saves the sync manifest locally
  Future<void> _saveLocalManifest(SyncManifest manifest) async {
    try {
      final manifestFile = await _getLocalManifestFile();
      final jsonContent = jsonEncode(manifest.toJson());
      await manifestFile.writeAsString(jsonContent);
    } catch (e) {
      debugPrint('Failed to save local manifest: $e');
      throw SyncException('Failed to save local manifest: $e');
    }
  }

  /// Merges local and remote manifests after sync
  SyncManifest _mergeManifests(
    SyncManifest local,
    SyncManifest? remote,
    SyncPlan plan,
  ) {
    var merged = local.copyWith(lastUpdated: DateTime.now());

    // If no remote manifest, just update local items that were uploaded
    if (remote == null) {
      for (final item in plan.itemsToUpload) {
        merged = merged.addItem(
          item.copyWith(
            syncStatus: SyncItemStatus.synced,
            lastSynced: DateTime.now(),
          ),
        );
      }
      return merged;
    }

    // Merge remote items into local manifest
    for (final remoteItem in remote.items.values) {
      final localItem = merged.getItem(remoteItem.id);

      if (localItem == null) {
        // Remote item doesn't exist locally, add it
        merged = merged.addItem(
          remoteItem.copyWith(syncStatus: SyncItemStatus.synced),
        );
      } else if (plan.itemsToUpload.contains(localItem)) {
        // Item was uploaded, mark as synced
        merged = merged.addItem(
          localItem.copyWith(
            syncStatus: SyncItemStatus.synced,
            lastSynced: DateTime.now(),
            remoteHash: localItem.localHash,
            remoteModified: localItem.localModified,
          ),
        );
      } else if (plan.itemsToDownload.contains(remoteItem)) {
        // Item was downloaded, update with remote info
        merged = merged.addItem(
          remoteItem.copyWith(
            syncStatus: SyncItemStatus.synced,
            lastSynced: DateTime.now(),
          ),
        );
      }
    }

    return merged;
  }

  /// Clears the local manifest to force regeneration
  Future<void> clearLocalManifest() async {
    try {
      final manifestFile = await _getLocalManifestFile();
      if (await manifestFile.exists()) {
        await manifestFile.delete();
        debugPrint('🗑️ Cleared local manifest file');
      }
    } catch (e) {
      debugPrint('Failed to clear local manifest: $e');
    }
  }

  /// Gets the local file path for the sync manifest
  Future<File> _getLocalManifestFile() async {
    final appDir = await getApplicationSupportDirectory();
    final syncDir = Directory(path.join(appDir.path, 'sync'));

    if (!await syncDir.exists()) {
      await syncDir.create(recursive: true);
    }

    final manifestPath = path.join(
      syncDir.path,
      '${_currentConfig!.id}_manifest.json',
    );
    return File(manifestPath);
  }
}

/// Plan for what needs to be synchronized
class SyncPlan {
  final List<SyncItem> itemsToUpload;
  final List<SyncItem> itemsToDownload;
  final List<SyncConflict> conflictItems;

  const SyncPlan({
    this.itemsToUpload = const [],
    this.itemsToDownload = const [],
    this.conflictItems = const [],
  });

  int get totalItems =>
      itemsToUpload.length + itemsToDownload.length + conflictItems.length;
}

/// Represents a sync conflict between local and remote versions
class SyncConflict {
  final SyncItem item;
  final SyncItem localItem;
  final SyncItem remoteItem;
  final ConflictType type;

  const SyncConflict({
    required this.item,
    required this.localItem,
    required this.remoteItem,
    required this.type,
  });
}

/// Types of sync conflicts
enum ConflictType { bothModified, deletedLocally, deletedRemotely }

/// Exception thrown during sync operations
class SyncException implements Exception {
  final String message;
  const SyncException(this.message);

  @override
  String toString() => 'SyncException: $message';
}
