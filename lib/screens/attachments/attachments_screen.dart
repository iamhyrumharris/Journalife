import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/attachment.dart';
import '../../models/entry.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../providers/entry_provider.dart';
import '../../services/attachment_service.dart';
import '../../widgets/journal_selector.dart';
import '../entry/entry_view_screen.dart';

class AttachmentsScreen extends ConsumerStatefulWidget {
  const AttachmentsScreen({super.key});

  @override
  ConsumerState<AttachmentsScreen> createState() => _AttachmentsScreenState();
}

class _AttachmentsScreenState extends ConsumerState<AttachmentsScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journalsAsync = ref.watch(journalProvider);
    final currentJournal = ref.watch(currentJournalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const JournalSelector(isAppBarTitle: true),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              ref.read(journalProvider.notifier).loadJournals();
            },
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.apps), text: 'All'),
            Tab(icon: Icon(Icons.image), text: 'Photos'),
            Tab(icon: Icon(Icons.video_library), text: 'Videos'),
            Tab(icon: Icon(Icons.audiotrack), text: 'Audio'),
            Tab(icon: Icon(Icons.insert_drive_file), text: 'Files'),
          ],
        ),
      ),
      body: journalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(journalProvider.notifier).loadJournals(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (journals) {
          if (journals.isEmpty) {
            return _buildEmptyState(ref);
          }

          // Use first journal if no current journal selected
          final effectiveJournal = currentJournal ?? journals.first;
          
          // Set current journal if not set
          if (currentJournal == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(currentJournalProvider.notifier).state = effectiveJournal;
            });
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAttachmentsView(ref, effectiveJournal, null),
              _buildAttachmentsView(ref, effectiveJournal, AttachmentType.photo),
              _buildAttachmentsView(ref, effectiveJournal, AttachmentType.photo), // Videos would be photos with video mime types
              _buildAttachmentsView(ref, effectiveJournal, AttachmentType.audio),
              _buildAttachmentsView(ref, effectiveJournal, AttachmentType.file),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.book, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No journals yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first journal to get started',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateJournalDialog(ref),
            icon: const Icon(Icons.add),
            label: const Text('Create Journal'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsView(WidgetRef ref, Journal journal, AttachmentType? filterType) {
    final entriesAsync = ref.watch(entryProvider(journal.id));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading entries: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(entryProvider(journal.id).notifier).loadEntries(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (entries) {
        // Collect all attachments from entries
        final allAttachments = <Attachment>[];
        final attachmentToEntry = <String, Entry>{};

        for (final entry in entries) {
          for (final attachment in entry.attachments) {
            if (filterType == null || attachment.type == filterType) {
              allAttachments.add(attachment);
              attachmentToEntry[attachment.id] = entry;
            }
          }
        }

        if (allAttachments.isEmpty) {
          return _buildEmptyAttachmentsState(filterType);
        }

        // Sort by creation date (newest first)
        allAttachments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (filterType == AttachmentType.photo) {
          return _buildPhotoGrid(allAttachments, attachmentToEntry);
        } else {
          return _buildAttachmentsList(allAttachments, attachmentToEntry);
        }
      },
    );
  }

  Widget _buildEmptyAttachmentsState(AttachmentType? filterType) {
    String message;
    IconData icon;

    switch (filterType) {
      case AttachmentType.photo:
        message = 'No photos yet';
        icon = Icons.image;
        break;
      case AttachmentType.audio:
        message = 'No audio recordings yet';
        icon = Icons.audiotrack;
        break;
      case AttachmentType.file:
        message = 'No files yet';
        icon = Icons.insert_drive_file;
        break;
      default:
        message = 'No attachments yet';
        icon = Icons.attachment;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add attachments to your entries to see them here',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/entry/create');
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Entry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(List<Attachment> attachments, Map<String, Entry> attachmentToEntry) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final attachment = attachments[index];
        final entry = attachmentToEntry[attachment.id]!;

        return GestureDetector(
          onTap: () => _showAttachmentDetails(context, attachment, entry),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                // Placeholder for image
                const Center(
                  child: Icon(
                    Icons.image,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),
                // Overlay with date
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      DateFormat('MMM d').format(attachment.createdAt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentsList(List<Attachment> attachments, Map<String, Entry> attachmentToEntry) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final attachment = attachments[index];
        final entry = attachmentToEntry[attachment.id]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _getAttachmentIcon(attachment.type),
            title: Text(attachment.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title.isNotEmpty ? entry.title : 'Untitled Entry'),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d, yyyy').format(attachment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (attachment.size != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatFileSize(attachment.size!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAttachmentDetails(context, attachment, entry),
          ),
        );
      },
    );
  }

  Widget _getAttachmentIcon(AttachmentType type) {
    switch (type) {
      case AttachmentType.photo:
        return const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.image, color: Colors.white),
        );
      case AttachmentType.audio:
        return const CircleAvatar(
          backgroundColor: Colors.purple,
          child: Icon(Icons.audiotrack, color: Colors.white),
        );
      case AttachmentType.file:
        return const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.insert_drive_file, color: Colors.white),
        );
      case AttachmentType.location:
        return const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.location_on, color: Colors.white),
        );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showAttachmentDetails(BuildContext context, Attachment attachment, Entry entry) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getAttachmentIcon(attachment.type),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _getAttachmentTypeLabel(attachment.type),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'From: ${entry.title.isNotEmpty ? entry.title : 'Untitled Entry'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Created: ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(attachment.createdAt)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (attachment.size != null) ...[
              const SizedBox(height: 8),
              Text(
                'Size: ${_formatFileSize(attachment.size!)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EntryViewScreen(entry: entry),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Entry'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    AttachmentService.openAttachment(context, attachment);
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getAttachmentTypeLabel(AttachmentType type) {
    switch (type) {
      case AttachmentType.photo:
        return 'Photo';
      case AttachmentType.audio:
        return 'Audio Recording';
      case AttachmentType.file:
        return 'File';
      case AttachmentType.location:
        return 'Location';
    }
  }

  void _showCreateJournalDialog(WidgetRef ref) {
    // This would show the same dialog as in CalendarScreen
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create journal functionality will be added'),
      ),
    );
  }
}