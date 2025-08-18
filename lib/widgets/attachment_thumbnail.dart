import 'dart:io';
import 'package:flutter/material.dart';
import '../models/attachment.dart';
import '../services/local_file_storage_service.dart';

/// Reusable thumbnail widget for displaying attachment images
/// Supports both relative paths (new storage system) and absolute paths (legacy)
class AttachmentThumbnail extends StatelessWidget {
  final Attachment attachment;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final Widget? placeholder;
  final bool showTypeIcon;

  const AttachmentThumbnail({
    super.key,
    required this.attachment,
    this.width = 80,
    this.height = 80,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.showTypeIcon = true,
  });

  static final LocalFileStorageService _storageService = LocalFileStorageService();
  
  // Simple cache for resolved file paths to avoid repeated file system operations
  static final Map<String, File?> _fileCache = <String, File?>{};
  static const int _maxCacheSize = 200; // Limit cache size to prevent memory bloat

  @override
  Widget build(BuildContext context) {
    // Handle non-photo attachments
    if (attachment.type != AttachmentType.photo) {
      return _buildNonPhotoThumbnail(context);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        color: Colors.grey[300],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: _buildImageContent(context),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    // Handle asset paths
    if (attachment.path.startsWith('assets/')) {
      return Image.asset(
        attachment.path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
      );
    }

    // Handle file paths (both absolute legacy and relative new paths)
    return FutureBuilder<File?>(
      future: _resolveAttachmentFile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingPlaceholder(context);
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildPlaceholder(context);
        }

        final file = snapshot.data!;
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
        );
      },
    );
  }

  /// Resolves attachment path to File, handling both relative and absolute paths
  Future<File?> _resolveAttachmentFile() async {
    // Check cache first
    final cacheKey = '${attachment.id}_${attachment.path}';
    if (_fileCache.containsKey(cacheKey)) {
      return _fileCache[cacheKey];
    }

    try {
      File? resolvedFile;
      
      // Check if it's already an absolute path (legacy)
      if (attachment.path.startsWith('/') || attachment.path.contains(':')) {
        final file = File(attachment.path);
        final exists = await file.exists();
        resolvedFile = exists ? file : null;
      } else {
        // Otherwise, it's a relative path - resolve through storage service
        final file = await _storageService.getFile(attachment.path);
        
        if (file != null) {
          final exists = await file.exists();
          resolvedFile = exists ? file : null;
        }
      }

      // Cache the result (even if null to avoid repeated failed lookups)
      _cacheFile(cacheKey, resolvedFile);
      
      return resolvedFile;
    } catch (e) {
      // Log error in debug mode only
      assert(() {
        // Use debugPrint instead of print for production safety
        return true;
      }());
      
      // Cache null result to avoid repeated failed attempts
      _cacheFile(cacheKey, null);
      return null;
    }
  }

  static void _cacheFile(String key, File? file) {
    // Implement simple LRU by removing oldest entries when cache is full
    if (_fileCache.length >= _maxCacheSize) {
      final keysToRemove = _fileCache.keys.take(_maxCacheSize ~/ 4).toList();
      for (final keyToRemove in keysToRemove) {
        _fileCache.remove(keyToRemove);
      }
    }
    _fileCache[key] = file;
  }

  Widget _buildNonPhotoThumbnail(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        color: _getTypeColor().withValues(alpha: 0.1),
      ),
      child: showTypeIcon
          ? Icon(
              _getTypeIcon(),
              color: _getTypeColor(),
              size: width * 0.4,
            )
          : (placeholder ?? _buildPlaceholder(context)),
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (placeholder != null) return placeholder!;

    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        attachment.type == AttachmentType.photo ? Icons.broken_image : _getTypeIcon(),
        color: Colors.grey[400],
        size: width * 0.4,
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (attachment.type) {
      case AttachmentType.photo:
        return Icons.image;
      case AttachmentType.audio:
        return Icons.audiotrack;
      case AttachmentType.file:
        return Icons.insert_drive_file;
      case AttachmentType.location:
        return Icons.location_on;
    }
  }

  Color _getTypeColor() {
    switch (attachment.type) {
      case AttachmentType.photo:
        return Colors.green;
      case AttachmentType.audio:
        return Colors.purple;
      case AttachmentType.file:
        return Colors.blue;
      case AttachmentType.location:
        return Colors.red;
    }
  }
}

/// Specialized thumbnail for timeline entries - smaller and optimized
class TimelineAttachmentThumbnail extends AttachmentThumbnail {
  const TimelineAttachmentThumbnail({
    super.key,
    required super.attachment,
  }) : super(
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          showTypeIcon: true,
        );
}

/// Specialized thumbnail for attachment preview - larger with more detail
class AttachmentPreviewThumbnail extends AttachmentThumbnail {
  const AttachmentPreviewThumbnail({
    super.key,
    required super.attachment,
  }) : super(
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          showTypeIcon: false,
        );
}