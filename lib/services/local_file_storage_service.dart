import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'file_storage_service.dart';
import 'storage_path_utils.dart';

/// Local file system implementation of FileStorageService
/// Stores files in organized directory structure: app_documents/journal_data/media/
class LocalFileStorageService implements FileStorageService {
  static const String _journalDataDir = 'journal_data';
  static const String _mediaDir = 'media';
  
  Directory? _baseDirectory;
  Directory? _mediaDirectory;
  
  /// Gets the base journal data directory
  Future<Directory> _getBaseDirectory() async {
    if (_baseDirectory != null) return _baseDirectory!;
    
    final appDocuments = await getApplicationDocumentsDirectory();
    _baseDirectory = Directory(path.join(appDocuments.path, _journalDataDir));
    
    if (!await _baseDirectory!.exists()) {
      await _baseDirectory!.create(recursive: true);
    }
    
    return _baseDirectory!;
  }
  
  /// Gets the media storage directory
  Future<Directory> _getMediaDirectory() async {
    if (_mediaDirectory != null) return _mediaDirectory!;
    
    final baseDir = await _getBaseDirectory();
    _mediaDirectory = Directory(path.join(baseDir.path, _mediaDir));
    
    if (!await _mediaDirectory!.exists()) {
      await _mediaDirectory!.create(recursive: true);
    }
    
    return _mediaDirectory!;
  }
  
  @override
  Future<String> saveFile(String relativePath, File sourceFile) async {
    debugPrint('💾 LocalFileStorageService.saveFile() starting...');
    debugPrint('Relative path: $relativePath');
    debugPrint('Source file: ${sourceFile.path}');
    
    // Validate path safety
    if (!StoragePathUtils.isPathSafe(relativePath)) {
      debugPrint('❌ Unsafe path rejected: $relativePath');
      throw ArgumentError('Unsafe path: $relativePath');
    }
    debugPrint('✓ Path safety validated');
    
    try {
      // Verify source file exists and get its properties
      if (!await sourceFile.exists()) {
        debugPrint('❌ Source file does not exist: ${sourceFile.path}');
        throw FileSystemException('Source file does not exist', sourceFile.path);
      }
      
      final sourceSize = await sourceFile.length();
      debugPrint('✓ Source file verified: ${sourceSize} bytes');
      
      final mediaDir = await _getMediaDirectory();
      debugPrint('Media directory: ${mediaDir.path}');
      
      final targetFile = File(path.join(mediaDir.path, relativePath));
      debugPrint('Target file: ${targetFile.path}');
      
      // Create parent directories if they don't exist
      final targetDirectory = targetFile.parent;
      debugPrint('Target directory: ${targetDirectory.path}');
      
      if (!await targetDirectory.exists()) {
        debugPrint('Creating target directory...');
        await targetDirectory.create(recursive: true);
        debugPrint('✓ Target directory created');
      } else {
        debugPrint('✓ Target directory already exists');
      }
      
      // Copy the source file to target location
      debugPrint('🔄 Copying file...');
      await sourceFile.copy(targetFile.path);
      debugPrint('✓ File copied successfully');
      
      // Verify the copy
      if (await targetFile.exists()) {
        final targetSize = await targetFile.length();
        debugPrint('✓ Target file verified: ${targetSize} bytes');
        
        if (targetSize == sourceSize) {
          debugPrint('✅ File copy successful and verified!');
        } else {
          debugPrint('⚠️ Size mismatch: source ${sourceSize} vs target ${targetSize}');
        }
      } else {
        debugPrint('❌ Target file does not exist after copy');
        throw FileSystemException('File copy failed - target not found', targetFile.path);
      }
      
      debugPrint('Returning relative path: $relativePath');
      return relativePath;
    } catch (e, stackTrace) {
      debugPrint('❌ saveFile() failed: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  @override
  Future<File?> getFile(String relativePath) async {
    debugPrint('🔍 LocalFileStorageService.getFile() starting...');
    debugPrint('Relative path: $relativePath');
    
    if (!StoragePathUtils.isPathSafe(relativePath)) {
      debugPrint('❌ Path safety check failed');
      return null;
    }
    debugPrint('✓ Path safety validated');
    
    try {
      final mediaDir = await _getMediaDirectory();
      debugPrint('Media directory: ${mediaDir.path}');
      
      final file = File(path.join(mediaDir.path, relativePath));
      debugPrint('Full file path: ${file.path}');
      
      final exists = await file.exists();
      debugPrint('File exists: $exists');
      
      if (exists) {
        final size = await file.length();
        debugPrint('✓ File verified: ${size} bytes');
        debugPrint('✅ getFile() successful!');
        return file;
      } else {
        debugPrint('❌ File does not exist at path');
        
        // Check if parent directory exists
        final parentDir = file.parent;
        final parentExists = await parentDir.exists();
        debugPrint('Parent directory exists: $parentExists');
        debugPrint('Parent directory path: ${parentDir.path}');
        
        if (parentExists) {
          debugPrint('Listing parent directory contents:');
          try {
            final contents = await parentDir.list().toList();
            for (final item in contents) {
              debugPrint('  - ${item.path}');
            }
          } catch (e) {
            debugPrint('Failed to list directory contents: $e');
          }
        }
        
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ getFile() failed: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
  
  @override
  Future<bool> deleteFile(String relativePath) async {
    final file = await getFile(relativePath);
    if (file == null) return false;
    
    try {
      await file.delete();
      
      // Clean up empty parent directories
      await _cleanupEmptyDirectories(file.parent);
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<String> getAbsolutePath(String relativePath) async {
    final mediaDir = await _getMediaDirectory();
    return path.join(mediaDir.path, relativePath);
  }
  
  @override
  Future<bool> fileExists(String relativePath) async {
    final file = await getFile(relativePath);
    return file != null;
  }
  
  @override
  Future<int?> getFileSize(String relativePath) async {
    final file = await getFile(relativePath);
    if (file == null) return null;
    
    try {
      return await file.length();
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<bool> deleteEntryFiles(String entryId, DateTime entryDate) async {
    bool allDeleted = true;
    
    // Get all possible entry folder paths
    final entryPaths = StoragePathUtils.getAllEntryPaths(
      entryDate: entryDate,
      entryId: entryId,
    );
    
    final mediaDir = await _getMediaDirectory();
    
    for (final entryPath in entryPaths) {
      final entryDir = Directory(path.join(mediaDir.path, entryPath));
      
      if (await entryDir.exists()) {
        try {
          await entryDir.delete(recursive: true);
          
          // Clean up empty parent directories
          await _cleanupEmptyDirectories(entryDir.parent);
        } catch (e) {
          allDeleted = false;
        }
      }
    }
    
    return allDeleted;
  }
  
  @override
  Future<StorageInfo> getStorageInfo() async {
    final mediaDir = await _getMediaDirectory();
    
    int totalSize = 0;
    int fileCount = 0;
    final Map<String, int> sizeByType = {
      'images': 0,
      'files': 0,
      'audio': 0,
    };
    
    await for (final entity in mediaDir.list(recursive: true)) {
      if (entity is File) {
        try {
          final size = await entity.length();
          totalSize += size;
          fileCount++;
          
          // Determine file type from path
          final relativePath = path.relative(entity.path, from: mediaDir.path);
          final pathInfo = StoragePathUtils.parseStoragePath(relativePath);
          
          if (pathInfo != null) {
            switch (pathInfo.type) {
              case FileStorageType.image:
                sizeByType['images'] = (sizeByType['images'] ?? 0) + size;
                break;
              case FileStorageType.file:
                sizeByType['files'] = (sizeByType['files'] ?? 0) + size;
                break;
              case FileStorageType.audio:
                sizeByType['audio'] = (sizeByType['audio'] ?? 0) + size;
                break;
            }
          }
        } catch (e) {
          // Skip files we can't read
        }
      }
    }
    
    return StorageInfo(
      totalSizeBytes: totalSize,
      fileCount: fileCount,
      sizeByType: sizeByType,
    );
  }
  
  @override
  Future<int> cleanupOrphanedFiles(Set<String> referencedPaths) async {
    final mediaDir = await _getMediaDirectory();
    int deletedCount = 0;
    
    await for (final entity in mediaDir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: mediaDir.path);
        
        // Skip cache files (thumbnails, etc.)
        if (relativePath.startsWith('cache${path.separator}')) {
          continue;
        }
        
        if (!referencedPaths.contains(relativePath)) {
          try {
            await entity.delete();
            deletedCount++;
          } catch (e) {
            // Skip files we can't delete
          }
        }
      }
    }
    
    // Clean up empty directories
    await _cleanupAllEmptyDirectories();
    
    return deletedCount;
  }
  
  /// Recursively cleans up empty directories starting from the given directory
  Future<void> _cleanupEmptyDirectories(Directory directory) async {
    final mediaDir = await _getMediaDirectory();
    
    // Don't delete the media directory itself
    if (directory.path == mediaDir.path) return;
    
    try {
      // Check if directory is empty
      final contents = await directory.list().toList();
      if (contents.isEmpty) {
        await directory.delete();
        
        // Recursively clean up parent directory
        await _cleanupEmptyDirectories(directory.parent);
      }
    } catch (e) {
      // Skip directories we can't access
    }
  }
  
  /// Cleans up all empty directories in the media folder
  Future<void> _cleanupAllEmptyDirectories() async {
    final mediaDir = await _getMediaDirectory();
    
    await for (final entity in mediaDir.list(recursive: true)) {
      if (entity is Directory) {
        try {
          final contents = await entity.list().toList();
          if (contents.isEmpty) {
            await entity.delete();
          }
        } catch (e) {
          // Skip directories we can't access
        }
      }
    }
  }
  
  /// Creates a unique filename if the target already exists
  /// Appends (1), (2), etc. before the extension
  Future<String> _generateUniqueFilename(String relativePath) async {
    final mediaDir = await _getMediaDirectory();
    final targetFile = File(path.join(mediaDir.path, relativePath));
    
    if (!await targetFile.exists()) {
      return relativePath;
    }
    
    final directory = path.dirname(relativePath);
    final filename = path.basenameWithoutExtension(relativePath);
    final extension = path.extension(relativePath);
    
    int counter = 1;
    String uniquePath;
    
    do {
      final uniqueFilename = '$filename ($counter)$extension';
      uniquePath = path.join(directory, uniqueFilename);
      final uniqueFile = File(path.join(mediaDir.path, uniquePath));
      
      if (!await uniqueFile.exists()) {
        return uniquePath;
      }
      
      counter++;
    } while (counter < 1000); // Prevent infinite loop
    
    // Fallback with timestamp if we can't find a unique name
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final timestampFilename = '${filename}_$timestamp$extension';
    return path.join(directory, timestampFilename);
  }
  
  /// Saves a file with automatic unique naming if target exists
  Future<String> saveFileWithUniqueNaming(String relativePath, File sourceFile) async {
    final uniquePath = await _generateUniqueFilename(relativePath);
    return await saveFile(uniquePath, sourceFile);
  }
}