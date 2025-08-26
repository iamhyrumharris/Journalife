import 'dart:typed_data';

class CachedImage {
  final String path;
  final Uint8List? thumbnailData;
  final DateTime cachedAt;
  final int sizeInBytes;

  const CachedImage({
    required this.path,
    this.thumbnailData,
    required this.cachedAt,
    required this.sizeInBytes,
  });

  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(cachedAt);
    return difference.inHours > 24;
  }
}

class ImageCacheStats {
  final int totalImages;
  final int totalSizeInBytes;
  final DateTime lastCleanup;

  const ImageCacheStats({
    required this.totalImages,
    required this.totalSizeInBytes,
    required this.lastCleanup,
  });

  double get sizeInMB => totalSizeInBytes / (1024 * 1024);
}