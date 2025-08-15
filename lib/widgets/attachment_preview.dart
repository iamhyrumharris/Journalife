import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../models/attachment.dart';
import '../services/media_service.dart';
import '../services/attachment_service.dart';
import '../services/local_file_storage_service.dart';

class AttachmentPreview extends StatefulWidget {
  final Attachment attachment;
  final bool showActions;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const AttachmentPreview({
    super.key,
    required this.attachment,
    this.showActions = true,
    this.onTap,
    this.onDelete,
  });

  @override
  State<AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<AttachmentPreview> {
  PlayerController? _playerController;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  // Duration _totalDuration = Duration.zero;  // Unused field
  
  static final LocalFileStorageService _storageService = LocalFileStorageService();

  @override
  void initState() {
    super.initState();
    if (widget.attachment.type == AttachmentType.audio) {
      _initializeAudioPlayer();
    }
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  void _initializeAudioPlayer() {
    _playerController = PlayerController();
    if (widget.attachment.path.isNotEmpty &&
        File(widget.attachment.path).existsSync()) {
      _playerController
          ?.preparePlayer(
            path: widget.attachment.path,
            shouldExtractWaveform: true,
          )
          .then((_) {
            _playerController?.onCurrentDurationChanged.listen((duration) {
              setState(() {
                _currentPosition = Duration(milliseconds: duration);
              });
            });
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _buildAttachmentContent(),
        ),
      ),
    );
  }

  Widget _buildAttachmentContent() {
    switch (widget.attachment.type) {
      case AttachmentType.photo:
        return _buildPhotoPreview();
      case AttachmentType.audio:
        return _buildAudioPreview();
      case AttachmentType.file:
        return _buildFilePreview();
      case AttachmentType.location:
        return _buildLocationPreview();
    }
  }

  Widget _buildPhotoPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image preview
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildImageWidget(),
        ),
        const SizedBox(height: 8),

        // Photo info
        Row(
          children: [
            const Icon(Icons.image, size: 16, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.attachment.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.attachment.size != null)
              Text(
                MediaService.formatFileSize(widget.attachment.size!),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            if (widget.showActions) ...[
              const SizedBox(width: 8),
              _buildActionButtons(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildImageWidget() {
    // Handle asset paths
    if (widget.attachment.path.startsWith('assets/')) {
      return Image.asset(
        widget.attachment.path,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
      );
    }

    // Handle file paths (both absolute legacy and relative new paths)
    return FutureBuilder<File?>(
      future: _resolveAttachmentFile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingWidget();
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return _buildImagePlaceholder();
        }

        final file = snapshot.data!;
        return Image.file(
          file,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[100],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Image not available', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  /// Resolves attachment path to File, handling both relative and absolute paths
  Future<File?> _resolveAttachmentFile() async {
    try {
      debugPrint('🔍 AttachmentPreview._resolveAttachmentFile() starting...');
      debugPrint('Attachment ID: ${widget.attachment.id}');
      debugPrint('Attachment path: ${widget.attachment.path}');
      debugPrint('Attachment type: ${widget.attachment.type}');
      debugPrint('Attachment size: ${widget.attachment.size} bytes');
      
      // Check if it's already an absolute path (legacy)
      if (widget.attachment.path.startsWith('/') || widget.attachment.path.contains(':')) {
        debugPrint('📁 Treating as absolute path (legacy)');
        final file = File(widget.attachment.path);
        final exists = await file.exists();
        debugPrint('Legacy file exists: $exists');
        
        if (exists) {
          final size = await file.length();
          debugPrint('✓ Legacy file verified: $size bytes');
        }
        
        return exists ? file : null;
      }

      // Otherwise, it's a relative path - resolve through storage service
      debugPrint('📂 Treating as relative path - resolving through storage service...');
      final resolvedFile = await _storageService.getFile(widget.attachment.path);
      
      if (resolvedFile != null) {
        final exists = await resolvedFile.exists();
        debugPrint('Resolved file exists: $exists');
        debugPrint('Resolved file path: ${resolvedFile.path}');
        
        if (exists) {
          final size = await resolvedFile.length();
          debugPrint('✓ Resolved file verified: $size bytes');
          debugPrint('✅ File resolution successful!');
        } else {
          debugPrint('❌ Resolved file does not exist on disk');
        }
        
        return exists ? resolvedFile : null;
      } else {
        debugPrint('❌ Storage service returned null for path: ${widget.attachment.path}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error resolving attachment file: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Widget _buildAudioPreview() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.audiotrack, size: 20, color: Colors.purple),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.attachment.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (widget.attachment.metadata?['duration'] != null) ...[
                        Text(
                          ' / ${_formatDuration(Duration(seconds: int.tryParse(widget.attachment.metadata!['duration']) ?? 0))}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const Spacer(),
                      if (widget.attachment.size != null)
                        Text(
                          MediaService.formatFileSize(widget.attachment.size!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Play/Pause Button
            IconButton(
              onPressed: _toggleAudioPlayback,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              style: IconButton.styleFrom(
                backgroundColor: Colors.purple.withValues(alpha: 0.1),
                foregroundColor: Colors.purple,
              ),
            ),

            if (widget.showActions) _buildActionButtons(),
          ],
        ),

        // Waveform (if available)
        if (_playerController != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: AudioFileWaveforms(
              playerController: _playerController!,
              size: const Size(double.infinity, 60),
              playerWaveStyle: const PlayerWaveStyle(
                fixedWaveColor: Colors.grey,
                liveWaveColor: Colors.purple,
                spacing: 4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilePreview() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            MediaService.getFileIcon(
              widget.attachment.mimeType,
              widget.attachment.metadata?['extension'],
            ),
            color: Colors.blue,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.attachment.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (widget.attachment.metadata?['extension'] != null) ...[
                    Text(
                      widget.attachment.metadata!['extension'].toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.attachment.size != null)
                    Text(
                      MediaService.formatFileSize(widget.attachment.size!),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (widget.showActions) _buildActionButtons(),
      ],
    );
  }

  Widget _buildLocationPreview() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.location_on, color: Colors.red, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.attachment.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (widget.attachment.metadata != null) ...[
                Text(
                  'Lat: ${widget.attachment.metadata!['latitude'] ?? 'Unknown'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Lng: ${widget.attachment.metadata!['longitude'] ?? 'Unknown'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (widget.showActions) _buildActionButtons(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (action) async {
        switch (action) {
          case 'delete':
            widget.onDelete?.call();
            break;
          case 'share':
            await AttachmentService.shareAttachment(context, widget.attachment);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 18),
              SizedBox(width: 8),
              Text('Share'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleAudioPlayback() async {
    if (_playerController == null) return;

    try {
      if (_isPlaying) {
        await _playerController!.pausePlayer();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _playerController!.startPlayer();
        setState(() {
          _isPlaying = true;
        });

        // Listen for completion
        _playerController!.onCompletion.listen((_) {
          setState(() {
            _isPlaying = false;
            _currentPosition = Duration.zero;
          });
        });
      }
    } catch (e) {
      debugPrint('Error toggling audio playback: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
