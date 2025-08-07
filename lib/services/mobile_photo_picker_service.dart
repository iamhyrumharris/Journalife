import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/attachment.dart';
import 'photo_picker_service.dart';
import 'local_file_storage_service.dart';
import 'storage_path_utils.dart';

/// Mobile implementation of PhotoPickerService using image_picker
/// Supports iOS and Android platforms with organized file storage
class MobilePhotoPickerService implements PhotoPickerService {
  static final ImagePicker _imagePicker = ImagePicker();
  static const Uuid _uuid = Uuid();
  static final LocalFileStorageService _storageService = LocalFileStorageService();

  @override
  bool get supportsCameraCapture => true;

  @override
  String get selectPhotoLabel => 'Choose from Gallery';

  @override
  String get selectMultiplePhotosLabel => 'Select Multiple';

  @override
  Future<Attachment?> capturePhoto(String entryId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        return _createImageAttachment(image, entryId);
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
    }
    return null;
  }

  @override
  Future<Attachment?> selectPhoto(String entryId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        return _createImageAttachment(image, entryId);
      }
    } catch (e) {
      debugPrint('Error selecting photo: $e');
    }
    return null;
  }

  @override
  Future<List<Attachment>> selectMultiplePhotos(String entryId) async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      final List<Attachment> attachments = [];
      for (final image in images) {
        final attachment = await _createImageAttachment(image, entryId);
        if (attachment != null) {
          attachments.add(attachment);
        }
      }
      return attachments;
    } catch (e) {
      debugPrint('Error selecting multiple photos: $e');
      return [];
    }
  }

  /// Creates an Attachment from an XFile image and saves it to organized storage
  static Future<Attachment?> _createImageAttachment(XFile image, String entryId) async {
    try {
      debugPrint('📸 Starting photo attachment creation...');
      debugPrint('Source path: ${image.path}');
      debugPrint('Entry ID: $entryId');
      
      final File sourceFile = File(image.path);
      
      // Verify source file exists
      if (!await sourceFile.exists()) {
        debugPrint('❌ Source image file does not exist: ${image.path}');
        return null;
      }
      
      final int fileSize = await sourceFile.length();
      debugPrint('✓ Source file verified: ${fileSize} bytes');
      
      final String originalFileName = path.basename(image.path);
      final String attachmentId = _uuid.v4();
      final DateTime attachmentDate = DateTime.now();
      
      debugPrint('Original filename: $originalFileName');
      debugPrint('Attachment ID: $attachmentId');
      debugPrint('Attachment date: $attachmentDate');
      
      // Generate a unique filename using attachment ID to avoid conflicts
      final String extension = path.extension(originalFileName);
      final String uniqueFileName = '$attachmentId$extension';
      debugPrint('Unique filename: $uniqueFileName');
      
      // Generate organized storage path: images/yyyy/mm/dd/entryId/filename
      final String relativePath = StoragePathUtils.generateFilePath(
        type: FileStorageType.image,
        entryDate: attachmentDate,
        entryId: entryId,
        filename: uniqueFileName,
      );
      debugPrint('Generated relative path: $relativePath');
      
      // Copy file to organized storage
      debugPrint('🔄 Starting file copy operation...');
      final String savedPath = await _storageService.saveFile(relativePath, sourceFile);
      debugPrint('✅ File saved successfully to: $savedPath');
      
      // Verify the saved file exists
      final savedFile = await _storageService.getFile(savedPath);
      if (savedFile != null && await savedFile.exists()) {
        final savedSize = await savedFile.length();
        debugPrint('✓ Saved file verified: ${savedSize} bytes');
        
        if (savedSize != fileSize) {
          debugPrint('⚠️ Size mismatch: original ${fileSize} vs saved ${savedSize}');
        }
      } else {
        debugPrint('❌ Saved file verification failed');
      }
      
      final attachment = Attachment(
        id: attachmentId,
        entryId: entryId,
        type: AttachmentType.photo,
        name: originalFileName, // Keep original name for display
        path: savedPath, // Store relative path
        size: fileSize,
        mimeType: image.mimeType ?? _getMimeTypeFromExtension(extension),
        createdAt: attachmentDate,
        metadata: {
          'originalPath': image.path,
          'storageType': 'organized',
          'platform': 'mobile',
          'extension': extension.replaceFirst('.', ''),
          'relativePath': relativePath,
          'savedPath': savedPath,
        },
      );
      
      debugPrint('🎉 Photo attachment created successfully!');
      debugPrint('Attachment: ${attachment.toString()}');
      
      return attachment;
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating image attachment: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Gets MIME type from file extension as fallback
  static String _getMimeTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.bmp':
        return 'image/bmp';
      default:
        return 'image/unknown';
    }
  }
}