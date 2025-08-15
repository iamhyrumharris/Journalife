import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import 'package:journal_new/main.dart' as app;
import 'package:journal_new/models/sync_config.dart';
import 'package:journal_new/models/journal.dart';
import 'package:journal_new/models/entry.dart';
import 'package:journal_new/models/attachment.dart';
import 'package:journal_new/services/webdav_sync_service.dart';
import 'package:journal_new/services/database_service.dart';
import 'package:journal_new/providers/journal_provider.dart';
import 'package:journal_new/providers/entry_provider.dart';
import 'package:journal_new/providers/sync_config_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('WebDAV Sync Integration Tests', () {
    late ProviderContainer container;
    late SyncConfig testConfig;
    late webdav.Client webdavClient;

    // Test configuration - you'll need to update these values
    const testServerUrl =
        'https://nextcloud.promiselan.com/remote.php/dav/files/iamhyrumharris@gmail.com';
    const testUsername = 'iamhyrumharris@gmail.com';
    const testPassword = r'broJoe123@#$';

    /// Cleans up test data from the WebDAV server
    Future<void> cleanupTestData() async {
      print('🧹 Cleaning up test data...');

      try {
        // Remove test base directory and all contents
        final testBasePath = '/journal_app/${testUsername}_data';
        await webdavClient.remove(testBasePath);
        print('✅ Test data cleaned up');
      } catch (e) {
        print('⚠️ Cleanup failed (may not exist): $e');
      }
    }

    setUpAll(() async {
      // Initialize the app
      app.main();

      // Create test configuration
      testConfig = SyncConfig(
        id: 'integration-test-config',
        serverUrl: testServerUrl,
        username: testUsername,
        displayName: 'Integration Test Config',
        lastSyncAt: DateTime.now(),
        syncFrequency: SyncFrequency.manual,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Initialize WebDAV client
      webdavClient = webdav.newClient(
        testServerUrl,
        user: testUsername,
        password: testPassword,
        debug: true,
      );

      // Create provider container
      container = ProviderContainer();

      // Clean up any existing test data
      await cleanupTestData();
    });

    tearDownAll(() async {
      await cleanupTestData();
      container.dispose();
    });

    testWidgets('Create journal entry and verify sync to WebDAV server', (
      WidgetTester tester,
    ) async {
      // Step 1: Create a test journal
      final journal = Journal(
        id: 'test-journal-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Journal for WebDAV Sync',
        description: 'Integration test journal',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final databaseService = container.read(databaseServiceProvider);
      await databaseService.insertJournal(journal);

      print('📓 Created test journal: ${journal.name}');

      // Step 2: Create a journal entry with attachments
      final entryId = 'test-entry-${DateTime.now().millisecondsSinceEpoch}';
      final entry = Entry(
        id: entryId,
        journalId: journal.id,
        title: 'Integration Test Entry',
        content:
            'This is a test entry created by the WebDAV integration test. It contains various attachments and should be synced to the WebDAV server.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: ['integration-test', 'webdav', 'sync'],
        latitude: 37.7749,
        longitude: -122.4194,
        locationName: 'San Francisco, CA',
        attachments: await createTestAttachments(entryId),
      );

      await databaseService.insertEntry(entry);

      print('📝 Created test entry: ${entry.title}');
      print('📎 Entry has ${entry.attachments.length} attachments');

      // Step 3: Set up WebDAV sync configuration
      final syncNotifier = container.read(syncConfigProvider.notifier);
      await syncNotifier.createConfiguration(
        serverUrl: testConfig.serverUrl,
        username: testConfig.username,
        displayName: testConfig.displayName,
        password: testPassword,
        syncFrequency: testConfig.syncFrequency,
        syncOnWifiOnly: false,
        syncAttachments: true,
        encryptData: false,
      );

      print('⚙️ Created WebDAV sync configuration');

      // Step 4: Initialize and perform sync
      final syncService = WebDAVSyncService();
      await syncService.initialize(testConfig, testPassword);

      print('🔄 Performing WebDAV sync...');
      final syncStatus = await syncService.performSync(
        onStatusUpdate: (status) {
          print(
            'Sync status: ${status.state} - ${status.message ?? 'No message'}',
          );
        },
      );

      expect(
        syncStatus.state,
        SyncState.completed,
        reason: 'Sync should complete successfully',
      );

      print('✅ WebDAV sync completed');

      // Step 5: Verify data exists on WebDAV server
      await verifyEntryOnServer(entry);

      // Step 6: Verify journal metadata on server
      await verifyJournalOnServer(journal);

      print('🎉 Integration test passed - entry verified on WebDAV server!');
    });

    testWidgets(
      'Verify bidirectional sync - modify entry on server and sync back',
      (WidgetTester tester) async {
        // This test verifies that changes made directly to the server
        // are properly synced back to the local app

        // Step 1: Get an existing entry from previous test
        final databaseService = container.read(databaseServiceProvider);
        final entries = await databaseService.getEntriesForJournal(
          'test-journal-*',
        );

        expect(
          entries.isNotEmpty,
          true,
          reason: 'Should have entries from previous test',
        );

        final originalEntry = entries.first;
        print('📝 Original entry: ${originalEntry.title}');

        // Step 2: Modify entry directly on WebDAV server
        final modifiedTitle = '${originalEntry.title} - Modified on Server';
        final modifiedContent =
            '${originalEntry.content}\n\nThis modification was made directly on the WebDAV server to test bidirectional sync.';

        await modifyEntryOnServer(
          originalEntry,
          modifiedTitle,
          modifiedContent,
        );
        print('🔧 Modified entry on WebDAV server');

        // Step 3: Perform sync to pull changes back
        final syncService = WebDAVSyncService();
        await syncService.initialize(testConfig, testPassword);

        print('🔄 Syncing changes from server...');
        final syncStatus = await syncService.performSync();

        expect(
          syncStatus.state,
          SyncState.completed,
          reason: 'Bidirectional sync should complete successfully',
        );

        // Step 4: Verify local entry was updated
        final updatedEntry = await databaseService.getEntry(originalEntry.id);
        expect(
          updatedEntry,
          isNotNull,
          reason: 'Entry should still exist after sync',
        );

        expect(
          updatedEntry!.title,
          modifiedTitle,
          reason: 'Entry title should be updated from server',
        );

        expect(
          updatedEntry.content,
          modifiedContent,
          reason: 'Entry content should be updated from server',
        );

        print('✅ Bidirectional sync verified - changes pulled from server');
      },
    );
  });

  /// Creates test attachments for the journal entry
  Future<List<Attachment>> createTestAttachments(String entryId) async {
    final attachments = <Attachment>[];
    final now = DateTime.now();

    // Create a test photo attachment
    final photoAttachment = Attachment(
      id: 'photo-${now.millisecondsSinceEpoch}',
      entryId: entryId,
      type: AttachmentType.photo,
      name: 'test-photo.jpg',
      path:
          'photos/${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/$entryId/test-photo.jpg',
      mimeType: 'image/jpeg',
      size: 1024 * 50, // 50KB
      createdAt: now,
      metadata: {
        'width': '800',
        'height': '600',
        'camera': 'Integration Test Camera',
      },
    );
    attachments.add(photoAttachment);

    // Create a test audio attachment
    final audioAttachment = Attachment(
      id: 'audio-${now.millisecondsSinceEpoch}',
      entryId: entryId,
      type: AttachmentType.audio,
      name: 'test-recording.m4a',
      path:
          'audio/${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/$entryId/test-recording.m4a',
      mimeType: 'audio/mp4',
      size: 1024 * 200, // 200KB
      createdAt: now,
      metadata: {'duration': '30', 'format': 'm4a', 'bitrate': '128'},
    );
    attachments.add(audioAttachment);

    // Create a test file attachment
    final fileAttachment = Attachment(
      id: 'file-${now.millisecondsSinceEpoch}',
      entryId: entryId,
      type: AttachmentType.file,
      name: 'test-document.pdf',
      path:
          'attachments/${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/$entryId/test-document.pdf',
      mimeType: 'application/pdf',
      size: 1024 * 100, // 100KB
      createdAt: now,
      metadata: {'pages': '5', 'format': 'PDF'},
    );
    attachments.add(fileAttachment);

    // Create test location attachment
    final locationAttachment = Attachment(
      id: 'location-${now.millisecondsSinceEpoch}',
      entryId: entryId,
      type: AttachmentType.location,
      name: 'Test Location',
      path: '', // Location attachments don't have file paths
      mimeType: 'application/json',
      size: 256,
      createdAt: now,
      metadata: {
        'latitude': '37.7749',
        'longitude': '-122.4194',
        'address': 'San Francisco, CA, USA',
        'accuracy': '10.0',
      },
    );
    attachments.add(locationAttachment);

    // Create actual test files for photo, audio, and file attachments
    await createTestFiles(attachments);

    return attachments;
  }

  /// Creates actual test files for attachments
  Future<void> createTestFiles(List<Attachment> attachments) async {
    for (final attachment in attachments) {
      if (attachment.path.isEmpty) continue; // Skip location attachments

      final serverPath = '${testConfig.basePath}/${attachment.path}';
      final parentDir = serverPath.substring(0, serverPath.lastIndexOf('/'));

      try {
        // Create directory structure
        await webdavClient.mkdir(parentDir);

        // Create appropriate test file content
        Uint8List fileContent;
        switch (attachment.type) {
          case AttachmentType.photo:
            fileContent = createTestImageData();
            break;
          case AttachmentType.audio:
            fileContent = createTestAudioData();
            break;
          case AttachmentType.file:
            fileContent = createTestPDFData();
            break;
          default:
            fileContent = Uint8List.fromList(utf8.encode('Test file content'));
        }

        // Upload test file to server
        await webdavClient.write(serverPath, fileContent);
        print(
          '📁 Created test file: ${attachment.name} (${attachment.size} bytes)',
        );
      } catch (e) {
        print('❌ Failed to create test file ${attachment.name}: $e');
      }
    }
  }

  /// Creates minimal test image data (fake JPEG header)
  Uint8List createTestImageData() {
    final imageData = <int>[
      0xFF, 0xD8, 0xFF, 0xE0, // JPEG header
      0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, // JFIF
    ];
    // Add some dummy data to reach desired size
    while (imageData.length < 1024 * 50) {
      imageData.addAll([0x00, 0xFF, 0xAA, 0x55]);
    }
    imageData.addAll([0xFF, 0xD9]); // JPEG end marker
    return Uint8List.fromList(imageData);
  }

  /// Creates minimal test audio data
  Uint8List createTestAudioData() {
    final audioData = <int>[
      0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // M4A header
      0x4D, 0x34, 0x41, 0x20,
    ];
    // Add dummy data to reach desired size
    while (audioData.length < 1024 * 200) {
      audioData.addAll([0x00, 0xFF, 0xAA, 0x55, 0x33, 0xCC]);
    }
    return Uint8List.fromList(audioData);
  }

  /// Creates minimal test PDF data
  Uint8List createTestPDFData() {
    const pdfContent = '''%PDF-1.4
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>
endobj
4 0 obj
<< /Length 44 >>
stream
BT
/F1 24 Tf
100 700 Td
(Integration Test PDF) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f 
0000000010 00000 n 
0000000053 00000 n 
0000000109 00000 n 
0000000203 00000 n 
trailer
<< /Size 5 /Root 1 0 R >>
startxref
295
%%EOF''';
    return Uint8List.fromList(utf8.encode(pdfContent));
  }

  /// Verifies that the journal entry exists on the WebDAV server
  Future<void> verifyEntryOnServer(Entry entry) async {
    print('🔍 Verifying entry on WebDAV server...');

    // Verify entry JSON file exists
    final entryPath = testConfig.getJournalEntriesPath(entry.createdAt);

    try {
      final entryBytes = await webdavClient.read(entryPath);
      final entryData = jsonDecode(utf8.decode(entryBytes));

      expect(
        entryData,
        isA<Map<String, dynamic>>(),
        reason: 'Entry data should be a valid JSON object',
      );

      // Find our entry in the entries array
      final entries = entryData['entries'] as List?;
      expect(entries, isNotNull, reason: 'Entries array should exist');

      final serverEntry = entries!.firstWhere(
        (e) => e['id'] == entry.id,
        orElse: () => null,
      );

      expect(serverEntry, isNotNull, reason: 'Entry should exist on server');

      expect(
        serverEntry['title'],
        entry.title,
        reason: 'Entry title should match',
      );

      expect(
        serverEntry['content'],
        entry.content,
        reason: 'Entry content should match',
      );

      expect(
        serverEntry['tags'],
        entry.tags,
        reason: 'Entry tags should match',
      );

      print('✅ Entry verified on server');

      // Verify attachments exist on server
      await verifyAttachmentsOnServer(entry.attachments);
    } catch (e) {
      fail('Failed to verify entry on server: $e');
    }
  }

  /// Verifies that all attachments exist on the WebDAV server
  Future<void> verifyAttachmentsOnServer(List<Attachment> attachments) async {
    print('🔍 Verifying ${attachments.length} attachments on server...');

    for (final attachment in attachments) {
      if (attachment.path.isEmpty) continue; // Skip location attachments

      final serverPath = '${testConfig.basePath}/${attachment.path}';

      try {
        final fileBytes = await webdavClient.read(serverPath);

        expect(
          fileBytes.isNotEmpty,
          true,
          reason: 'Attachment file should not be empty',
        );

        // Verify file size matches (approximately, allowing for some variance)
        final serverSize = fileBytes.length;
        final expectedSize = attachment.size ?? 0;
        final sizeDifference = (serverSize - expectedSize).abs();
        final allowedVariance = expectedSize * 0.1; // 10% variance allowed

        expect(
          sizeDifference <= allowedVariance,
          true,
          reason:
              'File size should be approximately correct (server: $serverSize, expected: $expectedSize)',
        );

        print('✅ Attachment verified: ${attachment.name} ($serverSize bytes)');
      } catch (e) {
        fail('Failed to verify attachment ${attachment.name} on server: $e');
      }
    }

    print('✅ All attachments verified on server');
  }

  /// Verifies that the journal metadata exists on the WebDAV server
  Future<void> verifyJournalOnServer(Journal journal) async {
    print('🔍 Verifying journal metadata on server...');

    final journalMetadataPath = testConfig.journalMetadataPath;

    try {
      final metadataBytes = await webdavClient.read(journalMetadataPath);
      final metadataData = jsonDecode(utf8.decode(metadataBytes));

      expect(
        metadataData,
        isA<Map<String, dynamic>>(),
        reason: 'Journal metadata should be a valid JSON object',
      );

      final journals = metadataData['journals'] as List?;
      expect(journals, isNotNull, reason: 'Journals array should exist');

      final serverJournal = journals!.firstWhere(
        (j) => j['id'] == journal.id,
        orElse: () => null,
      );

      expect(
        serverJournal,
        isNotNull,
        reason: 'Journal should exist on server',
      );

      expect(
        serverJournal['name'],
        journal.name,
        reason: 'Journal name should match',
      );

      print('✅ Journal metadata verified on server');
    } catch (e) {
      fail('Failed to verify journal metadata on server: $e');
    }
  }

  /// Modifies an entry directly on the WebDAV server
  Future<void> modifyEntryOnServer(
    Entry entry,
    String newTitle,
    String newContent,
  ) async {
    final entryPath = testConfig.getJournalEntriesPath(entry.createdAt);

    try {
      // Read current entries file
      final entryBytes = await webdavClient.read(entryPath);
      final entryData = jsonDecode(utf8.decode(entryBytes));

      final entries = entryData['entries'] as List;

      // Find and modify the entry
      for (int i = 0; i < entries.length; i++) {
        if (entries[i]['id'] == entry.id) {
          entries[i]['title'] = newTitle;
          entries[i]['content'] = newContent;
          entries[i]['updated_at'] = DateTime.now().toIso8601String();
          break;
        }
      }

      // Write back modified data
      final modifiedJson = jsonEncode(entryData);
      await webdavClient.write(
        entryPath,
        Uint8List.fromList(utf8.encode(modifiedJson)),
      );

      print('🔧 Modified entry on server: $newTitle');
    } catch (e) {
      fail('Failed to modify entry on server: $e');
    }
  }

  /// Cleans up test data from the WebDAV server
  Future<void> cleanupTestData() async {
    print('🧹 Cleaning up test data...');

    try {
      // Remove test base directory and all contents
      final testBasePath = '/journal_app/${testUsername}_data';
      await webdavClient.remove(testBasePath);
      print('✅ Test data cleaned up');
    } catch (e) {
      print('⚠️ Cleanup failed (may not exist): $e');
    }
  }
}
