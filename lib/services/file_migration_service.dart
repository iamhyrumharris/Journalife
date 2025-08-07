import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../models/attachment.dart';
import 'local_file_storage_service.dart';
import 'storage_path_utils.dart';
import 'database_service.dart';

/// Migration progress callback
typedef ProgressCallback = void Function(int current, int total, String status);

/// Migration result summary
class MigrationResult {
  final int totalAttachments;
  final int migratedSuccessfully;
  final int alreadyMigrated;
  final int failed;
  final List<String> errors;
  final Duration duration;

  MigrationResult({
    required this.totalAttachments,
    required this.migratedSuccessfully,
    required this.alreadyMigrated,
    required this.failed,
    required this.errors,
    required this.duration,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isComplete => (migratedSuccessfully + alreadyMigrated + failed) == totalAttachments;
  double get successRate => totalAttachments > 0 ? (migratedSuccessfully + alreadyMigrated) / totalAttachments : 1.0;
}

/// Service for migrating existing file references from absolute to relative paths
/// This handles the transition from legacy file storage to the new organized system
class FileMigrationService {
  static final FileMigrationService _instance = FileMigrationService._internal();
  factory FileMigrationService() => _instance;
  FileMigrationService._internal();

  static final LocalFileStorageService _storageService = LocalFileStorageService();
  static final DatabaseService _databaseService = DatabaseService();

  /// Checks if migration is needed by scanning for legacy absolute paths
  Future<bool> isMigrationNeeded() async {
    try {
      final database = await _databaseService.database;
      final result = await database.rawQuery('''
        SELECT COUNT(*) as count FROM attachments 
        WHERE path LIKE '/%' OR path LIKE '_:%'
      ''');
      
      final count = result.first['count'] as int;
      return count > 0;
    } catch (e) {
      debugPrint('Error checking migration status: $e');
      return false;
    }
  }

  /// Gets the count of attachments that need migration
  Future<int> getMigrationCount() async {
    try {
      final database = await _databaseService.database;
      final result = await database.rawQuery('''
        SELECT COUNT(*) as count FROM attachments 
        WHERE path LIKE '/%' OR path LIKE '_:%'
      ''');
      
      return result.first['count'] as int;
    } catch (e) {
      debugPrint('Error getting migration count: $e');
      return 0;
    }
  }

  /// Performs the complete migration process
  Future<MigrationResult> migrateAllFiles({
    ProgressCallback? onProgress,
    bool dryRun = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    
    int totalAttachments = 0;
    int migratedSuccessfully = 0;
    int alreadyMigrated = 0;
    int failed = 0;

    try {
      // Get all attachments that need migration
      final attachmentsToMigrate = await _getLegacyAttachments();
      totalAttachments = attachmentsToMigrate.length;

      onProgress?.call(0, totalAttachments, 'Starting migration...');

      for (int i = 0; i < attachmentsToMigrate.length; i++) {
        final attachment = attachmentsToMigrate[i];
        
        try {
          onProgress?.call(i + 1, totalAttachments, 'Migrating ${attachment.name}...');

          if (_isAlreadyMigrated(attachment)) {
            alreadyMigrated++;
            continue;
          }

          final migrationSuccess = await _migrateAttachment(attachment, dryRun: dryRun);
          
          if (migrationSuccess) {
            migratedSuccessfully++;
          } else {
            failed++;
            errors.add('Failed to migrate ${attachment.name}: Unknown error');
          }
        } catch (e) {
          failed++;
          errors.add('Failed to migrate ${attachment.name}: $e');
          debugPrint('Error migrating attachment ${attachment.id}: $e');
        }
      }

      onProgress?.call(totalAttachments, totalAttachments, 'Migration complete');

    } catch (e) {
      errors.add('Migration process failed: $e');
      debugPrint('Error during migration: $e');
    }

    stopwatch.stop();

    return MigrationResult(
      totalAttachments: totalAttachments,
      migratedSuccessfully: migratedSuccessfully,
      alreadyMigrated: alreadyMigrated,
      failed: failed,
      errors: errors,
      duration: stopwatch.elapsed,
    );
  }

  /// Gets all attachments with legacy absolute paths
  Future<List<Attachment>> _getLegacyAttachments() async {
    try {
      final database = await _databaseService.database;
      final maps = await database.rawQuery('''
        SELECT a.*, e.created_at as entry_created_at
        FROM attachments a
        JOIN entries e ON a.entry_id = e.id
        WHERE a.path LIKE '/%' OR a.path LIKE '_:%'
        ORDER BY a.created_at ASC
      ''');

      return maps.map((map) {
        final attachment = Attachment.fromMap(map);
        // Store entry creation date in metadata for path generation
        if (map['entry_created_at'] != null) {
          final entryCreatedAt = DateTime.parse(map['entry_created_at'] as String);
          attachment.metadata?['entry_created_at'] = entryCreatedAt.toIso8601String();
        }
        return attachment;
      }).toList();
    } catch (e) {
      debugPrint('Error getting legacy attachments: $e');
      return [];
    }
  }

  /// Checks if an attachment is already migrated (has relative path)
  bool _isAlreadyMigrated(Attachment attachment) {
    return !attachment.path.startsWith('/') && !attachment.path.contains(':');
  }

  /// Migrates a single attachment from absolute to relative path
  Future<bool> _migrateAttachment(Attachment attachment, {bool dryRun = false}) async {
    try {
      // Verify source file exists
      final sourceFile = File(attachment.path);
      if (!await sourceFile.exists()) {
        debugPrint('Source file does not exist: ${attachment.path}');
        return false;
      }

      // Get entry creation date for path generation
      DateTime entryDate = attachment.createdAt;
      if (attachment.metadata?['entry_created_at'] != null) {
        entryDate = DateTime.parse(attachment.metadata!['entry_created_at']);
      }

      // Generate new organized path
      final fileExtension = path.extension(attachment.path);
      final fileName = '${attachment.id}$fileExtension';
      
      final relativePath = StoragePathUtils.generateFilePath(
        type: _getStorageType(attachment.type),
        entryDate: entryDate,
        entryId: attachment.entryId,
        filename: fileName,
      );

      if (dryRun) {
        debugPrint('DRY RUN: Would migrate ${attachment.path} -> $relativePath');
        return true;
      }

      // Copy file to new organized location
      final savedPath = await _storageService.saveFile(relativePath, sourceFile);

      // Update database with new path
      final database = await _databaseService.database;
      await database.update(
        'attachments',
        {
          'path': savedPath,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [attachment.id],
      );

      debugPrint('Successfully migrated ${attachment.path} -> $savedPath');
      return true;

    } catch (e) {
      debugPrint('Error migrating attachment ${attachment.id}: $e');
      return false;
    }
  }

  /// Maps AttachmentType to FileStorageType
  FileStorageType _getStorageType(AttachmentType type) {
    switch (type) {
      case AttachmentType.photo:
        return FileStorageType.image;
      case AttachmentType.audio:
        return FileStorageType.audio;
      case AttachmentType.file:
        return FileStorageType.file;
      case AttachmentType.location:
        return FileStorageType.file; // Store as file for now
    }
  }

  /// Validates the migration results by checking file accessibility
  Future<Map<String, dynamic>> validateMigration() async {
    try {
      final database = await _databaseService.database;
      final maps = await database.query('attachments');
      
      int total = 0;
      int accessible = 0;
      int inaccessible = 0;
      final inaccessibleFiles = <String>[];

      for (final map in maps) {
        final attachment = Attachment.fromMap(map);
        total++;

        // Check if file is accessible through storage service
        final file = await _storageService.getFile(attachment.path);
        if (file != null && await file.exists()) {
          accessible++;
        } else {
          inaccessible++;
          inaccessibleFiles.add('${attachment.name} (${attachment.path})');
        }
      }

      return {
        'total': total,
        'accessible': accessible,
        'inaccessible': inaccessible,
        'inaccessible_files': inaccessibleFiles,
        'success_rate': total > 0 ? accessible / total : 1.0,
      };
    } catch (e) {
      debugPrint('Error validating migration: $e');
      return {
        'total': 0,
        'accessible': 0,
        'inaccessible': 0,
        'inaccessible_files': <String>[],
        'success_rate': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// Cleans up old files after successful migration
  /// WARNING: This permanently deletes the original files
  Future<int> cleanupLegacyFiles({
    bool dryRun = true,
    List<String>? specificPaths,
  }) async {
    int deletedCount = 0;
    
    try {
      // Get all attachments to find original paths that are no longer needed
      final database = await _databaseService.database;
      final maps = await database.rawQuery('''
        SELECT DISTINCT metadata FROM attachments 
        WHERE metadata IS NOT NULL AND metadata LIKE '%originalPath%'
      ''');

      for (final map in maps) {
        final metadataString = map['metadata'] as String?;
        if (metadataString == null) continue;

        // Parse metadata to find original path
        // This is a simplified parsing - in a real app you'd use proper JSON parsing
        if (metadataString.contains('originalPath')) {
          final regex = RegExp(r'"originalPath"\s*:\s*"([^"]+)"');
          final match = regex.firstMatch(metadataString);
          
          if (match != null) {
            final originalPath = match.group(1)!;
            
            // Skip if specific paths specified and this isn't one of them
            if (specificPaths != null && !specificPaths.contains(originalPath)) {
              continue;
            }

            final file = File(originalPath);
            if (await file.exists()) {
              if (dryRun) {
                debugPrint('DRY RUN: Would delete $originalPath');
                deletedCount++;
              } else {
                try {
                  await file.delete();
                  debugPrint('Deleted legacy file: $originalPath');
                  deletedCount++;
                } catch (e) {
                  debugPrint('Failed to delete $originalPath: $e');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }

    return deletedCount;
  }

  /// Gets migration statistics for display
  Future<Map<String, dynamic>> getMigrationStats() async {
    try {
      final database = await _databaseService.database;
      
      // Count legacy paths
      final legacyResult = await database.rawQuery('''
        SELECT COUNT(*) as count FROM attachments 
        WHERE path LIKE '/%' OR path LIKE '_:%'
      ''');
      final legacyCount = legacyResult.first['count'] as int;

      // Count migrated paths
      final migratedResult = await database.rawQuery('''
        SELECT COUNT(*) as count FROM attachments 
        WHERE path NOT LIKE '/%' AND path NOT LIKE '_:%'
      ''');
      final migratedCount = migratedResult.first['count'] as int;

      // Count by attachment type
      final typeResult = await database.rawQuery('''
        SELECT type, COUNT(*) as count 
        FROM attachments 
        GROUP BY type
      ''');

      final typeBreakdown = <String, int>{};
      for (final row in typeResult) {
        typeBreakdown[row['type'] as String] = row['count'] as int;
      }

      return {
        'legacy_count': legacyCount,
        'migrated_count': migratedCount,
        'total_count': legacyCount + migratedCount,
        'migration_needed': legacyCount > 0,
        'type_breakdown': typeBreakdown,
      };
    } catch (e) {
      debugPrint('Error getting migration stats: $e');
      return {
        'legacy_count': 0,
        'migrated_count': 0,
        'total_count': 0,
        'migration_needed': false,
        'type_breakdown': <String, int>{},
        'error': e.toString(),
      };
    }
  }
}