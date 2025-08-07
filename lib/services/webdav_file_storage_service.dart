import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'file_storage_service.dart';
import '../models/sync_config.dart';

/// WebDAV implementation of FileStorageService for remote file operations
class WebDAVFileStorageService implements FileStorageService {
  final webdav.Client _client;
  final SyncConfig _config;

  WebDAVFileStorageService(this._client, this._config);

  @override
  Future<String> saveFile(String relativePath, File sourceFile) async {
    final remotePath = _config.getAttachmentPath(relativePath);

    // Ensure parent directories exist
    await _ensureDirectoryExists(path.dirname(remotePath));

    // Upload the file
    final bytes = await sourceFile.readAsBytes();
    await _client.write(remotePath, bytes);

    return relativePath;
  }

  @override
  Future<File?> getFile(String relativePath) async {
    try {
      final remotePath = _config.getAttachmentPath(relativePath);

      // Create temporary local file
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        path.join(tempDir.path, 'webdav_temp_${path.basename(relativePath)}'),
      );

      // Download from WebDAV
      final bytes = await _client.read(remotePath);
      await tempFile.writeAsBytes(bytes);

      return tempFile;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> deleteFile(String relativePath) async {
    try {
      final remotePath = _config.getAttachmentPath(relativePath);
      await _client.remove(remotePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> getAbsolutePath(String relativePath) async {
    // Return the WebDAV URL path
    return _config.getAttachmentPath(relativePath);
  }

  @override
  Future<bool> fileExists(String relativePath) async {
    try {
      final remotePath = _config.getAttachmentPath(relativePath);

      // Try to get file info
      await _client.read(remotePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int?> getFileSize(String relativePath) async {
    try {
      final remotePath = _config.getAttachmentPath(relativePath);

      // For webdav_client, we need to read the file to get its size
      final bytes = await _client.read(remotePath);
      return bytes.length;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> deleteEntryFiles(String entryId, DateTime entryDate) async {
    try {
      // Get the directory path for this entry's files
      final entryPath = _getEntryPath(entryId, entryDate);

      // For now, just try to delete the directory
      // TODO: Implement proper file listing when webdav_client supports it
      try {
        await _client.remove(entryPath);
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Future<StorageInfo> getStorageInfo() async {
    // TODO: Implement proper storage info when webdav_client supports directory listing
    return const StorageInfo(totalSizeBytes: 0, fileCount: 0, sizeByType: {});
  }

  @override
  Future<int> cleanupOrphanedFiles(Set<String> referencedPaths) async {
    // TODO: Implement cleanup when webdav_client supports directory listing
    return 0;
  }

  /// Ensures that a directory exists on the WebDAV server
  Future<void> _ensureDirectoryExists(String dirPath) async {
    try {
      await _client.mkdir(dirPath);
    } catch (e) {
      // Directory might already exist, that's okay
      // TODO: Add proper directory existence check when webdav_client supports it
    }
  }

  /// Gets the WebDAV path for a specific entry's files using organized date structure
  String _getEntryPath(String entryId, DateTime entryDate) {
    return _config.getEntryAttachmentDir(entryId, entryDate);
  }

  /// Gets the WebDAV path for a specific entry attachment by type
  String _getEntryAttachmentPath(String entryId, DateTime entryDate, String filename, String extension) {
    // Use the organized path methods from SyncConfig based on file type
    final lowerExt = extension.toLowerCase();
    
    if (_isImageExtension(lowerExt)) {
      return _config.getPhotoPath(entryId, entryDate, filename);
    } else if (_isAudioExtension(lowerExt)) {
      return _config.getAudioPath(entryId, entryDate, filename);
    } else {
      return _config.getEntryAttachmentPath(entryId, entryDate, filename);
    }
  }

  /// Checks if extension is an image type
  bool _isImageExtension(String extension) {
    const imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'};
    return imageExts.contains(extension);
  }

  /// Checks if extension is an audio type  
  bool _isAudioExtension(String extension) {
    const audioExts = {'.mp3', '.wav', '.m4a', '.aac', '.ogg'};
    return audioExts.contains(extension);
  }

  /// Categorizes files by their extension
  String _getCategoryForExtension(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
        return 'images';
      case '.mp3':
      case '.wav':
      case '.m4a':
      case '.aac':
      case '.ogg':
        return 'audio';
      case '.mp4':
      case '.mov':
      case '.avi':
      case '.mkv':
        return 'video';
      case '.pdf':
      case '.doc':
      case '.docx':
      case '.txt':
      case '.rtf':
        return 'documents';
      default:
        return 'other';
    }
  }
}
