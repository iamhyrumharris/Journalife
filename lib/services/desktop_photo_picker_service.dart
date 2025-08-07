import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/attachment.dart';
import 'photo_picker_service.dart';
import 'local_file_storage_service.dart';
import 'storage_path_utils.dart';

/// Desktop implementation of PhotoPickerService using file_selector
/// Supports macOS, Windows, and Linux platforms with organized file storage
class DesktopPhotoPickerService implements PhotoPickerService {
  static const Uuid _uuid = Uuid();
  static final LocalFileStorageService _storageService = LocalFileStorageService();

  /// Image file type group with comprehensive extension support
  static const XTypeGroup _imageTypeGroup = XTypeGroup(
    label: 'Images',
    extensions: ['jpg', 'jpeg', 'png', 'heic', 'gif', 'bmp', 'webp', 'tiff', 'ico'],
  );

  @override
  bool get supportsCameraCapture => false; // Flutter plugin limitation, not platform

  @override
  String get selectPhotoLabel => 'Choose Image File';

  @override
  String get selectMultiplePhotosLabel => 'Select Image Files';

  @override
  Future<Attachment?> capturePhoto(String entryId) async {
    // Camera capture not supported through Flutter plugins on desktop
    return null;
  }

  @override
  Future<Attachment?> selectPhoto(String entryId) async {
    try {
      final initialDir = await _getInitialDirectory();

      final XFile? file = await openFile(
        acceptedTypeGroups: [_imageTypeGroup],
        initialDirectory: initialDir,
      );

      if (file != null) {
        return await _createImageAttachment(file, entryId);
      }
    } catch (e) {
      debugPrint('Error selecting photo on desktop: $e');
    }
    return null;
  }

  @override
  Future<List<Attachment>> selectMultiplePhotos(String entryId) async {
    try {
      final initialDir = await _getInitialDirectory();

      final List<XFile> files = await openFiles(
        acceptedTypeGroups: [_imageTypeGroup],
        initialDirectory: initialDir,
      );

      final List<Attachment> attachments = [];
      for (final file in files) {
        final attachment = await _createImageAttachment(file, entryId);
        if (attachment != null) {
          attachments.add(attachment);
        }
      }
      
      return attachments;
    } catch (e) {
      debugPrint('Error selecting multiple photos on desktop: $e');
      return [];
    }
  }

  /// Creates an Attachment from an XFile and saves it to organized storage
  Future<Attachment?> _createImageAttachment(XFile file, String entryId) async {
    try {
      final File sourceFile = File(file.path);
      
      // Verify the file exists and is readable
      if (!await sourceFile.exists()) {
        debugPrint('Selected file does not exist: ${file.path}');
        return null;
      }

      final int fileSize = await sourceFile.length();
      final String originalFileName = path.basename(file.path);
      final String extension = path.extension(file.path).toLowerCase();
      final String attachmentId = _uuid.v4();
      final DateTime attachmentDate = DateTime.now();

      // Generate a unique filename using attachment ID to avoid conflicts
      final String uniqueFileName = '$attachmentId$extension';
      
      // Generate organized storage path: images/yyyy/mm/dd/entryId/filename
      final String relativePath = StoragePathUtils.generateFilePath(
        type: FileStorageType.image,
        entryDate: attachmentDate,
        entryId: entryId,
        filename: uniqueFileName,
      );
      
      // Copy file to organized storage
      final String savedPath = await _storageService.saveFile(relativePath, sourceFile);

      // Basic MIME type detection based on extension
      final String mimeType = _getMimeTypeFromExtension(extension);

      return Attachment(
        id: attachmentId,
        entryId: entryId,
        type: AttachmentType.photo,
        name: originalFileName, // Keep original name for display
        path: savedPath, // Store relative path
        size: fileSize,
        mimeType: mimeType,
        createdAt: attachmentDate,
        metadata: {
          'originalPath': file.path,
          'storageType': 'organized',
          'platform': 'desktop',
          'extension': extension.replaceFirst('.', ''),
        },
      );
    } catch (e) {
      debugPrint('Error creating image attachment from desktop file: $e');
      return null;
    }
  }
  
  /// Gets MIME type from file extension
  static String _getMimeTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.bmp':
        return 'image/bmp';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.tiff':
      case '.tif':
        return 'image/tiff';
      default:
        return 'image/unknown';
    }
  }

  /// Gets a reasonable initial directory for file selection
  /// Defaults to user's Pictures directory if available, otherwise null
  Future<String?> _getInitialDirectory() async {
    try {
      if (Platform.isMacOS) {
        // Try common macOS Pictures directory
        final picturesDir = Directory('/Users/${Platform.environment['USER']}/Pictures');
        if (await picturesDir.exists()) {
          return picturesDir.path;
        }
      } else if (Platform.isWindows) {
        // Try common Windows Pictures directory
        final picturesDir = Directory('${Platform.environment['USERPROFILE']}\\Pictures');
        if (await picturesDir.exists()) {
          return picturesDir.path;
        }
      } else if (Platform.isLinux) {
        // Try common Linux Pictures directory
        final picturesDir = Directory('${Platform.environment['HOME']}/Pictures');
        if (await picturesDir.exists()) {
          return picturesDir.path;
        }
      }
    } catch (e) {
      debugPrint('Could not determine initial directory: $e');
    }
    return null; // Let the system choose default
  }
}