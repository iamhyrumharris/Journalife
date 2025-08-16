import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/attachment.dart';
import '../services/local_file_storage_service.dart';
import '../utils/image_dimensions.dart';

class PhotoCollageWidget extends StatefulWidget {
  final List<Attachment> photos;
  final Function(int index) onPhotoTap;
  final double spacing;
  final bool isDesktopLayout;
  final int maxPhotosToShow;

  const PhotoCollageWidget({
    super.key,
    required this.photos,
    required this.onPhotoTap,
    this.spacing = 4.0,
    this.isDesktopLayout = false,
    this.maxPhotosToShow = 4,
  });

  @override
  State<PhotoCollageWidget> createState() => _PhotoCollageWidgetState();
}

class _PhotoCollageWidgetState extends State<PhotoCollageWidget> {
  final Map<String, Future<File?>> _fileCache = {};
  final Map<String, File?> _resolvedFiles = {};
  final Map<String, ImageDimensions> _imageDimensions = {};
  double _containerHeight = 0;
  int _calculatedPhotoCount = 0;
  
  // Cache for optimization during resize
  double _lastCalculatedWidth = 0;
  double _lastCalculatedHeight = 0;
  Timer? _resizeDebouncer;

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

  @override
  void dispose() {
    _resizeDebouncer?.cancel();
    super.dispose();
  }

  void _preloadImages() {
    for (final photo in widget.photos) {
      if (!_fileCache.containsKey(photo.id)) {
        _fileCache[photo.id] = _resolveAttachmentFile(photo);
        _fileCache[photo.id]!.then((file) async {
          if (mounted && file != null) {
            // Load image dimensions for masonry layout
            final dimensions = await ImageDimensionLoader.loadFromFile(file);
            setState(() {
              _resolvedFiles[photo.id] = file;
              if (dimensions != null) {
                _imageDimensions[photo.id] = dimensions;
              }
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

    // Simple fixed 2x3 grid for desktop mode
    if (widget.isDesktopLayout) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        child: _buildFixed2x3Grid(colorScheme),
      );
    }

    // Standard mobile/tablet layout
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

  /// Builds a simple fixed 2x3 grid for desktop layout
  Widget _buildFixed2x3Grid(ColorScheme colorScheme) {
    // Fixed dimensions for consistent desktop layout
    const double containerWidth = 300;
    const double containerHeight = 450; // 2:3 aspect ratio

    // Show up to 6 photos in 2x3 grid
    final photosToShow = widget.photos.length.clamp(1, 6);
    final hasMorePhotos = widget.photos.length > 6;
    
    return Container(
      width: containerWidth,
      height: containerHeight,
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
        child: _build2x3GridContent(photosToShow, hasMorePhotos),
      ),
    );
  }

  /// Builds the actual 2x3 grid content
  Widget _build2x3GridContent(int photosToShow, bool hasMorePhotos) {
    return Column(
      children: [
        // Row 1
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridPhoto(0, photosToShow)),
              SizedBox(width: widget.spacing),
              Expanded(child: _buildGridPhoto(1, photosToShow)),
            ],
          ),
        ),
        SizedBox(height: widget.spacing),
        // Row 2
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridPhoto(2, photosToShow)),
              SizedBox(width: widget.spacing),
              Expanded(child: _buildGridPhoto(3, photosToShow)),
            ],
          ),
        ),
        SizedBox(height: widget.spacing),
        // Row 3
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildGridPhoto(4, photosToShow)),
              SizedBox(width: widget.spacing),
              Expanded(child: _buildGridPhoto(5, photosToShow, hasMorePhotos)),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a single photo for the 2x3 grid
  Widget _buildGridPhoto(int index, int photosToShow, [bool showMoreOverlay = false]) {
    // Return empty container if no photo at this index
    if (index >= photosToShow) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    final photo = widget.photos[index];
    final isLastPhoto = index == 5 && showMoreOverlay && widget.photos.length > 6;

    return GestureDetector(
      onTap: () => widget.onPhotoTap(index),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              _buildPhotoContent(photo),
              if (isLastPhoto) _buildMorePhotosOverlayFixed(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the "+N more" overlay for the fixed grid
  Widget _buildMorePhotosOverlayFixed() {
    final remainingCount = widget.photos.length - 6;
    
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

  void _calculateOptimalPhotoCountWithDebounce(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    
    // Skip calculation if dimensions haven't changed significantly
    if ((width - _lastCalculatedWidth).abs() < 10 && 
        (height - _lastCalculatedHeight).abs() < 10) {
      return;
    }
    
    // Cancel existing timer
    _resizeDebouncer?.cancel();
    
    // Debounce the calculation to avoid excessive recalculations during resize
    _resizeDebouncer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        _calculateOptimalPhotoCount(constraints);
        _lastCalculatedWidth = width;
        _lastCalculatedHeight = height;
      }
    });
  }

  void _calculateOptimalPhotoCount(BoxConstraints constraints) {
    final availableHeight = constraints.maxHeight;
    final availableWidth = constraints.maxWidth;
    
    // Validate constraints to prevent division by zero or invalid values
    if (!availableHeight.isFinite || availableHeight <= 0 || 
        !availableWidth.isFinite || availableWidth <= 0) {
      _calculatedPhotoCount = 4; // Default fallback
      return;
    }
    
    final columnWidth = (availableWidth - widget.spacing) / 2; // 2 columns
    
    // Validate column width
    if (!columnWidth.isFinite || columnWidth <= 0) {
      _calculatedPhotoCount = 4; // Default fallback
      return;
    }
    
    // Get dimensions for loaded photos
    final loadedDimensions = <ImageDimensions>[];
    for (final photo in widget.photos) {
      final dimensions = _imageDimensions[photo.id];
      if (dimensions != null) {
        loadedDimensions.add(dimensions);
      }
    }
    
    // Estimate average photo height if we have some dimensions
    double estimatedPhotoHeight = columnWidth; // Default to square
    if (loadedDimensions.isNotEmpty) {
      estimatedPhotoHeight = ImageDimensionLoader.estimateAverageHeight(
        loadedDimensions, 
        columnWidth
      );
    }
    
    // Validate estimated photo height
    if (!estimatedPhotoHeight.isFinite || estimatedPhotoHeight <= 0) {
      estimatedPhotoHeight = columnWidth; // Fallback to square
    }
    
    // Calculate how many photos can fit vertically (with spacing)
    final denominator = estimatedPhotoHeight + widget.spacing;
    if (!denominator.isFinite || denominator <= 0) {
      _calculatedPhotoCount = 4; // Default fallback
      return;
    }
    
    final photosPerColumnDouble = availableHeight / denominator;
    
    // Validate the result before converting to int
    if (!photosPerColumnDouble.isFinite || photosPerColumnDouble < 0) {
      _calculatedPhotoCount = 4; // Default fallback
      return;
    }
    
    final photosPerColumn = photosPerColumnDouble.floor().clamp(1, 20); // Reasonable limits
    final totalPhotos = photosPerColumn * 2; // 2 columns
    
    // Don't exceed available photos and ensure minimum of 2
    _calculatedPhotoCount = totalPhotos.clamp(2, widget.photos.length);
  }

  Widget _buildMasonryLayout(BoxConstraints constraints, ColorScheme colorScheme) {
    final photosToShow = _calculatedPhotoCount;
    final displayPhotos = widget.photos.take(photosToShow).toList();
    final hasMorePhotos = widget.photos.length > photosToShow;
    
    return Container(
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
                  onTap: () => widget.onPhotoTap(index),
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
            _buildPhotoContentWithAspectRatio(photo, dimensions),
            if (showOverlay) _buildMorePhotosOverlay(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPhotoContentWithAspectRatio(Attachment photo, ImageDimensions? dimensions) {
    final resolvedFile = _resolvedFiles[photo.id];
    
    // Check if this is a HEIC file
    final isHeic = photo.path.toLowerCase().endsWith('.heic') || 
                   photo.path.toLowerCase().endsWith('.heif');
    
    if (resolvedFile != null && dimensions != null) {
      // For HEIC files, show a placeholder with message
      if (isHeic) {
        return AspectRatio(
          aspectRatio: dimensions.aspectRatio,
          child: Container(
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
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  'HEIC format',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      
      return AspectRatio(
        aspectRatio: dimensions.aspectRatio,
        child: Image.file(
          resolvedFile,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading image: $error');
            return _buildPlaceholderWithAspectRatio(dimensions);
          },
        ),
      );
    } else if (_fileCache.containsKey(photo.id)) {
      // File is still loading - show placeholder with default aspect ratio
      return AspectRatio(
        aspectRatio: 1.0, // Default to square while loading
        child: _buildLoadingWidget(),
      );
    } else {
      // File not found or error
      return AspectRatio(
        aspectRatio: 1.0, // Default to square for error state
        child: _buildPlaceholder(),
      );
    }
  }
  
  Widget _buildMorePhotosOverlay() {
    final remainingCount = widget.photos.length - _calculatedPhotoCount;
    
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
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
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
          size: 48,
        ),
      ),
    );
  }

  Widget _buildCollageLayout() {
    final photoCount = widget.photos.length;
    
    // In desktop layout, show more photos to fill vertical space
    if (widget.isDesktopLayout) {
      switch (photoCount) {
        case 1:
          return _buildSinglePhotoDesktop();
        case 2:
          return _buildTwoPhotosDesktop();
        case 3:
          return _buildThreePhotosDesktop();
        case 4:
          return _buildFourPhotosDesktop();
        case 5:
          return _buildFivePhotosDesktop();
        case 6:
          return _buildSixPhotosDesktop();
        default:
          if (photoCount > 6) {
            return _buildSixPlusPhotosDesktop();
          } else {
            return _buildFourPhotosDesktop();
          }
      }
    }
    
    // Standard mobile/tablet layouts
    switch (photoCount) {
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

  // Desktop layouts - taller aspect ratio to fill vertical space
  Widget _buildSinglePhotoDesktop() {
    return AspectRatio(
      aspectRatio: 3 / 4, // Taller for desktop
      child: GestureDetector(
        onTap: () => widget.onPhotoTap(0),
        child: _buildPhotoThumbnail(widget.photos[0]),
      ),
    );
  }

  Widget _buildTwoPhotosDesktop() {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onPhotoTap(0),
              child: _buildPhotoThumbnail(widget.photos[0]),
            ),
          ),
          SizedBox(height: widget.spacing),
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

  Widget _buildThreePhotosDesktop() {
    return AspectRatio(
      aspectRatio: 2 / 3, // Even taller for 3 photos
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onPhotoTap(0),
              child: _buildPhotoThumbnail(widget.photos[0]),
            ),
          ),
          SizedBox(height: widget.spacing),
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
    );
  }

  Widget _buildFourPhotosDesktop() {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Column(
        children: [
          Expanded(
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
          ),
          SizedBox(height: widget.spacing),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(2),
                    child: _buildPhotoThumbnail(widget.photos[2]),
                  ),
                ),
                SizedBox(width: widget.spacing),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(3),
                    child: _buildPhotoThumbnail(widget.photos[3]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFivePhotosDesktop() {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Column(
        children: [
          Expanded(
            flex: 2,
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
          ),
          SizedBox(height: widget.spacing),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(2),
                    child: _buildPhotoThumbnail(widget.photos[2]),
                  ),
                ),
                SizedBox(width: widget.spacing),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(3),
                    child: _buildPhotoThumbnail(widget.photos[3]),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: widget.spacing),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () => widget.onPhotoTap(4),
              child: _buildPhotoThumbnail(widget.photos[4]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSixPhotosDesktop() {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Column(
        children: [
          Expanded(
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
          ),
          SizedBox(height: widget.spacing),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(2),
                    child: _buildPhotoThumbnail(widget.photos[2]),
                  ),
                ),
                SizedBox(width: widget.spacing),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(3),
                    child: _buildPhotoThumbnail(widget.photos[3]),
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
                    onTap: () => widget.onPhotoTap(4),
                    child: _buildPhotoThumbnail(widget.photos[4]),
                  ),
                ),
                SizedBox(width: widget.spacing),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(5),
                    child: _buildPhotoThumbnail(widget.photos[5]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSixPlusPhotosDesktop() {
    final hasMorePhotos = widget.photos.length > 6;
    final displayPhotos = widget.photos.take(6).toList();
    final remainingCount = widget.photos.length - 5;
    
    return AspectRatio(
      aspectRatio: 2 / 3,
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
                    child: _buildPhotoThumbnail(displayPhotos[3]),
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
                    onTap: () => widget.onPhotoTap(4),
                    child: _buildPhotoThumbnail(displayPhotos[4]),
                  ),
                ),
                SizedBox(width: widget.spacing),
                Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onPhotoTap(5),
                    child: hasMorePhotos
                        ? Stack(
                            children: [
                              _buildPhotoThumbnail(displayPhotos[5]),
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
                          )
                        : _buildPhotoThumbnail(displayPhotos[5]),
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
    
    // Check if this is a HEIC file
    final isHeic = photo.path.toLowerCase().endsWith('.heic') || 
                   photo.path.toLowerCase().endsWith('.heif');
    
    if (resolvedFile != null) {
      // For HEIC files, show a placeholder with message
      if (isHeic) {
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
                size: 32,
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
      
      // File is loaded and ready
      return Image.file(
        resolvedFile,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error displaying image: $error');
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