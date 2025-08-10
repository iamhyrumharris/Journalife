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
  DateTime _currentViewedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final GlobalKey<ScrollableCalendarState> _calendarKey = GlobalKey<ScrollableCalendarState>();

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

          return _buildScrollableCalendar(effectiveJournal);
        },
      ),
      floatingActionButton: _shouldShowJumpButton() ? FloatingActionButton.small(
        onPressed: _jumpToToday,
        tooltip: 'Jump to today',
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        child: const Text(
          'Today',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
        key: _calendarKey,
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
          setState(() {
            _currentViewedMonth = month;
          });
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

  bool _shouldShowJumpButton() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final viewedMonth = DateTime(_currentViewedMonth.year, _currentViewedMonth.month);
    
    // Hide button if we're already viewing the current month
    return !_isSameMonth(currentMonth, viewedMonth);
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  void _jumpToToday() {
    final today = DateTime.now();
    setState(() {
      _selectedDay = today;
      _selectedYear = today.year;
    });
    
    // Scroll calendar to today
    _calendarKey.currentState?.scrollToDate(today);
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