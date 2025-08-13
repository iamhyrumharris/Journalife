import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/entry.dart';
import '../../providers/entry_provider.dart';
import '../../providers/journal_provider.dart';
import 'entry_edit_screen.dart';

class DayEntriesScreen extends ConsumerWidget {
  final DateTime selectedDate;
  final String? journalId;

  const DayEntriesScreen({
    super.key,
    required this.selectedDate,
    this.journalId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentJournal = ref.watch(currentJournalProvider);
    final effectiveJournalId = journalId ?? currentJournal?.id;
    
    if (effectiveJournalId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Entries - ${DateFormat('MMM d, yyyy').format(selectedDate)}'),
        ),
        body: const Center(
          child: Text('No journal selected'),
        ),
      );
    }

    final entriesAsync = ref.watch(entryProvider(effectiveJournalId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Entries - ${DateFormat('MMM d, yyyy').format(selectedDate)}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _navigateToCreateEntry(context),
            tooltip: 'Create New Entry',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: entriesAsync.when(
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
                onPressed: () => ref.read(entryProvider(effectiveJournalId).notifier).loadEntries(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (allEntries) {
          final dayEntries = _getEntriesForDay(allEntries, selectedDate);
          
          if (dayEntries.isEmpty) {
            return _buildEmptyState(context);
          }
          
          return _buildEntriesList(context, dayEntries);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateEntry(context),
        tooltip: 'Create New Entry',
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Entry> _getEntriesForDay(List<Entry> allEntries, DateTime date) {
    return allEntries.where((entry) {
      return entry.createdAt.year == date.year &&
             entry.createdAt.month == date.month &&
             entry.createdAt.day == date.day;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by newest first
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.edit_note_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No entries yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first entry for ${DateFormat('MMMM d, yyyy').format(selectedDate)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _navigateToCreateEntry(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Entry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(BuildContext context, List<Entry> entries) {
    return Column(
      children: [
        // Day summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Entries list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _buildEntryCard(context, entry, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(BuildContext context, Entry entry, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToViewEntry(context, entry),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entry header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title.isNotEmpty ? entry.title : 'Untitled Entry',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    DateFormat('h:mm a').format(entry.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              
              // Entry content preview
              if (entry.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  entry.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              // Entry metadata
              const SizedBox(height: 12),
              Row(
                children: [
                  // Attachments indicator
                  if (entry.hasAttachments) ...[
                    Icon(
                      Icons.attachment,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.attachments.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  
                  // Location indicator
                  if (entry.hasLocation) ...[
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 16),
                  ],
                  
                  // Rating indicator
                  if (entry.hasRating) ...[
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < entry.rating! ? Icons.star : Icons.star_border,
                          size: 14,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  
                  const Spacer(),
                  
                  // Entry action indicator
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCreateEntry(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EntryEditScreen(
          initialDate: selectedDate,
        ),
      ),
    );
  }

  void _navigateToViewEntry(BuildContext context, Entry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EntryEditScreen(entry: entry),
      ),
    );
  }
}