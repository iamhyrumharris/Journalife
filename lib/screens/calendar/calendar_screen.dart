import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/entry.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../providers/entry_provider.dart';
import '../../widgets/journal_selector.dart';
import '../../widgets/file_migration_dialog.dart';
import '../../widgets/scrollable_calendar.dart';
import '../entry/entry_edit_screen.dart';
import '../entry/day_entries_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int _selectedYear = DateTime.now().year;
  DateTime? _selectedDay;

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
              Expanded(child: _buildScrollableCalendar(effectiveJournal)),
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

  Widget _buildScrollableCalendar(Journal journal) {
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
      data: (entries) => ScrollableCalendar(
        selectedYear: _selectedYear,
        selectedDay: _selectedDay,
        entries: entries,
        onDaySelected: (selectedDay) => _handleDaySelection(selectedDay, entries, journal.id),
        onYearChanged: (year) {
          setState(() {
            _selectedYear = year;
          });
        },
        onMonthChanged: (month) {
          // Month changed callback - can be used for future functionality
        },
      ),
    );
  }

  void _handleDaySelection(DateTime selectedDay, List<Entry> entries, String journalId) {
    setState(() {
      _selectedDay = selectedDay;
    });

    // Get entries for the selected day
    final dayEntries = entries.where((entry) {
      return _isSameDay(entry.createdAt, selectedDay);
    }).toList();

    if (dayEntries.isEmpty) {
      // No entries for this day - navigate directly to entry creation
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EntryEditScreen(
            initialDate: selectedDay,
          ),
        ),
      );
    } else {
      // Has entries - navigate to day entries screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DayEntriesScreen(
            selectedDate: selectedDay,
            journalId: journalId,
          ),
        ),
      );
    }
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}