import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import '../models/attachment.dart';
import 'photo_picker_service_factory.dart';

class MediaService {
  static const Uuid _uuid = Uuid();

  // Photo and Image Methods - Now using platform-specific services
  static Future<Attachment?> capturePhoto(String entryId) async {
    final photoService = PhotoPickerServiceFactory.create();
    return await photoService.capturePhoto(entryId);
  }

  static Future<Attachment?> selectPhoto(String entryId) async {
    final photoService = PhotoPickerServiceFactory.create();
    return await photoService.selectPhoto(entryId);
  }

  static Future<List<Attachment>> selectMultiplePhotos(String entryId) async {
    final photoService = PhotoPickerServiceFactory.create();
    return await photoService.selectMultiplePhotos(entryId);
  }

  /// Returns true if camera capture is supported on this platform
  static bool get supportsCameraCapture {
    final photoService = PhotoPickerServiceFactory.create();
    return photoService.supportsCameraCapture;
  }

  /// Returns platform-appropriate label for single photo selection
  static String get selectPhotoLabel {
    final photoService = PhotoPickerServiceFactory.create();
    return photoService.selectPhotoLabel;
  }

  /// Returns platform-appropriate label for multiple photo selection
  static String get selectMultiplePhotosLabel {
    final photoService = PhotoPickerServiceFactory.create();
    return photoService.selectMultiplePhotosLabel;
  }

  // File Picker Methods
  static Future<Attachment?> pickFile(String entryId) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final PlatformFile file = result.files.first;
        
        return Attachment(
          id: _uuid.v4(),
          entryId: entryId,
          type: AttachmentType.file,
          name: file.name,
          path: file.path ?? '',
          size: file.size,
          mimeType: file.extension != null ? 'application/${file.extension}' : null,
          createdAt: DateTime.now(),
          metadata: {
            'extension': file.extension ?? 'unknown',
          },
        );
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
    return null;
  }

  static Future<List<Attachment>> pickMultipleFiles(String entryId) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final List<Attachment> attachments = [];
        
        for (final PlatformFile file in result.files) {
          final attachment = Attachment(
            id: _uuid.v4(),
            entryId: entryId,
            type: AttachmentType.file,
            name: file.name,
            path: file.path ?? '',
            size: file.size,
            mimeType: file.extension != null ? 'application/${file.extension}' : null,
            createdAt: DateTime.now(),
            metadata: {
              'extension': file.extension ?? 'unknown',
            },
          );
          attachments.add(attachment);
        }
        return attachments;
      }
    } catch (e) {
      debugPrint('Error picking multiple files: $e');
    }
    return [];
  }

  // Audio Recording Methods
  static Future<Attachment?> recordAudio(String entryId) async {
    try {
      // This would typically involve showing a recording UI
      // For now, we'll create a placeholder implementation
      
      return Attachment(
        id: _uuid.v4(),
        entryId: entryId,
        type: AttachmentType.audio,
        name: 'Recording ${DateTime.now().millisecondsSinceEpoch}.m4a',
        path: '/path/to/audio/recording.m4a', // Placeholder path
        size: 1024 * 50, // Placeholder size (50KB)
        mimeType: 'audio/m4a',
        createdAt: DateTime.now(),
        metadata: {
          'duration': '30', // Duration in seconds
          'format': 'm4a',
        },
      );
    } catch (e) {
      debugPrint('Error recording audio: $e');
      return null;
    }
  }

  // Location Services Methods
  static Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return {
          'error': 'Location services are disabled.',
        };
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {
            'error': 'Location permissions are denied.',
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return {
          'error': 'Location permissions are permanently denied.',
        };
      }

      // Get current position
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Try to get address from coordinates
      String? locationName;
      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final Placemark place = placemarks.first;
          locationName = _formatPlacemark(place);
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'locationName': locationName ?? 'Unknown Location',
        'timestamp': position.timestamp,
      };
    } catch (e) {
      debugPrint('Error getting location: $e');
      return {
        'error': 'Failed to get current location: $e',
      };
    }
  }

  static String _formatPlacemark(Placemark place) {
    final List<String> parts = [];
    
    if (place.name != null && place.name!.isNotEmpty && place.name != place.street) {
      parts.add(place.name!);
    }
    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    }
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }
    if (place.country != null && place.country!.isNotEmpty) {
      parts.add(place.country!);
    }

    return parts.isNotEmpty ? parts.join(', ') : 'Unknown Location';
  }

  // Permission Methods
  static Future<bool> requestCameraPermission() async {
    // Camera permissions are handled by image_picker automatically
    return true;
  }

  static Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  // Utility Methods
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static IconData getFileIcon(String? mimeType, String? extension) {
    if (mimeType != null) {
      if (mimeType.startsWith('image/')) return Icons.image;
      if (mimeType.startsWith('audio/')) return Icons.audiotrack;
      if (mimeType.startsWith('video/')) return Icons.video_file;
      if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
      if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description;
      if (mimeType.contains('sheet') || mimeType.contains('excel')) return Icons.table_chart;
      if (mimeType.contains('presentation') || mimeType.contains('powerpoint')) return Icons.slideshow;
    }

    if (extension != null) {
      switch (extension.toLowerCase()) {
        case 'pdf': return Icons.picture_as_pdf;
        case 'doc':
        case 'docx': return Icons.description;
        case 'xls':
        case 'xlsx': return Icons.table_chart;
        case 'ppt':
        case 'pptx': return Icons.slideshow;
        case 'txt': return Icons.text_snippet;
        case 'zip':
        case 'rar':
        case '7z': return Icons.archive;
        default: return Icons.insert_drive_file;
      }
    }

    return Icons.insert_drive_file;
  }
}