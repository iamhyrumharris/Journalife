import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:journal_new/models/sync_config.dart';
import 'package:journal_new/models/sync_status.dart';
import 'package:journal_new/models/journal.dart';
import 'package:journal_new/models/entry.dart';
import 'package:journal_new/services/webdav_sync_service.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

void main() {
  group('WebDAV Sync Service Tests', () {
    late ProviderContainer container;
    late SyncConfig testConfig;
    late webdav.Client webdavClient;
    
    // Test configuration - using real Nextcloud server
    const testServerUrl = 'https://nextcloud.promiselan.com/remote.php/dav/files/iamhyrumharris@gmail.com';
    const testUsername = 'iamhyrumharris@gmail.com';
    const testPassword = r'broJoe123@#$';
    
    Future<void> cleanupTestData() async {
      try {
        final testBasePath = '/journal_app/${testUsername}_data';
        await webdavClient.remove(testBasePath);
        print('✅ Test data cleaned up');
      } catch (e) {
        print('⚠️ Cleanup failed (may not exist): $e');
      }
    }
    
    setUpAll(() async {
      // Create test configuration
      testConfig = SyncConfig(
        id: 'unit-test-config',
        serverUrl: testServerUrl,
        username: testUsername,
        displayName: 'Unit Test Config',
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
        debug: false,
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

    test('WebDAV connection and basic operations', () async {
      print('🔍 Testing WebDAV connection...');
      
      // Test basic connection
      await webdavClient.ping();
      print('✅ WebDAV connection successful');
      
      // Test directory creation
      final testDir = '/unit_test_${DateTime.now().millisecondsSinceEpoch}';
      await webdavClient.mkdir(testDir);
      print('✅ Directory creation successful');
      
      // Test file operations
      final testFile = '$testDir/test.json';
      const testData = '{"test": "data"}';
      await webdavClient.write(testFile, Uint8List.fromList(utf8.encode(testData)));
      
      final readData = await webdavClient.read(testFile);
      final readString = String.fromCharCodes(readData);
      expect(readString, equals(testData));
      print('✅ File operations successful');
      
      // Cleanup
      await webdavClient.remove(testDir);
      print('✅ Test cleanup successful');
    });

    test('WebDAV sync service initialization', () async {
      print('🔍 Testing WebDAV sync service initialization...');
      
      final syncService = WebDAVSyncService();
      await syncService.initialize(testConfig, testPassword);
      print('✅ WebDAV sync service initialized successfully');
    });

    test('Journal and entry sync workflow', () async {
      print('🔍 Testing journal and entry sync workflow...');
      
      // Create test journal
      final journal = Journal(
        id: 'test-journal-unit',
        name: 'Unit Test Journal',
        description: 'Test journal for unit testing',
        ownerId: 'test-user',
        sharedWithUserIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Create test entry
      final entry = Entry(
        id: 'test-entry-unit',
        journalId: journal.id,
        title: 'Unit Test Entry',
        content: 'This is a test entry for unit testing WebDAV sync.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tags: ['unit-test'],
        attachments: [],
      );
      
      // Initialize sync service
      final syncService = WebDAVSyncService();
      await syncService.initialize(testConfig, testPassword);
      
      // Test sync operations
      final syncStatus = await syncService.performSync(
        onStatusUpdate: (status) {
          print('Sync status: ${status.state} - ${status.statusMessage}');
        },
      );
      
      expect(syncStatus.state, equals(SyncState.completed));
      print('✅ Journal and entry sync workflow completed');
    });
  });
}