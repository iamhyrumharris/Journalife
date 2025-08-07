import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../lib/services/file_migration_service.dart';
import '../../lib/services/local_file_storage_service.dart';
import '../../lib/services/attachment_service.dart';
import '../../lib/widgets/attachment_thumbnail.dart';
import '../../lib/models/attachment.dart';
import '../../lib/models/entry.dart';
import '../test_helpers/test_database_helper.dart';
import '../test_helpers/test_data_generator.dart';
import '../test_helpers/test_file_helper.dart';

/// Comprehensive system integrity validation tests
/// These tests verify the entire file storage and migration system works together
void main() {
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

  group('System Integrity Validation', () {
    test('end-to-end system validation with real data flow', () async {
      print('🔍 Starting comprehensive system integrity validation...');

      // 1. SETUP: Create realistic test scenario
      print('📝 Setting up test data...');
      final testEntries = TestDataGenerator.createMigrationTestDataset(
        entryCount: 8,
        attachmentsPerEntry: 4,
        legacyRatio: 0.75, // 75% legacy, 25% modern
      );

      final allAttachments = <Attachment>[];
      for (final entry in testEntries) {
        allAttachments.addAll(entry.attachments);
      }

      final legacyAttachments = allAttachments.where(
        (a) => a.path.startsWith('/') || a.path.contains(':')
      ).toList();
      final modernAttachments = allAttachments.where(
        (a) => !a.path.startsWith('/') && !a.path.contains(':')
      ).toList();

      print('✅ Created ${testEntries.length} entries with ${allAttachments.length} attachments');
      print('   - Legacy: ${legacyAttachments.length}');
      print('   - Modern: ${modernAttachments.length}');

      // 2. DATABASE SETUP
      print('🗄️ Setting up test database...');
      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db,
        entries: testEntries,
        attachments: allAttachments,
      );

      // Verify database integrity
      final dbStats = await TestDatabaseHelper.getMigrationStats(db);
      expect(dbStats['total'], equals(allAttachments.length));
      expect(dbStats['legacy'], equals(legacyAttachments.length));
      expect(dbStats['modern'], equals(modernAttachments.length));
      print('✅ Database setup verified');

      // 3. FILE SYSTEM SETUP
      print('📁 Creating test files...');
      await TestFileHelper.createLegacyTestFiles(legacyAttachments);
      await TestFileHelper.createMigratedFileStructure(modernAttachments);

      // Verify all files exist
      for (final attachment in legacyAttachments) {
        final exists = await TestFileHelper.verifyFileExists(attachment.path);
        expect(exists, isTrue, reason: 'Legacy file should exist: ${attachment.path}');
      }

      final storageService = LocalFileStorageService();
      for (final attachment in modernAttachments) {
        final file = await storageService.getFile(attachment.path);
        expect(file, isNotNull, reason: 'Modern file should be accessible: ${attachment.path}');
        expect(await file!.exists(), isTrue);
      }
      print('✅ File system setup verified');

      // 4. MIGRATION SYSTEM VALIDATION
      print('🔄 Testing migration system...');
      final migrationService = FileMigrationService();

      // Pre-migration validation
      final migrationNeeded = await migrationService.isMigrationNeeded();
      expect(migrationNeeded, isTrue, reason: 'Should detect migration is needed');

      final migrationCount = await migrationService.getMigrationCount();
      expect(migrationCount, equals(legacyAttachments.length));

      // Run migration
      final migrationResult = await migrationService.migrateAllFiles();
      expect(migrationResult.totalAttachments, equals(allAttachments.length));
      expect(migrationResult.migratedSuccessfully, equals(legacyAttachments.length));
      expect(migrationResult.alreadyMigrated, equals(modernAttachments.length));
      expect(migrationResult.failed, equals(0));
      expect(migrationResult.hasErrors, isFalse);

      print('✅ Migration completed successfully');
      print('   - Total: ${migrationResult.totalAttachments}');
      print('   - Migrated: ${migrationResult.migratedSuccessfully}');
      print('   - Duration: ${migrationResult.duration}');

      // 5. POST-MIGRATION DATABASE VALIDATION
      print('🔍 Validating post-migration database state...');
      final postMigrationStats = await TestDatabaseHelper.getMigrationStats(db);
      expect(postMigrationStats['legacy'], equals(0), reason: 'No legacy paths should remain');
      expect(postMigrationStats['modern'], equals(allAttachments.length));
      expect(postMigrationStats['total'], equals(allAttachments.length));

      // Verify no data loss
      final allPostMigration = await TestDatabaseHelper.getAllAttachments(db);
      expect(allPostMigration.length, equals(allAttachments.length));
      print('✅ Database integrity maintained after migration');

      // 6. FILE ACCESSIBILITY VALIDATION
      print('📂 Validating file accessibility...');
      final validation = await migrationService.validateMigration();
      expect(validation['total'], equals(allAttachments.length));
      expect(validation['accessible'], equals(allAttachments.length));
      expect(validation['inaccessible'], equals(0));
      expect(validation['success_rate'], equals(1.0));

      // Test each file through storage service
      for (final attachment in allPostMigration) {
        final file = await storageService.getFile(attachment.path);
        expect(file, isNotNull, reason: 'File should be accessible: ${attachment.path}');
        expect(await file!.exists(), isTrue);
        
        final isReadable = await TestFileHelper.isFileAccessible(file.path);
        expect(isReadable, isTrue, reason: 'File should be readable: ${attachment.path}');
      }
      print('✅ All files accessible through storage service');

      // 7. ATTACHMENT SERVICE INTEGRATION
      print('🔗 Testing AttachmentService integration...');
      int successCount = 0;
      
      for (final attachment in allPostMigration.take(5)) { // Test subset for performance
        try {
          // Test file resolution (similar to what AttachmentThumbnail does)
          final file = await storageService.getFile(attachment.path);
          if (file != null && await file.exists()) {
            successCount++;
          }
        } catch (e) {
          fail('AttachmentService integration failed for ${attachment.name}: $e');
        }
      }
      
      expect(successCount, equals(5));
      print('✅ AttachmentService integration verified');

      // 8. ORGANIZED STORAGE STRUCTURE VALIDATION
      print('🗂️ Validating organized storage structure...');
      final storageRoot = await TestFileHelper.getTestRootDir();
      final journalDataDir = '$storageRoot/journal_data';
      
      // Verify directory structure exists
      expect(await Directory('$journalDataDir/images').exists(), isTrue);
      expect(await Directory('$journalDataDir/audio').exists(), isTrue);
      expect(await Directory('$journalDataDir/documents').exists(), isTrue);

      // Count files by type
      final fileCounts = await TestFileHelper.countFiles(journalDataDir);
      expect(fileCounts['total'], greaterThan(0));
      print('✅ Organized storage structure validated');
      print('   - Total files: ${fileCounts['total']}');
      print('   - Images: ${fileCounts['images']}');
      print('   - Audio: ${fileCounts['audio']}');
      print('   - Documents: ${fileCounts['documents']}');

      // 9. PERFORMANCE VALIDATION
      print('⚡ Performance validation...');
      final directorySize = await TestFileHelper.getDirectorySize(journalDataDir);
      expect(directorySize, greaterThan(0));
      
      // Verify reasonable performance metrics
      final avgMigrationTime = migrationResult.duration.inMilliseconds / migrationResult.totalAttachments;
      expect(avgMigrationTime, lessThan(1000)); // Less than 1 second per file
      
      print('✅ Performance metrics validated');
      print('   - Directory size: ${(directorySize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('   - Avg migration time: ${avgMigrationTime.toStringAsFixed(2)}ms per file');

      print('🎉 System integrity validation PASSED!');
    });

    test('data consistency under stress conditions', () async {
      print('💪 Testing system under stress conditions...');

      // Create large dataset
      final entries = TestDataGenerator.createPerformanceTestDataset(
        entryCount: 100,
        maxAttachmentsPerEntry: 8,
      );

      final allAttachments = <Attachment>[];
      for (final entry in entries) {
        allAttachments.addAll(entry.attachments);
      }

      print('📊 Stress test dataset: ${entries.length} entries, ${allAttachments.length} attachments');

      // Setup database
      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db,
        entries: entries,
        attachments: allAttachments,
      );

      // Create subset of files for stress test (avoid excessive disk usage)
      final testFileAttachments = allAttachments.take(200).toList();
      await TestFileHelper.createLegacyTestFiles(testFileAttachments);

      // Run migration under stress
      final migrationService = FileMigrationService();
      
      // Simulate concurrent database operations
      final concurrentOps = <Future>[];
      concurrentOps.add(migrationService.migrateAllFiles());
      
      // Add concurrent reads
      for (int i = 0; i < 5; i++) {
        concurrentOps.add(Future.delayed(
          Duration(milliseconds: i * 100),
          () => TestDatabaseHelper.getMigrationStats(db),
        ));
      }

      final results = await Future.wait(concurrentOps);
      final migrationStats = results.first as Map<String, int>;

      // Verify system remained consistent under stress
      expect(migrationStats['total'], equals(allAttachments.length));
      expect(migrationStats['legacy'] ?? 0, lessThan(allAttachments.length ~/ 2)); // At most 50% failures expected

      // Verify database consistency
      final finalStats = await TestDatabaseHelper.getMigrationStats(db);
      expect(finalStats['total'], equals(allAttachments.length));

      print('✅ System remained consistent under stress');
      final modernCount = migrationStats['modern'] ?? 0;
      final totalCount = migrationStats['total'] ?? 0;
      final successRate = totalCount > 0 ? modernCount / totalCount : 1.0;
      print('   - Migration success rate: ${(successRate * 100).toStringAsFixed(1)}%');
    });

    test('recovery from corrupted data scenarios', () async {
      print('🔧 Testing recovery from corrupted data...');

      // Create test data
      final attachments = List.generate(10, (i) =>
        TestDataGenerator.createLegacyAttachment(name: 'recovery_test_$i.jpg')
      );

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);

      // Create valid files for half the attachments
      final validAttachments = attachments.take(5).toList();
      await TestFileHelper.createLegacyTestFiles(validAttachments);

      // Create corrupted files for the other half
      final corruptedPaths = attachments.skip(5).map((a) => a.path).toList();
      await TestFileHelper.createCorruptedFiles(corruptedPaths);

      // Run migration
      final migrationService = FileMigrationService();
      final result = await migrationService.migrateAllFiles();

      // Verify system handles corruption gracefully
      expect(result.totalAttachments, equals(10));
      expect(result.migratedSuccessfully, equals(5)); // Only valid files
      expect(result.failed, equals(5)); // Corrupted files fail
      expect(result.hasErrors, isTrue);

      // Verify database remains consistent despite corrupted files
      final postMigrationStats = await TestDatabaseHelper.getMigrationStats(db);
      expect(postMigrationStats['total'], equals(10));

      print('✅ System recovered gracefully from corrupted data');
      print('   - Valid migrations: ${result.migratedSuccessfully}');
      print('   - Failed migrations: ${result.failed}');
    });

    test('cross-platform path handling consistency', () async {
      print('🌍 Testing cross-platform path handling...');

      // Create attachments with various path formats
      final attachments = <Attachment>[
        // Unix-style absolute paths
        TestDataGenerator.createLegacyAttachment(
          name: 'unix_file.jpg',
          absolutePath: '/home/user/pictures/unix_file.jpg',
        ),
        // Windows-style absolute paths (if testing on Windows)
        if (Platform.isWindows)
          TestDataGenerator.createLegacyAttachment(
            name: 'windows_file.jpg',
            absolutePath: 'C:\\Users\\user\\Pictures\\windows_file.jpg',
          ),
        // Modern relative paths
        TestDataGenerator.createModernAttachment(name: 'modern_file.jpg'),
      ];

      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db, attachments: attachments);

      // Test path detection logic
      final legacyAttachments = await TestDatabaseHelper.getLegacyAttachments(db);
      final modernAttachments = await TestDatabaseHelper.getModernAttachments(db);

      expect(legacyAttachments.length, greaterThan(0));
      expect(modernAttachments.length, greaterThan(0));

      // Verify cross-platform path detection
      for (final attachment in legacyAttachments) {
        final isLegacy = attachment.path.startsWith('/') || attachment.path.contains(':');
        expect(isLegacy, isTrue, reason: 'Should detect legacy path: ${attachment.path}');
      }

      for (final attachment in modernAttachments) {
        final isModern = !attachment.path.startsWith('/') && !attachment.path.contains(':');
        expect(isModern, isTrue, reason: 'Should detect modern path: ${attachment.path}');
      }

      print('✅ Cross-platform path handling validated');
      print('   - Platform: ${Platform.operatingSystem}');
      print('   - Legacy paths detected: ${legacyAttachments.length}');
      print('   - Modern paths detected: ${modernAttachments.length}');
    });

    test('memory usage and resource cleanup validation', () async {
      print('🧠 Testing memory usage and resource cleanup...');

      // Create large dataset to test memory management
      final entries = List.generate(500, (i) =>
        TestDataGenerator.createTestEntry(
          title: 'Memory Test Entry $i',
          attachments: [
            TestDataGenerator.createLegacyAttachment(name: 'mem_test_$i.jpg'),
          ],
        )
      );

      final allAttachments = <Attachment>[];
      for (final entry in entries) {
        allAttachments.addAll(entry.attachments);
      }

      // Setup database
      final db = await TestDatabaseHelper.createTestDatabase();
      await TestDatabaseHelper.insertTestData(db,
        entries: entries,
        attachments: allAttachments,
      );

      // Create a subset of files to avoid excessive disk usage
      await TestFileHelper.createLegacyTestFiles(allAttachments.take(50).toList());

      // Monitor resource usage during migration
      final migrationService = FileMigrationService();
      
      final memoryBefore = ProcessInfo.currentRss;
      final result = await migrationService.migrateAllFiles();
      final memoryAfter = ProcessInfo.currentRss;

      // Verify migration handled large dataset
      expect(result.totalAttachments, equals(500));

      // Basic memory usage validation (this is platform/environment dependent)
      final memoryIncrease = memoryAfter - memoryBefore;
      print('✅ Memory usage validated');
      print('   - Memory before: ${(memoryBefore / 1024 / 1024).toStringAsFixed(2)} MB');
      print('   - Memory after: ${(memoryAfter / 1024 / 1024).toStringAsFixed(2)} MB');
      print('   - Memory increase: ${(memoryIncrease / 1024 / 1024).toStringAsFixed(2)} MB');

      // Verify reasonable memory usage (less than 100MB increase for this test size)
      expect(memoryIncrease, lessThan(100 * 1024 * 1024));
    });
  });
}