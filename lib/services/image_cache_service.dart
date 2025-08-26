import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/image_cache_models.dart';
import '../utils/calendar_constants.dart';

final imageCacheServiceProvider = Provider<ImageCacheService>((ref) {
  return ImageCacheService();
});

class ImageCacheService {
  final Map<String, CachedImage> _cache = {};
  Timer? _cleanupTimer;
  static const int maxCacheSize = 50 * 1024 * 1024; // 50MB

  ImageCacheService() {
    _startPeriodicCleanup();
  }

  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _cleanupCache();
    });
  }

  Future<String?> generateThumbnail(String imagePath) async {
    try {
      return await compute(_generateThumbnailIsolate, imagePath);
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  static Future<String?> _generateThumbnailIsolate(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final thumbnail = img.copyResize(
        image,
        width: CalendarConstants.thumbnailSize,
        height: CalendarConstants.thumbnailSize,
      );

      final thumbnailBytes = img.encodeJpg(
        thumbnail,
        quality: CalendarConstants.thumbnailQuality,
      );

      final tempDir = await getTemporaryDirectory();
      final thumbnailName = '${DateTime.now().millisecondsSinceEpoch}_thumb.jpg';
      final thumbnailPath = '${tempDir.path}/$thumbnailName';
      
      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      return thumbnailPath;
    } catch (e) {
      debugPrint('Error in thumbnail generation isolate: $e');
      return null;
    }
  }

  Future<Uint8List?> getThumbnailData(String imagePath) async {
    if (_cache.containsKey(imagePath)) {
      final cached = _cache[imagePath]!;
      if (!cached.isExpired) {
        return cached.thumbnailData;
      }
    }

    final thumbnailPath = await generateThumbnail(imagePath);
    if (thumbnailPath == null) return null;

    try {
      final file = File(thumbnailPath);
      final bytes = await file.readAsBytes();
      
      _cache[imagePath] = CachedImage(
        path: imagePath,
        thumbnailData: bytes,
        cachedAt: DateTime.now(),
        sizeInBytes: bytes.length,
      );

      _checkCacheSize();
      
      return bytes;
    } catch (e) {
      debugPrint('Error reading thumbnail: $e');
      return null;
    }
  }

  void _checkCacheSize() {
    int totalSize = 0;
    for (final cached in _cache.values) {
      totalSize += cached.sizeInBytes;
    }

    if (totalSize > maxCacheSize) {
      _cleanupCache();
    }
  }

  void _cleanupCache() {
    final keysToRemove = <String>[];

    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    if (_cache.length > 100) {
      final sortedEntries = _cache.entries.toList()
        ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));

      final toRemove = sortedEntries.take(50);
      for (final entry in toRemove) {
        _cache.remove(entry.key);
      }
    }
  }

  Future<void> preloadImagesForMonth(DateTime month, List<String> imagePaths) async {
    for (final path in imagePaths.take(10)) {
      if (!_cache.containsKey(path)) {
        await getThumbnailData(path);
      }
    }
  }

  ImageCacheStats getStats() {
    int totalSize = 0;
    for (final cached in _cache.values) {
      totalSize += cached.sizeInBytes;
    }

    return ImageCacheStats(
      totalImages: _cache.length,
      totalSizeInBytes: totalSize,
      lastCleanup: DateTime.now(),
    );
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cache.clear();
  }
}