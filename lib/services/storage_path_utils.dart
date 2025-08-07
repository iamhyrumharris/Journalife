import 'package:path/path.dart' as path;

/// Utilities for generating and managing storage paths
/// Implements the flexible directory structure: type/yyyy/mm/dd/entryId/
class StoragePathUtils {
  /// Base directories for different file types
  static const String _imagesDir = 'images';
  static const String _filesDir = 'files';
  static const String _audioDir = 'audio';
  static const String _cacheDir = 'cache';
  static const String _thumbnailsDir = 'thumbnails';
  
  /// Generates a relative path for a file based on type, date, entry ID, and filename
  /// Format: type/yyyy/mm/dd/entryId/filename
  static String generateFilePath({
    required FileStorageType type,
    required DateTime entryDate,
    required String entryId,
    required String filename,
  }) {
    final typeDir = _getTypeDirName(type);
    final dateDir = _formatDatePath(entryDate);
    
    return path.join(typeDir, dateDir, entryId, filename);
  }
  
  /// Generates a relative path for an entry's folder
  /// Format: type/yyyy/mm/dd/entryId/
  static String generateEntryFolderPath({
    required FileStorageType type,
    required DateTime entryDate,
    required String entryId,
  }) {
    final typeDir = _getTypeDirName(type);
    final dateDir = _formatDatePath(entryDate);
    
    return path.join(typeDir, dateDir, entryId);
  }
  
  /// Generates a relative path for a date folder
  /// Format: type/yyyy/mm/dd/
  static String generateDateFolderPath({
    required FileStorageType type,
    required DateTime date,
  }) {
    final typeDir = _getTypeDirName(type);
    final dateDir = _formatDatePath(date);
    
    return path.join(typeDir, dateDir);
  }
  
  /// Generates a path for thumbnails
  /// Format: cache/thumbnails/yyyy/mm/dd/entryId/filename_thumb.ext
  static String generateThumbnailPath({
    required DateTime entryDate,
    required String entryId,
    required String originalFilename,
  }) {
    final dateDir = _formatDatePath(entryDate);
    final thumbnailFilename = _generateThumbnailFilename(originalFilename);
    
    return path.join(_cacheDir, _thumbnailsDir, dateDir, entryId, thumbnailFilename);
  }
  
  /// Extracts entry information from a relative path
  /// Returns null if path doesn't match expected format
  static PathInfo? parseStoragePath(String relativePath) {
    final parts = path.split(relativePath);
    
    // Expected format: type/yyyy/mm/dd/entryId/filename
    if (parts.length < 5) return null;
    
    try {
      final typeStr = parts[0];
      final year = int.parse(parts[1]);
      final month = int.parse(parts[2]);
      final day = int.parse(parts[3]);
      final entryId = parts[4];
      final filename = parts.length > 5 ? parts.sublist(5).join(path.separator) : '';
      
      final type = _parseFileStorageType(typeStr);
      if (type == null) return null;
      
      final date = DateTime(year, month, day);
      
      return PathInfo(
        type: type,
        entryDate: date,
        entryId: entryId,
        filename: filename,
        relativePath: relativePath,
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Gets all possible entry folder paths for a given entry
  /// Used for cleanup operations
  static List<String> getAllEntryPaths({
    required DateTime entryDate,
    required String entryId,
  }) {
    return [
      generateEntryFolderPath(
        type: FileStorageType.image,
        entryDate: entryDate,
        entryId: entryId,
      ),
      generateEntryFolderPath(
        type: FileStorageType.file,
        entryDate: entryDate,
        entryId: entryId,
      ),
      generateEntryFolderPath(
        type: FileStorageType.audio,
        entryDate: entryDate,
        entryId: entryId,
      ),
    ];
  }
  
  /// Formats a date as yyyy/mm/dd path
  static String _formatDatePath(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    
    return path.join(year, month, day);
  }
  
  /// Gets directory name for file storage type
  static String _getTypeDirName(FileStorageType type) {
    switch (type) {
      case FileStorageType.image:
        return _imagesDir;
      case FileStorageType.file:
        return _filesDir;
      case FileStorageType.audio:
        return _audioDir;
    }
  }
  
  /// Parses a directory name back to file storage type
  static FileStorageType? _parseFileStorageType(String dirName) {
    switch (dirName) {
      case _imagesDir:
        return FileStorageType.image;
      case _filesDir:
        return FileStorageType.file;
      case _audioDir:
        return FileStorageType.audio;
      default:
        return null;
    }
  }
  
  /// Generates a thumbnail filename from original filename
  static String _generateThumbnailFilename(String originalFilename) {
    final extension = path.extension(originalFilename);
    final nameWithoutExtension = path.basenameWithoutExtension(originalFilename);
    
    return '${nameWithoutExtension}_thumb$extension';
  }
  
  /// Validates that a relative path is safe (no .. or absolute paths)
  static bool isPathSafe(String relativePath) {
    if (relativePath.startsWith('/') || relativePath.startsWith(path.separator)) {
      return false; // Absolute path
    }
    
    if (relativePath.contains('..')) {
      return false; // Directory traversal attempt
    }
    
    return true;
  }
}

/// File storage type enumeration
enum FileStorageType {
  image,
  file,
  audio,
}

/// Information parsed from a storage path
class PathInfo {
  final FileStorageType type;
  final DateTime entryDate;
  final String entryId;
  final String filename;
  final String relativePath;
  
  const PathInfo({
    required this.type,
    required this.entryDate,
    required this.entryId,
    required this.filename,
    required this.relativePath,
  });
  
  @override
  String toString() {
    return 'PathInfo(type: $type, date: $entryDate, entryId: $entryId, filename: $filename)';
  }
}