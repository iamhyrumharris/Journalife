import '../models/attachment.dart';

/// Abstract service interface for photo picking functionality across platforms
abstract class PhotoPickerService {
  /// Captures a photo using the device camera
  /// Returns null if operation fails or is not supported
  Future<Attachment?> capturePhoto(String entryId);
  
  /// Selects a single photo from gallery/file system
  /// Returns null if operation fails or is cancelled
  Future<Attachment?> selectPhoto(String entryId);
  
  /// Selects multiple photos from gallery/file system
  /// Returns empty list if operation fails or is cancelled
  Future<List<Attachment>> selectMultiplePhotos(String entryId);
  
  /// Whether this platform supports camera capture
  bool get supportsCameraCapture;
  
  /// Display name for single photo selection (platform-specific)
  String get selectPhotoLabel;
  
  /// Display name for multiple photo selection (platform-specific)
  String get selectMultiplePhotosLabel;
}