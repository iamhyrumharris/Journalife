import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../lib/services/file_migration_service.dart';
import '../../lib/services/local_file_storage_service.dart';
import '../../lib/models/attachment.dart';
import '../test_helpers/test_database_helper.dart';
import '../test_helpers/test_data_generator.dart';
import '../test_helpers/test_file_helper.dart';

void main() {
  // Initialize FFI for desktop testing
  setUpAll(() {
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  setUp(() async {
    // Clean up before each test
    await TestFileHelper.cleanup();
    await TestDatabaseHelper.cleanup();
  });

  tearDown(() async {
    // Clean up after each test
    await TestFileHelper.cleanup();
    await TestDatabaseHelper.cleanup();
  });

  group('FileMigrationService - Migration Detection', () {
    test('isMigrationNeeded returns true when legacy paths exist', () async {
      // Setup test database with legacy attachments
      final db = await TestDatabaseHelper.setupMigrationTestDb(
        legacyAttachmentCount: 5,
        modernAttachmentCount: 0,
      );

      final migrationService = FileMigrationService();
      
      // Override database service to use test database
      final result = await migrationService.isMigrationNeeded();
      
      expect(result, isTrue);
    });

    test('isMigrationNeeded returns false when no legacy paths exist', () async {
      // Setup test database with only modern attachments
      final db = await TestDatabaseHelper.setupMigrationTestDb(
        legacyAttachmentCount: 0,
        modernAttachmentCount: 5,
      );

      final migrationService = FileMigrationService();
      final result = await migrationService.isMigrationNeeded();
      
      expect(result, isFalse);
    });

    test('getMigrationCount returns correct count of legacy attachments', () async {
      const expectedLegacyCount = 7;
      const modernCount = 3;
      
      final db = await TestDatabaseHelper.setupMigrationTestDb(
        legacyAttachmentCount: expectedLegacyCount,
        modernAttachmentCount: modernCount,
      );

      final migrationService = FileMigrationService();
      final count = await migrationService.getMigrationCount();
      
      expect(count, equals(expectedLegacyCount));
    });

    test('getMigrationStats returns accurate statistics', () async {
      const legacyCount = 8;
      const modernCount = 4;
      
      final db = await TestDatabaseHelper.setupMigrationTestDb(
        legacyAttachmentCount: legacyCount,
        modernAttachmentCount: modernCount,
      );

      final migrationService = FileMigrationService();
      final stats = await migrationService.getMigrationStats();
      
      expect(stats['legacy_count'], equals(legacyCount));
      expect(stats['migrated_count'], equals(modernCount));
      expect(stats['total_count'], equals(legacyCount + modernCount));
      expect(stats['migration_needed'], isTrue);
    });
  });

  group('FileMigrationService - File Migration', () {
    test('migrateAllFiles successfully migrates legacy attachments', () async {
      // Create test data
      const legacyCount = 3;
      final attachments = <Attachment>[];
      
      for (int i = 0; i < legacyCount; i++) {
        attachments.add(TestDataGenerator.createLegacyAttachment(
          name: 'legacy_test_$i.jpg',
        ));
      }

      // Setup database
      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);

      // Create actual test files
      await TestFileHelper.createLegacyTestFiles(attachments);

      // Setup organized storage structure
      await TestFileHelper.createOrganizedStorageStructure();

      final migrationService = FileMigrationService();
      
      // Track progress
      final progressUpdates = <String>[];
      final result = await migrationService.migrateAllFiles(
        onProgress: (current, total, status) {
          progressUpdates.add('$current/$total: $status');
        },
      );

      // Verify results
      expect(result.totalAttachments, equals(legacyCount));
      expect(result.migratedSuccessfully, equals(legacyCount));
      expect(result.alreadyMigrated, equals(0));
      expect(result.failed, equals(0));
      expect(result.hasErrors, isFalse);
      expect(progressUpdates.isNotEmpty, isTrue);
      expect(result.isComplete, isTrue);
      expect(result.successRate, equals(1.0));
    });

    test('migrateAllFiles handles mixed legacy and modern attachments', () async {
      // Create mixed test data
      final legacyAttachments = List.generate(4, (i) => 
        TestDataGenerator.createLegacyAttachment(name: 'legacy_$i.jpg')
      );
      final modernAttachments = List.generate(3, (i) => 
        TestDataGenerator.createModernAttachment(name: 'modern_$i.jpg')
      );

      final allAttachments = [...legacyAttachments, ...modernAttachments];

      // Setup database
      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: allAttachments);

      // Create test files
      await TestFileHelper.createLegacyTestFiles(legacyAttachments);
      await TestFileHelper.createMigratedFileStructure(modernAttachments);

      final migrationService = FileMigrationService();
      final result = await migrationService.migrateAllFiles();

      expect(result.totalAttachments, equals(allAttachments.length));
      expect(result.migratedSuccessfully, equals(legacyAttachments.length));
      expect(result.alreadyMigrated, equals(modernAttachments.length));
      expect(result.failed, equals(0));
    });

    test('migrateAllFiles handles missing source files gracefully', () async {
      // Create attachments but don't create the actual files
      final attachments = List.generate(3, (i) => 
        TestDataGenerator.createLegacyAttachment(name: 'missing_$i.jpg')
      );

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);
      
      // Setup storage but don't create source files
      await TestFileHelper.createOrganizedStorageStructure();

      final migrationService = FileMigrationService();
      final result = await migrationService.migrateAllFiles();

      expect(result.totalAttachments, equals(3));
      expect(result.migratedSuccessfully, equals(0));
      expect(result.failed, equals(3));
      expect(result.hasErrors, isTrue);
      expect(result.errors.length, equals(3));
    });

    test('migrateAllFiles dry run mode works correctly', () async {
      // Create test data with files
      final attachments = List.generate(2, (i) => 
        TestDataGenerator.createLegacyAttachment(name: 'dryrun_$i.jpg')
      );

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);
      await TestFileHelper.createLegacyTestFiles(attachments);

      final migrationService = FileMigrationService();
      
      // Run in dry run mode
      final result = await migrationService.migrateAllFiles(dryRun: true);

      // Verify no actual changes were made
      expect(result.totalAttachments, equals(2));
      expect(result.migratedSuccessfully, equals(2)); // Simulated success
      expect(result.failed, equals(0));
      
      // Verify database wasn't actually updated
      final legacyAttachments = await TestDatabaseHelper.getLegacyAttachments(db);
      expect(legacyAttachments.length, equals(2)); // Still legacy paths
    });
  });

  group('FileMigrationService - Progress Tracking', () {
    test('progress callbacks provide accurate updates', () async {
      final attachments = List.generate(5, (i) => 
        TestDataGenerator.createLegacyAttachment(name: 'progress_$i.jpg')
      );

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);
      await TestFileHelper.createLegacyTestFiles(attachments);

      final migrationService = FileMigrationService();
      
      final progressHistory = <Map<String, dynamic>>[];
      
      await migrationService.migrateAllFiles(
        onProgress: (current, total, status) {
          progressHistory.add({
            'current': current,
            'total': total,
            'status': status,
          });
        },
      );

      // Verify progress tracking
      expect(progressHistory.isNotEmpty, isTrue);
      expect(progressHistory.first['current'], equals(0));
      expect(progressHistory.first['total'], equals(5));
      expect(progressHistory.last['current'], equals(5));
      expect(progressHistory.last['total'], equals(5));
      
      // Verify progression
      for (int i = 1; i < progressHistory.length; i++) {
        expect(progressHistory[i]['current'], 
          greaterThanOrEqualTo(progressHistory[i-1]['current']));
      }
    });
  });

  group('FileMigrationService - Validation', () {
    test('validateMigration correctly reports file accessibility', () async {
      // Create some attachments and migrate them
      final legacyAttachments = List.generate(3, (i) => 
        TestDataGenerator.createLegacyAttachment(name: 'validate_$i.jpg')
      );

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: legacyAttachments);
      await TestFileHelper.createLegacyTestFiles(legacyAttachments);

      final migrationService = FileMigrationService();
      await migrationService.migrateAllFiles();

      // Validate migration results
      final validation = await migrationService.validateMigration();

      expect(validation['total'], equals(3));
      expect(validation['accessible'], equals(3));
      expect(validation['inaccessible'], equals(0));
      expect(validation['success_rate'], equals(1.0));
      expect(validation['inaccessible_files'], isEmpty);
    });

    test('validateMigration detects inaccessible files', () async {
      // Create attachments and files
      final attachments = List.generate(4, (i) => 
        TestDataGenerator.createLegacyAttachment(name: 'access_test_$i.jpg')
      );

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);
      await TestFileHelper.createLegacyTestFiles(attachments);

      final migrationService = FileMigrationService();
      await migrationService.migrateAllFiles();

      // Simulate some files becoming inaccessible
      final allAttachments = await TestDatabaseHelper.getAllAttachments(db);
      final someFilePaths = allAttachments.take(2).map((a) => a.path).toList();
      await TestFileHelper.simulateMissingFiles(someFilePaths);

      // Validate and check results
      final validation = await migrationService.validateMigration();

      expect(validation['total'], equals(4));
      expect(validation['accessible'], equals(2));
      expect(validation['inaccessible'], equals(2));
      expect(validation['success_rate'], equals(0.5));
      expect(validation['inaccessible_files'], hasLength(2));
    });
  });

  group('FileMigrationService - Error Handling', () {
    test('handles permission errors gracefully', () async {
      if (Platform.isWindows) return; // Skip on Windows

      final attachments = [TestDataGenerator.createLegacyAttachment(name: 'permission_test.jpg')];

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);
      await TestFileHelper.createLegacyTestFiles(attachments);

      // Remove permissions
      await TestFileHelper.simulatePermissionIssues([attachments.first.path]);

      final migrationService = FileMigrationService();
      final result = await migrationService.migrateAllFiles();

      // Should handle permission error gracefully
      expect(result.totalAttachments, equals(1));
      expect(result.failed, equals(1));
      expect(result.hasErrors, isTrue);

      // Cleanup: restore permissions
      await TestFileHelper.restorePermissions([attachments.first.path]);
    });

    test('handles database errors during migration', () async {
      final attachments = [TestDataGenerator.createLegacyAttachment()];

      // Create database but don't set up proper schema
      final db = await TestDatabaseHelper.createTestDatabase();
      // Intentionally corrupt the database schema
      await db.execute('DROP TABLE attachments');

      final migrationService = FileMigrationService();
      
      // Should handle database errors gracefully
      expect(() => migrationService.migrateAllFiles(), 
        throwsA(isA<Exception>()));
    });
  });

  group('FileMigrationService - Performance', () {
    test('handles large datasets efficiently', () async {
      const largeCount = 100;
      final attachments = List.generate(largeCount, (i) => 
        TestDataGenerator.createLegacyAttachment(name: 'perf_$i.jpg')
      );

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);
      
      // Create smaller test files for performance
      for (final attachment in attachments.take(10)) {
        await TestFileHelper.createLegacyTestFiles([attachment]);
      }

      final migrationService = FileMigrationService();
      
      final stopwatch = Stopwatch()..start();
      final result = await migrationService.migrateAllFiles();
      stopwatch.stop();

      // Verify performance metrics
      expect(result.duration.inMilliseconds, lessThan(30000)); // Less than 30s
      expect(result.totalAttachments, equals(largeCount));
      expect(result.migratedSuccessfully + result.failed, equals(largeCount));
      
      print('Migration of $largeCount attachments took: ${result.duration}');
    });
  });
}