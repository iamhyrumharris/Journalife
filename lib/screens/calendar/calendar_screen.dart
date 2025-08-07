import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/entry.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../providers/entry_provider.dart';
import '../../widgets/journal_selector.dart';
import '../../widgets/file_migration_dialog.dart';
import '../entry/entry_view_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final journalsAsync = ref.watch(journalProvider);
    final currentJournal = ref.watch(currentJournalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              ref.read(journalProvider.notifier).loadJournals();
            },
          ),
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: () {
              Navigator.pushNamed(context, '/journals');
            },
            tooltip: 'Manage Journals',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'migration':
                  showDialog(
                    context: context,
                    builder: (context) => const FileMigrationDialog(),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'migration',
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move, size: 18),
                    SizedBox(width: 8),
                    Text('File Migration'),
                  ],
                ),
              ),
            ],
          ),
        ],
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
            return _buildEmptyState();
          }

          // Use first journal if no current journal selected
          final effectiveJournal = currentJournal ?? journals.first;
          
          // Set current journal if not set
          if (currentJournal == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(currentJournalProvider.notifier).state = effectiveJournal;
            });
          }

          return Column(
            children: [
              const JournalSelector(),
              Expanded(child: _buildCalendarView(effectiveJournal, journals)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
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
            onPressed: () => _showCreateJournalDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create Journal'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(Journal journal, List<Journal> allJournals) {
    final entriesAsync = ref.watch(entryProvider(journal.id));

    return Column(
      children: [
        Expanded(
          child: entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error loading entries: $error')),
            data: (entries) => _buildCalendarWithEntries(entries),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarWithEntries(List<Entry> entries) {
    return Column(
      children: [
        TableCalendar<Entry>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 1, 1),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) {
            return isSameDay(_selectedDay, day);
          },
          eventLoader: (day) {
            return entries.where((entry) {
              return isSameDay(entry.createdAt, day);
            }).toList();
          },
          startingDayOfWeek: StartingDayOfWeek.sunday,
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            markersMaxCount: 3,
            markerDecoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildSelectedDayEntries(entries),
        ),
      ],
    );
  }

  Widget _buildSelectedDayEntries(List<Entry> allEntries) {
    if (_selectedDay == null) {
      return const Center(child: Text('Select a day to view entries'));
    }

    final dayEntries = allEntries.where((entry) {
      return isSameDay(entry.createdAt, _selectedDay!);
    }).toList();

    if (dayEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit_note, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No entries for ${DateFormat('MMM d, yyyy').format(_selectedDay!)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/entry/create'),
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayEntries.length,
      itemBuilder: (context, index) {
        final entry = dayEntries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              entry.title.isNotEmpty ? entry.title : 'Untitled',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.content.isNotEmpty)
                  Text(
                    entry.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormat('HH:mm').format(entry.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (entry.hasAttachments) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.attachment, size: 16),
                      Text('${entry.attachments.length}'),
                    ],
                    if (entry.hasLocation) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on, size: 16),
                    ],
                    if (entry.hasRating) ...[
                      const SizedBox(width: 8),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < entry.rating! ? Icons.star : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EntryViewScreen(entry: entry),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showCreateJournalDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Journal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Journal Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              if (nameController.text.isNotEmpty) {
                ref.read(journalProvider.notifier).createJournal(
                  name: nameController.text,
                  description: descriptionController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}