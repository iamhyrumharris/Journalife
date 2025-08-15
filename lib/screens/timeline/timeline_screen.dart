import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/entry.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../providers/entry_provider.dart';
import '../../widgets/journal_selector.dart';
import '../../widgets/attachment_thumbnail.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/error_state_widget.dart';
import '../entry/entry_edit_screen.dart';
import '../settings/settings_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/search_overlay.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalsAsync = ref.watch(journalProvider);
    final currentJournal = ref.watch(currentJournalProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: JournalSelector(isAppBarTitle: true),
        ),
        leadingWidth: 200,
        title: const Text('Timeline'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearchOverlay(context);
            },
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: journalsAsync.when(
        loading: () => _buildShimmerLoading(),
        error: (error, stack) => ErrorStateWidget(
          error: error.toString(),
          onRetry: () => ref.read(journalProvider.notifier).loadJournals(),
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
              ref.read(currentJournalProvider.notifier).state =
                  effectiveJournal;
            });
          }

          return _buildTimelineView(context, ref, effectiveJournal);
        },
      ),
    );
  }

  Widget _buildEmptyState(WidgetRef ref) {
    return NoJournalsEmptyState(
      onCreateJournal: () => _showCreateJournalDialog(ref),
    );
  }

  Widget _buildTimelineView(
    BuildContext context,
    WidgetRef ref,
    Journal journal,
  ) {
    final entriesAsync = ref.watch(entryProvider(journal.id));

    return entriesAsync.when(
      loading: () => _buildShimmerLoading(),
      error: (error, stack) => ErrorStateWidget(
        error: error.toString(),
        onRetry: () => ref.read(entryProvider(journal.id).notifier).loadEntries(),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return NoEntriesEmptyState(
            onCreateEntry: () => Navigator.pushNamed(context, '/entry/create'),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(entryProvider(journal.id).notifier).loadEntries();
          },
          child: _buildEntriesList(entries),
        );
      },
    );
  }

  Widget _buildEntriesList(List<Entry> entries) {
    // Group entries by date
    final entriesByDate = <String, List<Entry>>{};

    for (final entry in entries) {
      final dateKey = DateFormat('yyyy-MM-dd').format(entry.createdAt);
      if (!entriesByDate.containsKey(dateKey)) {
        entriesByDate[dateKey] = [];
      }
      entriesByDate[dateKey]!.add(entry);
    }

    // Sort dates in descending order
    final sortedDates = entriesByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final dateEntries = entriesByDate[dateKey]!;
        final date = DateTime.parse(dateKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formatDateHeader(date),
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),

            // Entries for this date
            ...dateEntries.map((entry) => _buildTimelineEntry(context, entry)),
          ],
        );
      },
    );
  }

  Widget _buildTimelineEntry(BuildContext context, Entry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EntryEditScreen(entry: entry),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with time and metadata
              Row(
                children: [
                  Text(
                    DateFormat('HH:mm').format(entry.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (entry.hasAttachments) ...[
                    Icon(Icons.attachment, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.attachments.length}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (entry.hasLocation)
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              if (entry.title.isNotEmpty) ...[
                Text(
                  entry.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Content preview
              if (entry.content.isNotEmpty) ...[
                Text(
                  entry.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
              ],

              // Tags
              if (entry.hasTags) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: entry.tags
                      .take(3)
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tag,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.blue[700]),
                          ),
                        ),
                      )
                      .toList(),
                ),
                if (entry.tags.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${entry.tags.length - 3} more tags',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ),
                const SizedBox(height: 8),
              ],

              // Photo attachments preview
              if (entry.photoAttachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: entry.photoAttachments.length,
                    itemBuilder: (context, index) {
                      final attachment = entry.photoAttachments[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: TimelineAttachmentThumbnail(
                          attachment: attachment,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'Today';
    } else if (entryDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(entryDate).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else if (date.year == now.year) {
      return DateFormat('MMMM d').format(date);
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6, // Show 6 shimmer cards
      itemBuilder: (context, index) {
        return ShimmerCard(
          height: index % 3 == 0 ? 160 : 120, // Vary height for realism
          margin: const EdgeInsets.only(bottom: 12),
        );
      },
    );
  }

  void _showCreateJournalDialog(WidgetRef ref) {
    // This would show the same dialog as in CalendarScreen
    // For now, just show a snackbar
  }
}
