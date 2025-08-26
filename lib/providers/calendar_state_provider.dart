import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_models.dart';
import '../models/entry.dart';
import '../models/attachment.dart';
import '../utils/calendar_constants.dart';
import '../utils/date_extensions.dart';
import 'entry_provider.dart';
import 'journal_provider.dart';

// Core calendar state providers
final currentDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final visibleMonthsProvider = StateNotifierProvider<VisibleMonthsNotifier, List<DateTime>>((ref) {
  return VisibleMonthsNotifier();
});

class VisibleMonthsNotifier extends StateNotifier<List<DateTime>> {
  VisibleMonthsNotifier() : super([]) {
    _initializeVisibleMonths();
  }

  void _initializeVisibleMonths() {
    final now = DateTime.now();
    final months = <DateTime>[];
    
    for (int i = -3; i <= 3; i++) {
      months.add(DateTime(now.year, now.month + i, 1));
    }
    
    state = months;
  }

  void updateVisibleRange(DateTime firstMonth, DateTime lastMonth) {
    final months = <DateTime>[];
    
    // Normalize the months to the first day
    DateTime current = DateTime(firstMonth.year, firstMonth.month, 1);
    final end = DateTime(lastMonth.year, lastMonth.month, 1);
    
    // Ensure we don't create too many months
    int monthCount = 0;
    const maxMonths = 24; // Reasonable maximum
    
    while (!current.isAfter(end) && monthCount < maxMonths) {
      months.add(DateTime(current.year, current.month, 1));
      current = DateTime(current.year, current.month + 1, 1);
      monthCount++;
    }
    
    // Ensure we always have at least some months
    if (months.isEmpty) {
      _initializeVisibleMonths();
      return;
    }
    
    state = months;
  }

  void addMonthsAtEnd(int count) {
    if (state.isEmpty) return;
    
    final lastMonth = state.last;
    final newMonths = List<DateTime>.from(state);
    
    for (int i = 1; i <= count; i++) {
      newMonths.add(DateTime(lastMonth.year, lastMonth.month + i, 1));
    }
    
    if (newMonths.length > CalendarConstants.maxCachedMonths) {
      newMonths.removeRange(0, newMonths.length - CalendarConstants.maxCachedMonths);
    }
    
    state = newMonths;
  }

  void addMonthsAtStart(int count) {
    if (state.isEmpty) return;
    
    final firstMonth = state.first;
    final newMonths = <DateTime>[];
    
    for (int i = count; i >= 1; i--) {
      newMonths.add(DateTime(firstMonth.year, firstMonth.month - i, 1));
    }
    
    newMonths.addAll(state);
    
    if (newMonths.length > CalendarConstants.maxCachedMonths) {
      newMonths.removeRange(
        CalendarConstants.maxCachedMonths, 
        newMonths.length
      );
    }
    
    state = newMonths;
  }
}

// Journal data integration - converts journal entries to calendar format
final monthDataProvider = StateNotifierProvider.family<MonthDataNotifier, MonthData?, DateTime>(
  (ref, month) {
    final notifier = MonthDataNotifier(month);
    // Schedule the data loading after the provider is built
    Future.microtask(() => notifier._loadMonthData(ref));
    return notifier;
  },
);

class MonthDataNotifier extends StateNotifier<MonthData?> {
  final DateTime month;
  
  MonthDataNotifier(this.month) : super(null);

  void _loadMonthData(Ref ref) async {
    final currentJournal = ref.read(currentJournalProvider);
    if (currentJournal == null) {
      // No journal selected, create empty month
      _createEmptyMonth();
      return;
    }

    final entriesAsync = ref.read(entryProvider(currentJournal.id));
    
    entriesAsync.when(
      data: (entries) {
        _createMonthFromEntries(entries);
      },
      loading: () {
        _createEmptyMonth();
      },
      error: (error, stack) {
        _createEmptyMonth();
      },
    );
  }

  void _createEmptyMonth() {
    final days = <CalendarDay>[];
    final daysInMonth = month.daysInMonth;
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      days.add(CalendarDay(
        date: date,
        imagePath: null,
        thumbnailPath: null,
        hasEntry: false,
        entryCount: 0,
      ));
    }
    
    state = MonthData(
      month: month,
      days: days,
      isLoaded: true,
    );
  }

  void _createMonthFromEntries(List<Entry> allEntries) {
    // Filter entries for this month only
    final monthEntries = allEntries.where((entry) {
      return entry.createdAt.year == month.year && 
             entry.createdAt.month == month.month;
    }).toList();

    // Group entries by day
    final entriesByDay = <int, List<Entry>>{};
    for (final entry in monthEntries) {
      final day = entry.createdAt.day;
      entriesByDay.putIfAbsent(day, () => []).add(entry);
    }

    final days = <CalendarDay>[];
    final daysInMonth = month.daysInMonth;
    
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final dayEntries = entriesByDay[day] ?? [];
      
      // Get first photo attachment if available
      String? imagePath;
      String? thumbnailPath;
      
      if (dayEntries.isNotEmpty) {
        // Sort entries by content richness (content length + attachment count)
        // This prioritizes entries with more substantial content
        final sortedEntries = List<Entry>.from(dayEntries)
          ..sort((a, b) {
            final scoreA = a.content.length + (a.attachments.length * 10);
            final scoreB = b.content.length + (b.attachments.length * 10);
            return scoreB.compareTo(scoreA);
          });
        
        for (final entry in sortedEntries) {
          // Look for photo attachments
          final photoAttachments = entry.attachments.where(
            (attachment) => attachment.type == AttachmentType.photo
          ).toList();
          
          if (photoAttachments.isNotEmpty) {
            final firstPhoto = photoAttachments.first;
            imagePath = firstPhoto.path;
            // Use the same path for thumbnail - the image cache service will handle optimization
            thumbnailPath = firstPhoto.path;
            break;
          }
        }
      }
      
      days.add(CalendarDay(
        date: date,
        imagePath: imagePath,
        thumbnailPath: thumbnailPath,
        hasEntry: dayEntries.isNotEmpty,
        entryCount: dayEntries.length,
      ));
    }
    
    state = MonthData(
      month: month,
      days: days,
      isLoaded: true,
    );
  }

  void updateDay(CalendarDay day) {
    if (state == null) return;
    
    final updatedDays = state!.days.map((d) {
      if (d.date.isSameDay(day.date)) {
        return day;
      }
      return d;
    }).toList();
    
    state = state!.copyWith(days: updatedDays);
  }

  void refreshMonth(Ref ref) {
    _loadMonthData(ref);
  }
}

// Scroll position and viewport tracking
final scrollPositionProvider = StateNotifierProvider<ScrollPositionNotifier, double>(
  (ref) => ScrollPositionNotifier(),
);

class ScrollPositionNotifier extends StateNotifier<double> {
  Timer? _debounceTimer;
  
  ScrollPositionNotifier() : super(0.0);

  void updatePosition(double position) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(CalendarConstants.scrollDebounce, () {
      state = position;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final calendarViewportProvider = Provider<CalendarViewportInfo>((ref) {
  final visibleMonths = ref.watch(visibleMonthsProvider);
  final scrollPosition = ref.watch(scrollPositionProvider);
  
  if (visibleMonths.isEmpty) {
    final now = DateTime.now();
    return CalendarViewportInfo(
      firstVisibleMonth: now.firstDayOfMonth,
      lastVisibleMonth: now.firstDayOfMonth,
      scrollOffset: 0.0,
    );
  }
  
  return CalendarViewportInfo(
    firstVisibleMonth: visibleMonths.first,
    lastVisibleMonth: visibleMonths.last,
    scrollOffset: scrollPosition,
  );
});

// Date selection and navigation
final selectedDateProvider = StateProvider<DateTime?>((ref) => null);

final calendarDaysCache = <String, List<DateTime?>>{};

final calendarDaysProvider = Provider.family<List<DateTime?>, DateTime>((ref, month) {
  final key = '${month.year}-${month.month}';
  
  if (calendarDaysCache.containsKey(key)) {
    return calendarDaysCache[key]!;
  }
  
  final days = month.getCalendarDaysForMonth();
  calendarDaysCache[key] = days;
  
  // Prevent memory leaks by limiting cache size
  if (calendarDaysCache.length > 20) {
    final keysToRemove = calendarDaysCache.keys.take(5).toList();
    for (final k in keysToRemove) {
      calendarDaysCache.remove(k);
    }
  }
  
  return days;
});

final jumpToDateProvider = Provider<void Function(DateTime)>((ref) {
  return (DateTime date) {
    // Always update the visible range when jumping to a date
    final visibleMonthsNotifier = ref.read(visibleMonthsProvider.notifier);
    
    // Load 3 months before and 3 months after the selected date (7 months total)
    final firstMonth = DateTime(date.year, date.month - 3, 1);
    final lastMonth = DateTime(date.year, date.month + 3, 1);
    
    // Update the visible range
    visibleMonthsNotifier.updateVisibleRange(firstMonth, lastMonth);
    
    // Update selected date
    ref.read(selectedDateProvider.notifier).state = date;
    
    // Trigger calendar refresh to ensure month data is loaded
    final currentCount = ref.read(calendarRefreshTriggerProvider);
    ref.read(calendarRefreshTriggerProvider.notifier).state = currentCount + 1;
  };
});

// Loading states for pull-to-load functionality
final isLoadingEarlierMonthsProvider = StateProvider<bool>((ref) => false);
final isLoadingLaterMonthsProvider = StateProvider<bool>((ref) => false);

// Pull progress tracking
final pullProgressTopProvider = StateProvider<double>((ref) => 0.0);
final pullProgressBottomProvider = StateProvider<double>((ref) => 0.0);

// Refresh trigger - used when entries are added/updated/deleted
final calendarRefreshTriggerProvider = StateProvider<int>((ref) => 0);

// Provider to refresh calendar data when entries change
final calendarDataRefreshProvider = Provider<void>((ref) {
  // Watch for entry changes in current journal
  final currentJournal = ref.watch(currentJournalProvider);
  if (currentJournal != null) {
    ref.watch(entryProvider(currentJournal.id));
  }
  
  // Watch for refresh trigger
  ref.watch(calendarRefreshTriggerProvider);
  
  // Refresh all visible months when data changes
  final visibleMonths = ref.watch(visibleMonthsProvider);
  // Schedule refresh after build phase completes to avoid provider initialization issues
  Future.microtask(() {
    for (final month in visibleMonths) {
      ref.read(monthDataProvider(month).notifier).refreshMonth(ref);
    }
  });
});

// Helper function to trigger calendar refresh
void refreshCalendar(WidgetRef ref) {
  final currentCount = ref.read(calendarRefreshTriggerProvider);
  ref.read(calendarRefreshTriggerProvider.notifier).state = currentCount + 1;
}