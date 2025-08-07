import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/attachment.dart';

/// Service for handling attachment operations like opening files
class AttachmentService {
  /// Shares an attachment using native sharing capabilities
  static Future<bool> shareAttachment(
    BuildContext context,
    Attachment attachment,
  ) async {
    try {
      final file = File(attachment.path);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File not found - cannot share'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      // Create XFile for sharing
      final xFile = XFile(
        attachment.path,
        name: attachment.name,
        mimeType: attachment.mimeType,
      );

      // Share the file with a descriptive text
      final String shareText = _getShareText(attachment);

      await Share.shareXFiles(
        [xFile],
        text: shareText,
        subject: 'Shared from Journal: ${attachment.name}',
      );

      return true;
    } catch (e) {
      debugPrint('Error sharing attachment: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing attachment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Opens an attachment based on its type
  static Future<bool> openAttachment(
    BuildContext context,
    Attachment attachment,
  ) async {
    try {
      switch (attachment.type) {
        case AttachmentType.photo:
          return await _openPhoto(context, attachment);
        case AttachmentType.audio:
          return await _openAudio(context, attachment);
        case AttachmentType.file:
          return await _openFile(context, attachment);
        case AttachmentType.location:
          return await _openLocation(context, attachment);
      }
    } catch (e) {
      debugPrint('Error opening attachment: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening attachment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  /// Opens a photo attachment
  static Future<bool> _openPhoto(
    BuildContext context,
    Attachment attachment,
  ) async {
    final file = File(attachment.path);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo file not found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    // Show photo in a dialog or full screen viewer
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(attachment.name),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Flexible(child: Image.file(file)),
            ],
          ),
        ),
      );
    }
    return true;
  }

  /// Opens an audio attachment
  static Future<bool> _openAudio(
    BuildContext context,
    Attachment attachment,
  ) async {
    final file = File(attachment.path);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio file not found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    // For now, show a placeholder dialog - audio playback would require additional packages
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(attachment.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.audiotrack, size: 64),
              const SizedBox(height: 16),
              Text('Audio file: ${attachment.name}'),
              const SizedBox(height: 8),
              if (attachment.size != null)
                Text('Size: ${_formatFileSize(attachment.size!)}'),
              const SizedBox(height: 16),
              const Text('Audio playback coming soon!'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
    return true;
  }

  /// Opens a file attachment
  static Future<bool> _openFile(
    BuildContext context,
    Attachment attachment,
  ) async {
    final file = File(attachment.path);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File not found'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    // Try to open the file with the system default app
    final uri = Uri.file(attachment.path);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    } else {
      // If we can't launch it, show file info
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(attachment.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insert_drive_file, size: 64),
                const SizedBox(height: 16),
                Text('File: ${attachment.name}'),
                const SizedBox(height: 8),
                Text('Path: ${attachment.path}'),
                if (attachment.size != null) ...[
                  const SizedBox(height: 8),
                  Text('Size: ${_formatFileSize(attachment.size!)}'),
                ],
                if (attachment.mimeType != null) ...[
                  const SizedBox(height: 8),
                  Text('Type: ${attachment.mimeType}'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      return false;
    }
  }

  /// Opens a location attachment
  static Future<bool> _openLocation(
    BuildContext context,
    Attachment attachment,
  ) async {
    // Show location details - could integrate with maps in the future
    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 64),
              const SizedBox(height: 16),
              Text(attachment.name),
              const SizedBox(height: 8),
              Text('Path: ${attachment.path}'),
              const SizedBox(height: 16),
              const Text('Map integration coming soon!'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
    return true;
  }

  /// Formats file size for display
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Gets the appropriate icon for an attachment type
  static IconData getAttachmentIcon(AttachmentType type) {
    switch (type) {
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

  /// Gets descriptive text for sharing an attachment
  static String _getShareText(Attachment attachment) {
    switch (attachment.type) {
      case AttachmentType.photo:
        return 'Sharing photo from my journal: ${attachment.name}';
      case AttachmentType.audio:
        return 'Sharing audio recording from my journal: ${attachment.name}';
      case AttachmentType.file:
        return 'Sharing file from my journal: ${attachment.name}';
      case AttachmentType.location:
        return 'Sharing location from my journal: ${attachment.name}';
    }
  }
}
