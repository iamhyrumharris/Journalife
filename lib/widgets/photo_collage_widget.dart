import 'dart:io';
import 'package:flutter/material.dart';
import '../models/attachment.dart';
import '../services/local_file_storage_service.dart';

class PhotoCollageWidget extends StatefulWidget {
  final List<Attachment> photos;
  final Function(int index) onPhotoTap;
  final double spacing;

  const PhotoCollageWidget({
    super.key,
    required this.photos,
    required this.onPhotoTap,
    this.spacing = 4.0,
  });

  @override
  State<PhotoCollageWidget> createState() => _PhotoCollageWidgetState();
}

class _PhotoCollageWidgetState extends State<PhotoCollageWidget> {
  final Map<String, Future<File?>> _fileCache = {};
  final Map<String, File?> _resolvedFiles = {};

  @override
  void initState() {
    super.initState();
    _preloadImages();
  }

  @override
  void didUpdateWidget(PhotoCollageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if the photo list actually changed
    if (!_photosAreEqual(oldWidget.photos, widget.photos)) {
      _preloadImages();
    }
  }

  bool _photosAreEqual(List<Attachment> oldPhotos, List<Attachment> newPhotos) {
    if (oldPhotos.length != newPhotos.length) return false;
    for (int i = 0; i < oldPhotos.length; i++) {
      if (oldPhotos[i].id != newPhotos[i].id || oldPhotos[i].path != newPhotos[i].path) {
        return false;
      }
    }
    return true;
  }

  void _preloadImages() {
    for (final photo in widget.photos) {
      if (!_fileCache.containsKey(photo.id)) {
        _fileCache[photo.id] = _resolveAttachmentFile(photo);
        _fileCache[photo.id]!.then((file) {
          if (mounted) {
            setState(() {
              _resolvedFiles[photo.id] = file;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildCollageLayout(),
      ),
    );
  }

  Widget _buildCollageLayout() {
    switch (widget.photos.length) {
      case 1:
        return _buildSinglePhoto();
      case 2:
        return _buildTwoPhotos();
      case 3:
        return _buildThreePhotos();
      default:
        return _buildFourPlusPhotos();
    }
  }

  Widget _buildSinglePhoto() {
    return AspectRatio(
      aspectRatio: 4 / 3, // Changed to 4:3 for better visual appeal
      child: GestureDetector(
        onTap: () => widget.onPhotoTap(0),
        child: _buildPhotoThumbnail(widget.photos[0]),
      ),
    );
  }

  Widget _buildTwoPhotos() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onPhotoTap(0),
              child: _buildPhotoThumbnail(widget.photos[0]),
            ),
          ),
          SizedBox(width: widget.spacing),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onPhotoTap(1),
              child: _buildPhotoThumbnail(widget.photos[1]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreePhotos() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () => widget.onPhotoTap(0),
              child: _buildPhotoThumbnail(widget.photos[0]),
            ),
          ),
          SizedBox(width: widget.spacing),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(1),
                    child: _buildPhotoThumbnail(widget.photos[1]),
                  ),
                ),
                SizedBox(height: widget.spacing),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(2),
                    child: _buildPhotoThumbnail(widget.photos[2]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourPlusPhotos() {
    final hasMorePhotos = widget.photos.length > 4;
    final displayPhotos = widget.photos.take(4).toList();
    
    return AspectRatio(
      aspectRatio: 1.0, // Square grid for 4 photos
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(0),
                    child: _buildPhotoThumbnail(displayPhotos[0]),
                  ),
                ),
                SizedBox(width: widget.spacing),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(1),
                    child: _buildPhotoThumbnail(displayPhotos[1]),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: widget.spacing),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(2),
                    child: _buildPhotoThumbnail(displayPhotos[2]),
                  ),
                ),
                SizedBox(width: widget.spacing),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(3),
                    child: hasMorePhotos
                        ? _buildMorePhotosIndicator(displayPhotos[3])
                        : _buildPhotoThumbnail(displayPhotos[3]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(Attachment photo) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildPhotoContent(photo),
      ),
    );
  }

  Widget _buildPhotoContent(Attachment photo) {
    // Check if we have a resolved file in cache
    final resolvedFile = _resolvedFiles[photo.id];
    
    if (resolvedFile != null) {
      // File is loaded and ready
      return Image.file(
        resolvedFile,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    } else if (_fileCache.containsKey(photo.id)) {
      // File is still loading
      return _buildLoadingWidget();
    } else {
      // File not found or error
      return _buildPlaceholder();
    }
  }

  Widget _buildMorePhotosIndicator(Attachment photo) {
    final remainingCount = widget.photos.length - 3;
    
    return Stack(
      children: [
        _buildPhotoThumbnail(photo),
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '+$remainingCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.image,
        color: Colors.grey,
        size: 48,
      ),
    );
  }

  /// Resolves attachment path to File, handling both relative and absolute paths
  static final LocalFileStorageService _storageService = LocalFileStorageService();
  
  Future<File?> _resolveAttachmentFile(Attachment attachment) async {
    try {
      // Check if it's already an absolute path (legacy)
      if (attachment.path.startsWith('/') || attachment.path.contains(':')) {
        final file = File(attachment.path);
        final exists = await file.exists();
        return exists ? file : null;
      }

      // Otherwise, it's a relative path - resolve through storage service
      final resolvedFile = await _storageService.getFile(attachment.path);
      
      if (resolvedFile != null) {
        final exists = await resolvedFile.exists();
        return exists ? resolvedFile : null;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error resolving attachment file: $e');
      return null;
    }
  }
}