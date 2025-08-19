import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../providers/entry_provider.dart';
import 'journal_edit_screen.dart';
import 'journal_settings_screen.dart';

class JournalListScreen extends ConsumerWidget {
  const JournalListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalsAsync = ref.watch(journalProvider);
    final currentJournal = ref.watch(currentJournalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Journals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => ref.read(journalProvider.notifier).loadJournals(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: journalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading journals: $error'),
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
            return _buildEmptyState(context, ref);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: journals.length,
            itemBuilder: (context, index) {
              final journal = journals[index];
              final isActive = currentJournal?.id == journal.id;
              
              return _buildJournalCard(context, ref, journal, isActive);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateJournal(context),
        tooltip: 'Create Journal',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.book, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No journals yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first journal to start writing',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _navigateToCreateJournal(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Journal'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalCard(BuildContext context, WidgetRef ref, Journal journal, bool isActive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 4 : 1,
      color: isActive ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () => _selectJournal(ref, journal),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (journal.icon != null)
                    Text(
                      journal.icon!,
                      style: const TextStyle(fontSize: 24),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: journal.color != null 
                            ? Color(int.parse(journal.color!, radix: 16))
                            : Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.book, color: Colors.white),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                journal.name,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                                ),
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Active',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (value) => _handleMenuAction(context, ref, journal, value),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'settings',
                                  child: Row(
                                    children: [
                                      Icon(Icons.settings),
                                      SizedBox(width: 8),
                                      Text('Settings'),
                                    ],
                                  ),
                                ),
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
                        if (journal.description.isNotEmpty)
                          Text(
                            journal.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isActive 
                                  ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                                  : Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Journal stats
              Consumer(
                builder: (context, ref, child) {
                  final entriesAsync = ref.watch(entryProvider(journal.id));
                  return entriesAsync.when(
                    loading: () => const SizedBox(height: 20, child: LinearProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                    data: (entries) => _buildJournalStats(context, journal, entries.length, isActive),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJournalStats(BuildContext context, Journal journal, int entryCount, bool isActive) {
    final textColor = isActive 
        ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
        : Colors.grey[600];

    return Row(
      children: [
        Icon(Icons.edit_note, size: 16, color: textColor),
        const SizedBox(width: 4),
        Text(
          '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
          style: TextStyle(color: textColor, fontSize: 12),
        ),
        const SizedBox(width: 16),
        Icon(Icons.calendar_today, size: 16, color: textColor),
        const SizedBox(width: 4),
        Text(
          'Created ${DateFormat('MMM d, yyyy').format(journal.createdAt)}',
          style: TextStyle(color: textColor, fontSize: 12),
        ),
      ],
    );
  }

  void _selectJournal(WidgetRef ref, Journal journal) {
    ref.read(currentJournalProvider.notifier).state = journal;
    ScaffoldMessenger.of(ref.context).showSnackBar(
      SnackBar(
        content: Text('Switched to "${journal.name}"'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToCreateJournal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JournalEditScreen(),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, Journal journal, String action) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JournalEditScreen(journal: journal),
          ),
        );
        break;
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JournalSettingsScreen(journal: journal),
          ),
        );
        break;
      case 'delete':
        _showDeleteConfirmation(context, ref, journal);
        break;
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Journal journal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Journal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${journal.name}"?'),
            const SizedBox(height: 8),
            const Text(
              'This will permanently delete the journal and all its entries. This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteJournal(ref, journal);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteJournal(WidgetRef ref, Journal journal) async {
    try {
      // If this is the current journal, clear the selection
      final currentJournal = ref.read(currentJournalProvider);
      if (currentJournal?.id == journal.id) {
        ref.read(currentJournalProvider.notifier).state = null;
      }
      
      await ref.read(journalProvider.notifier).deleteJournal(journal.id);
      
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text('Journal "${journal.name}" deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text('Error deleting journal: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}