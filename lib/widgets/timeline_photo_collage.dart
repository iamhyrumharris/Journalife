import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/attachment.dart';
import '../services/local_file_storage_service.dart';
import '../utils/image_dimensions.dart';

class TimelinePhotoCollage extends StatefulWidget {
  final List<Attachment> photos;
  final Function(int index)? onPhotoTap;
  final double spacing;
  final int maxPhotosToShow;
  final double maxHeight;

  const TimelinePhotoCollage({
    super.key,
    required this.photos,
    this.onPhotoTap,
    this.spacing = 4.0,
    this.maxPhotosToShow = 6,
    this.maxHeight = 300,
  });

  @override
  State<TimelinePhotoCollage> createState() => _TimelinePhotoCollageState();
}

class _TimelinePhotoCollageState extends State<TimelinePhotoCollage> {
  final Map<String, Future<File?>> _fileCache = {};
  final Map<String, File?> _resolvedFiles = {};
  final Map<String, ImageDimensions> _imageDimensions = {};
  
  static final LocalFileStorageService _storageService = LocalFileStorageService();

  @override
  void initState() {
    super.initState();
    _preloadImages();
  }

  @override
  void didUpdateWidget(TimelinePhotoCollage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    final photosToLoad = widget.photos.take(widget.maxPhotosToShow);
    
    for (final photo in photosToLoad) {
      if (!_fileCache.containsKey(photo.id)) {
        _fileCache[photo.id] = _resolveAttachmentFile(photo);
        _fileCache[photo.id]!.then((file) async {
          if (mounted && file != null) {
            final dimensions = await ImageDimensionLoader.loadFromFile(file);
            if (mounted) {
              setState(() {
                _resolvedFiles[photo.id] = file;
                if (dimensions != null) {
                  _imageDimensions[photo.id] = dimensions;
                }
              });
            }
          }
        });
      }
    }
  }

  Future<File?> _resolveAttachmentFile(Attachment attachment) async {
    try {
      if (attachment.path.startsWith('/') || attachment.path.contains(':')) {
        final file = File(attachment.path);
        final exists = await file.exists();
        return exists ? file : null;
      }

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

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final photoCount = widget.photos.length;
    
    if (photoCount <= 3) {
      return _buildSimpleLayout(colorScheme);
    } else {
      return _buildMasonryLayout(colorScheme);
    }
  }

  Widget _buildSimpleLayout(ColorScheme colorScheme) {
    final photoCount = widget.photos.length;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildLayoutForCount(photoCount),
      ),
    );
  }

  Widget _buildLayoutForCount(int count) {
    switch (count) {
      case 1:
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            onTap: widget.onPhotoTap != null ? () => widget.onPhotoTap!(0) : null,
            child: _buildPhotoTile(widget.photos[0], false),
          ),
        );
      case 2:
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onPhotoTap != null ? () => widget.onPhotoTap!(0) : null,
                  child: _buildPhotoTile(widget.photos[0], false),
                ),
              ),
              SizedBox(width: widget.spacing),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onPhotoTap != null ? () => widget.onPhotoTap!(1) : null,
                  child: _buildPhotoTile(widget.photos[1], false),
                ),
              ),
            ],
          ),
        );
      case 3:
        return AspectRatio(
          aspectRatio: 16 / 9,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: widget.onPhotoTap != null ? () => widget.onPhotoTap!(0) : null,
                  child: _buildPhotoTile(widget.photos[0], false),
                ),
              ),
              SizedBox(width: widget.spacing),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onPhotoTap != null ? () => widget.onPhotoTap!(1) : null,
                        child: _buildPhotoTile(widget.photos[1], false),
                      ),
                    ),
                    SizedBox(height: widget.spacing),
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onPhotoTap != null ? () => widget.onPhotoTap!(2) : null,
                        child: _buildPhotoTile(widget.photos[2], false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMasonryLayout(ColorScheme colorScheme) {
    final photosToShow = widget.photos.length.clamp(1, widget.maxPhotosToShow);
    final displayPhotos = widget.photos.take(photosToShow).toList();
    final hasMorePhotos = widget.photos.length > widget.maxPhotosToShow;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: RepaintBoundary(
          child: MasonryGridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: widget.spacing,
            crossAxisSpacing: widget.spacing,
            itemCount: photosToShow,
            itemBuilder: (context, index) {
              final photo = displayPhotos[index];
              final isLastPhoto = index == photosToShow - 1;
              final showOverlay = hasMorePhotos && isLastPhoto;
              
              return RepaintBoundary(
                key: ValueKey(photo.id),
                child: GestureDetector(
                  onTap: widget.onPhotoTap != null ? () => widget.onPhotoTap!(index) : null,
                  child: _buildMasonryPhotoTile(photo, showOverlay),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMasonryPhotoTile(Attachment photo, bool showOverlay) {
    final dimensions = _imageDimensions[photo.id];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            _buildPhotoWithAspectRatio(photo, dimensions),
            if (showOverlay) _buildMorePhotosOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTile(Attachment photo, bool showOverlay) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            _buildPhotoContent(photo),
            if (showOverlay) _buildMorePhotosOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoWithAspectRatio(Attachment photo, ImageDimensions? dimensions) {
    final resolvedFile = _resolvedFiles[photo.id];
    
    final isHeic = photo.path.toLowerCase().endsWith('.heic') || 
                   photo.path.toLowerCase().endsWith('.heif');
    
    if (resolvedFile != null && dimensions != null) {
      if (isHeic) {
        return AspectRatio(
          aspectRatio: dimensions.aspectRatio,
          child: _buildHeicPlaceholder(),
        );
      }
      
      return AspectRatio(
        aspectRatio: dimensions.aspectRatio,
        child: Image.file(
          resolvedFile,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderWithAspectRatio(dimensions);
          },
        ),
      );
    } else if (_fileCache.containsKey(photo.id)) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: _buildLoadingWidget(),
      );
    } else {
      return AspectRatio(
        aspectRatio: 1.0,
        child: _buildPlaceholder(),
      );
    }
  }

  Widget _buildPhotoContent(Attachment photo) {
    final resolvedFile = _resolvedFiles[photo.id];
    
    final isHeic = photo.path.toLowerCase().endsWith('.heic') || 
                   photo.path.toLowerCase().endsWith('.heif');
    
    if (resolvedFile != null) {
      if (isHeic) {
        return _buildHeicPlaceholder();
      }
      
      return Image.file(
        resolvedFile,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    } else if (_fileCache.containsKey(photo.id)) {
      return _buildLoadingWidget();
    } else {
      return _buildPlaceholder();
    }
  }

  Widget _buildMorePhotosOverlay() {
    final remainingCount = widget.photos.length - widget.maxPhotosToShow;
    
    return Container(
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
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeicPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            color: Colors.grey[600],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            'HEIC',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderWithAspectRatio(ImageDimensions dimensions) {
    return AspectRatio(
      aspectRatio: dimensions.aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.image,
          color: Colors.grey,
          size: 32,
        ),
      ),
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
          width: 16,
          height: 16,
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
        size: 32,
      ),
    );
  }
}