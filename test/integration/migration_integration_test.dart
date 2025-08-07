import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../lib/services/file_migration_service.dart';
import '../../lib/services/local_file_storage_service.dart';
import '../../lib/services/attachment_service.dart';
import '../../lib/models/attachment.dart';
import '../../lib/models/entry.dart';
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
    await TestFileHelper.cleanup();
    await TestDatabaseHelper.cleanup();
  });

  tearDown(() async {
    await TestFileHelper.cleanup();
    await TestDatabaseHelper.cleanup();
  });

  group('Migration Integration Tests', () {
    test('complete migration workflow with real files', () async {
      // 1. Setup: Create a realistic scenario with mixed attachments
      final entries = TestDataGenerator.createMigrationTestDataset(
        entryCount: 5,
        attachmentsPerEntry: 3,
        legacyRatio: 0.8, // 80% legacy attachments
      );

      // Extract all attachments
      final allAttachments = <Attachment>[];
      for (final entry in entries) {
        allAttachments.addAll(entry.attachments);
      }

      final legacyAttachments = allAttachments.where(
        (a) => a.path.startsWith('/') || a.path.contains(':')
      ).toList();
      final modernAttachments = allAttachments.where(
        (a) => !a.path.startsWith('/') && !a.path.contains(':')
      ).toList();

      print('Test setup: ${legacyAttachments.length} legacy, ${modernAttachments.length} modern attachments');

      // 2. Setup database with test data
      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, 
        entries: entries, 
        attachments: allAttachments
      );

      // 3. Create actual files for legacy attachments
      await TestFileHelper.createLegacyTestFiles(legacyAttachments);
      await TestFileHelper.createMigratedFileStructure(modernAttachments);

      // 4. Verify pre-migration state
      final preMigrationStats = await TestDatabaseHelper.getMigrationStats(db);
      expect(preMigrationStats['legacy'], equals(legacyAttachments.length));
      expect(preMigrationStats['modern'], equals(modernAttachments.length));

      // Verify source files exist
      for (final attachment in legacyAttachments) {
        final exists = await TestFileHelper.verifyFileExists(attachment.path);
        expect(exists, isTrue, reason: 'Source file should exist: ${attachment.path}');
      }

      // 5. Run migration
      final migrationService = FileMigrationService();
      
      final progressLog = <String>[];
      final result = await migrationService.migrateAllFiles(
        onProgress: (current, total, status) {
          progressLog.add('[$current/$total] $status');
        },
      );

      // 6. Verify migration results
      expect(result.totalAttachments, equals(allAttachments.length));
      expect(result.migratedSuccessfully, equals(legacyAttachments.length));
      expect(result.alreadyMigrated, equals(modernAttachments.length));
      expect(result.failed, equals(0));
      expect(result.hasErrors, isFalse);
      expect(result.successRate, equals(1.0));

      // 7. Verify database was updated
      final postMigrationStats = await TestDatabaseHelper.getMigrationStats(db);
      expect(postMigrationStats['legacy'], equals(0)); // All migrated
      expect(postMigrationStats['modern'], equals(allAttachments.length)); // All modern now

      // 8. Verify migrated files exist and are accessible
      final validation = await migrationService.validateMigration();
      expect(validation['accessible'], equals(allAttachments.length));
      expect(validation['inaccessible'], equals(0));
      expect(validation['success_rate'], equals(1.0));

      // 9. Test file storage service can access migrated files
      final storageService = LocalFileStorageService();
      final migratedAttachments = await TestDatabaseHelper.getAllAttachments(db);
      
      for (final attachment in migratedAttachments) {
        final file = await storageService.getFile(attachment.path);
        expect(file, isNotNull, reason: 'Migrated file should be accessible: ${attachment.path}');
        expect(await file!.exists(), isTrue);
      }

      print('Migration completed successfully:');
      print('- Total: ${result.totalAttachments}');
      print('- Migrated: ${result.migratedSuccessfully}');
      print('- Duration: ${result.duration}');
      print('- Progress updates: ${progressLog.length}');
    });

    test('migration handles partial failures correctly', () async {
      // Create test data where some files will be missing
      final attachments = List.generate(6, (i) => 
        TestDataGenerator.createLegacyAttachment(name: 'partial_fail_$i.jpg')
      );

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);

      // Create files for only half of the attachments
      final successAttachments = attachments.take(3).toList();
      final failAttachments = attachments.skip(3).toList();
      
      await TestFileHelper.createLegacyTestFiles(successAttachments);
      // Don't create files for failAttachments - they will fail

      // Run migration
      final migrationService = FileMigrationService();
      final result = await migrationService.migrateAllFiles();

      // Verify partial success handling
      expect(result.totalAttachments, equals(6));
      expect(result.migratedSuccessfully, equals(3));
      expect(result.failed, equals(3));
      expect(result.hasErrors, isTrue);
      expect(result.errors.length, equals(3));
      expect(result.successRate, equals(0.5));

      // Verify database state - successful ones should be migrated
      final legacyAfter = await TestDatabaseHelper.getLegacyAttachments(db);
      final modernAfter = await TestDatabaseHelper.getModernAttachments(db);
      
      expect(legacyAfter.length, equals(3)); // Failed ones remain legacy
      expect(modernAfter.length, equals(3)); // Successful ones are modern
    });

    test('migration preserves file integrity and metadata', () async {
      // Create attachments with various types and metadata
      final photoAttachment = TestDataGenerator.createLegacyAttachment(
        type: AttachmentType.photo,
        name: 'integrity_photo.jpg',
        size: 1024 * 750, // 750KB
        metadata: {'camera': 'iPhone', 'location': 'test'},
      );

      final audioAttachment = TestDataGenerator.createLegacyAttachment(
        type: AttachmentType.audio,
        name: 'integrity_audio.mp3',
        size: 1024 * 1024 * 3, // 3MB
        metadata: {'duration': '180', 'bitrate': '128'},
      );

      final attachments = [photoAttachment, audioAttachment];

      // Setup database and files
      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);
      await TestFileHelper.createLegacyTestFiles(attachments);

      // Get original file info
      final originalPhotoInfo = await TestFileHelper.getFileInfo(photoAttachment.path);
      final originalAudioInfo = await TestFileHelper.getFileInfo(audioAttachment.path);

      // Run migration
      final migrationService = FileMigrationService();
      final result = await migrationService.migrateAllFiles();

      expect(result.migratedSuccessfully, equals(2));
      expect(result.failed, equals(0));

      // Get migrated attachments from database
      final migratedAttachments = await TestDatabaseHelper.getAllAttachments(db);
      expect(migratedAttachments.length, equals(2));

      // Verify file integrity after migration
      final storageService = LocalFileStorageService();
      
      for (final attachment in migratedAttachments) {
        final migratedFile = await storageService.getFile(attachment.path);
        expect(migratedFile, isNotNull);
        expect(await migratedFile!.exists(), isTrue);

        final migratedInfo = await TestFileHelper.getFileInfo(migratedFile.path);
        
        // Verify file size is preserved
        if (attachment.type == AttachmentType.photo) {
          expect(migratedInfo['size'], equals(originalPhotoInfo['size']));
        } else {
          expect(migratedInfo['size'], equals(originalAudioInfo['size']));
        }
        
        // Verify metadata is preserved
        expect(attachment.metadata, isNotNull);
        expect(attachment.size, isNotNull);
        expect(attachment.mimeType, isNotNull);
        expect(attachment.name, isNotEmpty);
      }
    });

    test('migration works correctly with concurrent file operations', () async {
      // Create test data
      final attachments = List.generate(10, (i) => 
        TestDataGenerator.createLegacyAttachment(name: 'concurrent_$i.jpg')
      );

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);
      await TestFileHelper.createLegacyTestFiles(attachments);

      final migrationService = FileMigrationService();

      // Start migration and simulate concurrent file access
      final migrationFuture = migrationService.migrateAllFiles();
      
      // Simulate concurrent file operations (reading files while migrating)
      final concurrentOps = <Future>[];
      for (final attachment in attachments.take(3)) {
        concurrentOps.add(Future.delayed(
          Duration(milliseconds: 100),
          () async {
            final exists = await TestFileHelper.verifyFileExists(attachment.path);
            return exists;
          },
        ));
      }

      // Wait for both migration and concurrent operations
      final results = await Future.wait([migrationFuture, ...concurrentOps]);
      final migrationResult = results.first as MigrationResult;

      // Verify migration succeeded despite concurrent operations
      expect(migrationResult.totalAttachments, equals(10));
      expect(migrationResult.migratedSuccessfully, equals(10));
      expect(migrationResult.failed, equals(0));

      // Verify concurrent operations completed
      for (int i = 1; i < results.length; i++) {
        expect(results[i], isA<bool>());
      }
    });

    test('large dataset performance and memory usage', () async {
      // Create a large dataset for performance testing
      const largeCount = 500;
      
      final entries = TestDataGenerator.createPerformanceTestDataset(
        entryCount: 50,
        maxAttachmentsPerEntry: 10,
      );

      final allAttachments = <Attachment>[];
      for (final entry in entries) {
        allAttachments.addAll(entry.attachments);
      }

      print('Performance test: ${allAttachments.length} attachments across ${entries.length} entries');

      // Setup database
      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, 
        entries: entries,
        attachments: allAttachments
      );

      // Create test files for a subset (to avoid excessive disk usage in tests)
      final testFileCount = 50;
      await TestFileHelper.createLegacyTestFiles(allAttachments.take(testFileCount).toList());

      // Run migration with timing
      final migrationService = FileMigrationService();
      
      final stopwatch = Stopwatch()..start();
      var lastProgressTime = stopwatch.elapsedMilliseconds;
      var progressCount = 0;
      
      final result = await migrationService.migrateAllFiles(
        onProgress: (current, total, status) {
          progressCount++;
          final currentTime = stopwatch.elapsedMilliseconds;
          final timeDiff = currentTime - lastProgressTime;
          
          if (progressCount % 100 == 0) { // Log every 100 progress updates
            print('Progress: $current/$total (${(current/total*100).toStringAsFixed(1)}%) - '
                  'Time since last: ${timeDiff}ms');
          }
          
          lastProgressTime = currentTime;
        },
      );
      stopwatch.stop();

      // Performance assertions
      expect(result.totalAttachments, equals(allAttachments.length));
      expect(result.duration.inSeconds, lessThan(60)); // Should complete within 1 minute
      expect(progressCount, greaterThan(allAttachments.length)); // Should have progress updates

      print('Performance results:');
      print('- Total attachments: ${result.totalAttachments}');
      print('- Migration time: ${result.duration}');
      print('- Successful migrations: ${result.migratedSuccessfully}');
      print('- Failed migrations: ${result.failed}');
      print('- Progress updates: $progressCount');
      print('- Average time per attachment: ${result.duration.inMilliseconds / result.totalAttachments}ms');
    });

    test('rollback scenario when storage service fails', () async {
      // This test simulates what happens when the storage service fails mid-migration
      final attachments = List.generate(5, (i) => 
        TestDataGenerator.createLegacyAttachment(name: 'rollback_$i.jpg')
      );

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);
      await TestFileHelper.createLegacyTestFiles(attachments);

      // Create a snapshot of database state before migration
      final preMigrationSnapshot = await TestDatabaseHelper.createDatabaseSnapshot(db);
      final preMigrationStats = await TestDatabaseHelper.getMigrationStats(db);

      // Simulate storage service failure by removing write permissions on target directory
      final storageDir = await TestFileHelper.createOrganizedStorageStructure();
      if (Platform.isLinux || Platform.isMacOS) {
        await Process.run('chmod', ['555', storageDir]); // Read-only
      }

      try {
        // Run migration - should fail due to permission issues
        final migrationService = FileMigrationService();
        final result = await migrationService.migrateAllFiles();

        // Should have failures
        expect(result.failed, greaterThan(0));
        expect(result.hasErrors, isTrue);

        // Verify database state - should not be corrupted
        final postFailureStats = await TestDatabaseHelper.getMigrationStats(db);
        
        // Some migrations might have started but database should be consistent
        expect(postFailureStats['total'], equals(preMigrationStats['total']));
        
      } finally {
        // Restore permissions for cleanup
        if (Platform.isLinux || Platform.isMacOS) {
          await Process.run('chmod', ['755', storageDir]);
        }
      }
    });
  });
}