import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/entry.dart';
import '../../models/attachment.dart';
import '../../providers/entry_provider.dart';
import '../../services/attachment_service.dart';
import 'entry_edit_screen.dart';

class EntryViewScreen extends ConsumerWidget {
  final Entry entry;

  const EntryViewScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.title.isNotEmpty ? entry.title : 'Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EntryEditScreen(entry: entry),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'delete':
                  final confirmed = await _showDeleteConfirmation(context);
                  if (confirmed && context.mounted) {
                    ref.read(entryProvider(entry.journalId).notifier)
                        .deleteEntry(entry.id);
                    Navigator.pop(context);
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and time
            Text(
              DateFormat('EEEE, MMMM d, yyyy \'at\' h:mm a').format(entry.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Title
            if (entry.title.isNotEmpty) ...[
              Text(
                entry.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Content
            if (entry.content.isNotEmpty) ...[
              Text(
                entry.content,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
            ],

            // Rating
            if (entry.hasRating) ...[
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < entry.rating! ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Tags
            if (entry.hasTags) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: entry.tags.map((tag) => Chip(
                  label: Text(tag),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Location
            if (entry.hasLocation) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(entry.locationName ?? 'Location'),
                  subtitle: Text(
                    '${entry.latitude!.toStringAsFixed(6)}, ${entry.longitude!.toStringAsFixed(6)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showLocationDialog(context, entry);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Attachments
            if (entry.hasAttachments) ...[
              Text(
                'Attachments',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildAttachments(context, entry.attachments),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments(BuildContext context, List<Attachment> attachments) {
    return Column(
      children: attachments.map((attachment) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _getAttachmentIcon(attachment.type),
            title: Text(attachment.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getAttachmentTypeLabel(attachment.type)),
                if (attachment.size != null)
                  Text(_formatFileSize(attachment.size!)),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await AttachmentService.openAttachment(context, attachment);
            },
          ),
        );
      }).toList(),
    );
  }

  Icon _getAttachmentIcon(AttachmentType type) {
    switch (type) {
      case AttachmentType.photo:
        return const Icon(Icons.image, color: Colors.green);
      case AttachmentType.audio:
        return const Icon(Icons.audiotrack, color: Colors.purple);
      case AttachmentType.file:
        return const Icon(Icons.insert_drive_file, color: Colors.blue);
      case AttachmentType.location:
        return const Icon(Icons.location_on, color: Colors.red);
    }
  }

  String _getAttachmentTypeLabel(AttachmentType type) {
    switch (type) {
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void _showLocationDialog(BuildContext context, Entry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_on),
            const SizedBox(width: 8),
            Text(entry.locationName ?? 'Location'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Coordinates:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText('Latitude: ${entry.latitude!.toStringAsFixed(6)}'),
            SelectableText('Longitude: ${entry.longitude!.toStringAsFixed(6)}'),
            const SizedBox(height: 16),
            if (entry.locationName != null) ...[
              const Text('Location Name:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(entry.locationName!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Map view coming soon!'),
                ),
              );
            },
            icon: const Icon(Icons.map),
            label: const Text('Open in Map'),
          ),
        ],
      ),
    );
  }
}