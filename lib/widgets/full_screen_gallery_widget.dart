import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/attachment.dart';
import '../services/local_file_storage_service.dart';

class FullScreenGalleryWidget extends StatefulWidget {
  final List<Attachment> photos;
  final int initialIndex;

  const FullScreenGalleryWidget({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenGalleryWidget> createState() => _FullScreenGalleryWidgetState();
}

class _FullScreenGalleryWidgetState extends State<FullScreenGalleryWidget> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleAppBarVisibility() {
    setState(() {
      _showAppBar = !_showAppBar;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showAppBar
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                '${_currentIndex + 1} of ${widget.photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              centerTitle: true,
              systemOverlayStyle: SystemUiOverlayStyle.light,
            )
          : null,
      body: GestureDetector(
        onTap: _toggleAppBarVisibility,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemCount: widget.photos.length,
          itemBuilder: (context, index) {
            return _buildPhotoPage(widget.photos[index]);
          },
        ),
      ),
      bottomNavigationBar: _showAppBar && widget.photos.length > 1
          ? Container(
              color: Colors.black.withValues(alpha: 0.5),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photos.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPhotoPage(Attachment photo) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.8,
        maxScale: 4.0,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: FutureBuilder<File?>(
            future: _resolveAttachmentFile(photo),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return _buildErrorPlaceholder();
              }

              final file = snapshot.data!;
              return Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorPlaceholder();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Colors.white54,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Image not available',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
            ),
          ),
        ],
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