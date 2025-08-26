import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import 'calendar_day_cell.dart';

class ScrollableCalendar extends StatefulWidget {
  final int selectedYear;
  final DateTime? selectedDay;
  final List<Entry> entries;
  final Function(DateTime) onDaySelected;
  final Function(int) onYearChanged;
  final Function(DateTime) onMonthChanged;

  const ScrollableCalendar({
    super.key,
    required this.selectedYear,
    this.selectedDay,
    required this.entries,
    required this.onDaySelected,
    required this.onYearChanged,
    required this.onMonthChanged,
  });

  @override
  ScrollableCalendarState createState() => ScrollableCalendarState();
}

class ScrollableCalendarState extends State<ScrollableCalendar> {
  late ScrollController _scrollController;
  late DateTime _currentMonth;
  final double _bannerHeight = 40.0; // Height of month banner (padding + text)
  // Grid/spacing constants
  static const double _gridMainAxisSpacing = 1.0; // Must match GridView mainAxisSpacing
  static const double _horizontalPadding = 4.0; // Must match container padding

  // These are computed at layout-time based on available width
  double _monthItemExtent = 0;
  double _rowHeight = 0; // Square cell size based on width
  double? _viewportHeight; // For centering month within viewport
  bool _didInitialCenter = false; // Prevent auto-centering on resize
  bool _isAdjustingForResize = false; // Prevent scroll listener interference during resize
  
  // Use current year as base date for more accurate calculations
  late final DateTime _baseDate;
  final int _centerOffset = 600; // Center point for infinite scrolling
  
  // (Fixed-height mode active; helper not used)

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _baseDate = DateTime(2020, 1); // Keep stable base date
    
    _scrollController = ScrollController(
      // Will center after first layout when true extents are known
      initialScrollOffset: 0,
    );
    
    // Add scroll listener for month change detection
    _scrollController.addListener(_onScroll);
    // Do not auto-center here; we will center once after first layout within build when rowHeight is known
  }

  @override
  void didUpdateWidget(ScrollableCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedYear != oldWidget.selectedYear) {
      // Update current month to match new year
      _currentMonth = DateTime(widget.selectedYear, _currentMonth.month);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Convert a DateTime to a consistent month index
  int _getMonthIndex(DateTime date) {
    final monthsSinceBase = (date.year - _baseDate.year) * 12 + 
                           (date.month - _baseDate.month);
    return _centerOffset + monthsSinceBase;
  }

  // Convert a month index back to DateTime
  DateTime _getMonthForIndex(int index) {
    final monthsSinceBase = index - _centerOffset;
    
    // Handle negative months properly
    int year = _baseDate.year;
    int month = _baseDate.month + monthsSinceBase;
    
    // Adjust for months outside 1-12 range
    while (month > 12) {
      month -= 12;
      year += 1;
    }
    while (month < 1) {
      month += 12;
      year -= 1;
    }
    
    return DateTime(year, month);
  }

  void _onScroll() {
    // Don't update current month during resize adjustments
    if (_isAdjustingForResize || !_scrollController.hasClients || _monthItemExtent <= 0) {
      return;
    }
    
    final scrollOffset = _scrollController.offset;
    final monthIndex = (scrollOffset / _monthItemExtent).round();
    final month = _getMonthForIndex(monthIndex);
    
    if (month.month != _currentMonth.month || month.year != _currentMonth.year) {
      setState(() {
        _currentMonth = month;
      });
      widget.onMonthChanged(month);
    }
  }

  // Public method to center on a specific date's month (no animation)
  void scrollToDate(DateTime targetDate) {
    if (!_scrollController.hasClients) return;
    final targetMonth = DateTime(targetDate.year, targetDate.month);
    _centerOnMonth(targetMonth);
  }

  void _centerOnMonth(DateTime month) {
    if (!_scrollController.hasClients || _monthItemExtent <= 0) return;
    final index = _getMonthIndex(month);
    double offset = index * _monthItemExtent;
    if (_viewportHeight != null) {
      final extra = _viewportHeight! - _monthItemExtent;
      if (extra > 0) offset -= extra / 2;
    }
    final pos = _scrollController.position;
    _scrollController.jumpTo(offset.clamp(pos.minScrollExtent, pos.maxScrollExtent));

    if (month.month != _currentMonth.month || month.year != _currentMonth.year) {
      setState(() {
        _currentMonth = month;
      });
      widget.onMonthChanged(month);
    }
  }

  // Removed variable-height helpers for macOS stability


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildWeekdayHeaders(context),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewportHeight = constraints.maxHeight;
              // Compute fixed month extent (banner + 6 rows) based on width for stable scrolling
              final availableWidth = constraints.maxWidth - (_horizontalPadding * 2);
              final cellWidth = (availableWidth - _gridMainAxisSpacing * (7 - 1)) / 7.0;
              _rowHeight = cellWidth; // childAspectRatio is 1.0
              final fullGridHeight = (_rowHeight * 6) + (_gridMainAxisSpacing * 5);
              final newMonthItemExtent = _bannerHeight + fullGridHeight;

              // Handle resize: preserve current month position when extent changes
              if (_didInitialCenter && _monthItemExtent > 0 && newMonthItemExtent != _monthItemExtent && _scrollController.hasClients) {
                final currentIndex = _getMonthIndex(_currentMonth);
                _isAdjustingForResize = true;
                _monthItemExtent = newMonthItemExtent;
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _scrollController.hasClients) {
                    double offset = currentIndex * _monthItemExtent;
                    if (_viewportHeight != null) {
                      final extra = _viewportHeight! - _monthItemExtent;
                      if (extra > 0) offset -= extra / 2;
                    }
                    final pos = _scrollController.position;
                    _scrollController.jumpTo(offset.clamp(pos.minScrollExtent, pos.maxScrollExtent));
                    _isAdjustingForResize = false;
                  }
                });
              } else {
                _monthItemExtent = newMonthItemExtent;
              }

              // Center exactly once after first layout with valid row height
              if (!_didInitialCenter) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _scrollController.hasClients) {
                    _centerOnMonth(_currentMonth);
                    _didInitialCenter = true;
                  }
                });
              }

              return ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.vertical,
                itemExtent: _monthItemExtent,
                itemCount: _centerOffset * 2, // Provide reasonable range (2020-2070)
                itemBuilder: (context, index) {
                  final month = _getMonthForIndex(index);
                  return Column(
                    children: [
                      _buildMonthBanner(context, month),
                      SizedBox(
                        height: fullGridHeight,
                        child: _buildMonthGrid(context, month),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildWeekdayHeaders(BuildContext context) {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: weekdays.map((day) => Expanded(
          child: Container(
            height: 32,
            alignment: Alignment.center,
            child: Text(
              day,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildMonthBanner(BuildContext context, DateTime month) {
    return SizedBox(
      height: _bannerHeight,
      width: double.infinity,
      child: Center(
        child: Text(
          DateFormat('MMMM yyyy').format(month),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthGrid(BuildContext context, DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    // 0 = Sunday, ... 6 = Saturday
    final firstDayOfWeek = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;

    final cells = <Widget>[];

    // Leading days from previous month to fill the first week
    final prevMonth = DateTime(month.year, month.month - 1, 1);
    final prevMonthLastDay = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
    for (int i = firstDayOfWeek - 1; i >= 0; i--) {
      final day = prevMonthLastDay - i;
      final date = DateTime(prevMonth.year, prevMonth.month, day);
      cells.add(_buildDayCell(context, date, false, month));
    }

    // Current month days
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      cells.add(_buildDayCell(context, date, true, month));
    }

    // Trailing days from next month to complete 6 weeks (42 cells)
    const targetCells = 42; // 6 weeks * 7
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    int trailingDay = 1;
    while (cells.length < targetCells) {
      final date = DateTime(nextMonth.year, nextMonth.month, trailingDay++);
      cells.add(_buildDayCell(context, date, false, month));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1,
        mainAxisSpacing: _gridMainAxisSpacing,
        crossAxisSpacing: 1,
        children: cells,
      ),
    );
  }

  // Cache today's date to avoid repeated DateTime.now() calls
  static DateTime? _cachedToday;
  static int? _cachedTodayTimestamp;

  Widget _buildDayCell(BuildContext context, DateTime date, bool isCurrentMonth, DateTime displayMonth) {
    final now = DateTime.now();
    final todayTimestamp = now.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24); // Day precision
    
    if (_cachedTodayTimestamp != todayTimestamp) {
      _cachedToday = DateTime(now.year, now.month, now.day);
      _cachedTodayTimestamp = todayTimestamp;
    }
    
    // Pre-calculate date comparisons
    final cachedToday = _cachedToday;
    final isToday = cachedToday != null && 
                   date.year == cachedToday.year && 
                   date.month == cachedToday.month && 
                   date.day == cachedToday.day;
    
    final selectedDay = widget.selectedDay;
    final isSelected = selectedDay != null && 
                      date.year == selectedDay.year && 
                      date.month == selectedDay.month && 
                      date.day == selectedDay.day;
    
    // Filter entries more efficiently
    final dayEntries = isCurrentMonth 
        ? widget.entries.where((entry) {
            final entryDate = entry.createdAt;
            return entryDate.year == date.year && 
                   entryDate.month == date.month && 
                   entryDate.day == date.day;
          }).toList()
        : const <Entry>[];
    
    return CalendarDayCell(
      dayNumber: date.day,
      isCurrentMonth: isCurrentMonth,
      isSelected: isSelected,
      isToday: isToday,
      entries: dayEntries,
      onTap: () => widget.onDaySelected(date),
    );
  }

  // Kept for clarity; used during leading/trailing fill generation if needed in the future
  // ignore: unused_element
  Widget _buildEmptyCell(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
    );
  }


}