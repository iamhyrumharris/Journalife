import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/entry.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../providers/entry_provider.dart';
import '../../widgets/journal_selector.dart';
import '../../widgets/file_migration_dialog.dart';
import '../../widgets/scrollable_calendar.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/error_state_widget.dart';
import '../entry/entry_edit_screen.dart';
import '../entry/day_entries_screen.dart';
import '../settings/settings_screen.dart';
import '../../widgets/search_overlay.dart';

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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journalsAsync = ref.watch(journalProvider);
    final currentJournal = ref.watch(currentJournalProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: JournalSelector(isAppBarTitle: true),
        ),
        leadingWidth: 200,
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
        heroTag: 'calendar_jump_today_fab',
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
    return NoJournalsEmptyState(
      onCreateJournal: () => _showCreateJournalDialog(),
    );
  }

  Widget _buildScrollableCalendar(Journal journal) {
    final entriesAsync = ref.watch(entryProvider(journal.id));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => ErrorStateWidget(
        error: error.toString(),
        onRetry: () => ref.read(entryProvider(journal.id).notifier).loadEntries(),
      ),
      data: (entries) => KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            _handleKeyEvent(event, entries, journal.id);
          }
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            // Add swipe gesture support for month navigation
            if (details.delta.dx > 10) {
              _navigateToPreviousMonth();
            } else if (details.delta.dx < -10) {
              _navigateToNextMonth();
            }
          },
          child: ScrollableCalendar(
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
        ),
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

  void _handleKeyEvent(KeyDownEvent event, List<Entry> entries, String journalId) {
    if (_selectedDay == null) return;
    
    DateTime newSelectedDay = _selectedDay!;
    
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        newSelectedDay = _selectedDay!.subtract(const Duration(days: 1));
        break;
      case LogicalKeyboardKey.arrowRight:
        newSelectedDay = _selectedDay!.add(const Duration(days: 1));
        break;
      case LogicalKeyboardKey.arrowUp:
        newSelectedDay = _selectedDay!.subtract(const Duration(days: 7));
        break;
      case LogicalKeyboardKey.arrowDown:
        newSelectedDay = _selectedDay!.add(const Duration(days: 7));
        break;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        _handleDaySelection(_selectedDay!, entries, journalId);
        return;
      case LogicalKeyboardKey.keyT:
        _jumpToToday();
        return;
      default:
        return;
    }
    
    setState(() {
      _selectedDay = newSelectedDay;
      if (newSelectedDay.year != _selectedYear) {
        _selectedYear = newSelectedDay.year;
      }
    });
    
    // Scroll to the new date if needed
    _calendarKey.currentState?.scrollToDate(newSelectedDay);
  }

  void _navigateToPreviousMonth() {
    final previousMonth = DateTime(_currentViewedMonth.year, _currentViewedMonth.month - 1);
    setState(() {
      _currentViewedMonth = previousMonth;
    });
    _calendarKey.currentState?.scrollToDate(previousMonth);
  }

  void _navigateToNextMonth() {
    final nextMonth = DateTime(_currentViewedMonth.year, _currentViewedMonth.month + 1);
    setState(() {
      _currentViewedMonth = nextMonth;
    });
    _calendarKey.currentState?.scrollToDate(nextMonth);
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3, // Show 3 shimmer cards
      itemBuilder: (context, index) {
        return ShimmerCard(
          height: 200,
          margin: const EdgeInsets.only(bottom: 16),
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}