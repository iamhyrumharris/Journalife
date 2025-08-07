import 'dart:io';
import 'photo_picker_service.dart';
import 'mobile_photo_picker_service.dart';
import 'desktop_photo_picker_service.dart';

/// Factory for creating platform-appropriate PhotoPickerService instances
class PhotoPickerServiceFactory {
  static PhotoPickerService? _instance;

  /// Creates and returns a platform-specific PhotoPickerService instance
  /// Uses singleton pattern for efficiency
  static PhotoPickerService create() {
    return _instance ??= _createPlatformService();
  }

  /// Creates the appropriate service based on the current platform
  static PhotoPickerService _createPlatformService() {
    if (Platform.isIOS || Platform.isAndroid) {
      return MobilePhotoPickerService();
    } else {
      // Desktop platforms: macOS, Windows, Linux
      return DesktopPhotoPickerService();
    }
  }

  /// Clears the cached instance (useful for testing)
  static void reset() {
    _instance = null;
  }

  /// Returns true if the current platform is mobile (iOS/Android)
  static bool get isMobilePlatform => Platform.isIOS || Platform.isAndroid;

  /// Returns true if the current platform is desktop (macOS/Windows/Linux)
  static bool get isDesktopPlatform => !isMobilePlatform;

  /// Returns a human-readable platform name
  static String get platformName {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}