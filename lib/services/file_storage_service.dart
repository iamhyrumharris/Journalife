import 'dart:io';

/// Abstract interface for file storage operations
/// Supports both local and cloud storage implementations
abstract class FileStorageService {
  /// Saves a file to storage using a relative path
  /// Returns the relative path where the file was saved
  Future<String> saveFile(String relativePath, File sourceFile);
  
  /// Retrieves a file from storage using its relative path
  /// Returns null if file doesn't exist
  Future<File?> getFile(String relativePath);
  
  /// Deletes a file from storage using its relative path
  /// Returns true if successful, false if file didn't exist
  Future<bool> deleteFile(String relativePath);
  
  /// Gets the absolute path for a relative path
  /// Used for compatibility with existing code that needs absolute paths
  Future<String> getAbsolutePath(String relativePath);
  
  /// Checks if a file exists at the given relative path
  Future<bool> fileExists(String relativePath);
  
  /// Gets the size of a file in bytes
  /// Returns null if file doesn't exist
  Future<int?> getFileSize(String relativePath);
  
  /// Deletes all files for a specific entry
  /// Used when an entry is deleted
  Future<bool> deleteEntryFiles(String entryId, DateTime entryDate);
  
  /// Gets storage usage information
  Future<StorageInfo> getStorageInfo();
  
  /// Cleans up orphaned files that are no longer referenced
  Future<int> cleanupOrphanedFiles(Set<String> referencedPaths);
}

/// Information about storage usage
class StorageInfo {
  final int totalSizeBytes;
  final int fileCount;
  final Map<String, int> sizeByType; // e.g., {'images': 1024000, 'files': 512000}
  
  const StorageInfo({
    required this.totalSizeBytes,
    required this.fileCount,
    required this.sizeByType,
  });
  
  String get formattedTotalSize {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    if (totalSizeBytes < 1024 * 1024 * 1024) return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}