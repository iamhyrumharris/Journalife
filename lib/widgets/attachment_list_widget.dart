import 'package:flutter/material.dart';
import '../models/attachment.dart';
import '../services/media_service.dart';

class AttachmentListWidget extends StatelessWidget {
  final List<Attachment> attachments;
  final Function(Attachment) onRemove;
  final bool isEditable;

  const AttachmentListWidget({
    super.key,
    required this.attachments,
    required this.onRemove,
    this.isEditable = true,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out photos - they're handled by PhotoCollageWidget
    final nonPhotoAttachments = attachments
        .where((attachment) => attachment.type != AttachmentType.photo)
        .toList();
        
    if (nonPhotoAttachments.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attachments (${nonPhotoAttachments.length})',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...nonPhotoAttachments.map((attachment) => _AttachmentItem(
            attachment: attachment,
            onRemove: isEditable ? () => onRemove(attachment) : null,
            colorScheme: colorScheme,
          )),
        ],
      ),
    );
  }
}

class _AttachmentItem extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback? onRemove;
  final ColorScheme colorScheme;

  const _AttachmentItem({
    required this.attachment,
    this.onRemove,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final icon = MediaService.getFileIcon(attachment.mimeType, _getExtension(attachment.name));
    final sizeText = MediaService.formatFileSize(attachment.size ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getTypeColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: _getTypeColor(),
            size: 20,
          ),
        ),
        title: Text(
          attachment.name,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              _getTypeLabel(),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              sizeText,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            if (attachment.type == AttachmentType.audio && 
                attachment.metadata?['duration'] != null) ...[
              const SizedBox(width: 8),
              Text(
                '${attachment.metadata!['duration']}s',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: onRemove != null 
            ? IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.close,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                padding: EdgeInsets.zero,
              )
            : null,
      ),
    );
  }

  Color _getTypeColor() {
    switch (attachment.type) {
      case AttachmentType.photo:
        return Colors.blue;
      case AttachmentType.audio:
        return Colors.orange;
      case AttachmentType.file:
        return Colors.grey;
      case AttachmentType.location:
        return Colors.green;
    }
  }

  String _getTypeLabel() {
    switch (attachment.type) {
      case AttachmentType.photo:
        return 'Photo';
      case AttachmentType.audio:
        return 'Audio';
      case AttachmentType.file:
        return 'File';
      case AttachmentType.location:
        return 'Location';
    }
  }

  String? _getExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot != -1 && lastDot < filename.length - 1) {
      return filename.substring(lastDot + 1);
    }
    return null;
  }
}