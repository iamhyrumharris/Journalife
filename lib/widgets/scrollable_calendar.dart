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
  final double _weekRowHeight = 80.0; // Height per week row
  
  // Calculate dynamic height based on number of weeks needed for each month
  double _getMonthHeight(DateTime month) {
    final weeksNeeded = _getWeeksNeeded(month);
    return weeksNeeded * _weekRowHeight;
  }
  
  double _getTotalMonthHeight(DateTime month) {
    return _getMonthHeight(month) + _bannerHeight;
  }
  
  // Use current year as base date for more accurate calculations
  late final DateTime _baseDate;
  final int _centerOffset = 600; // Center point for infinite scrolling
  
  // Calculate how many weeks are needed for a month
  int _getWeeksNeeded(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    
    // Calculate first day of week (0 = Sunday, 1 = Monday, etc.)
    final firstDayOfWeek = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;
    
    // Calculate total cells needed
    final totalCells = firstDayOfWeek + daysInMonth;
    
    // Calculate weeks needed (round up to nearest week)
    return (totalCells / 7).ceil();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _baseDate = DateTime(2020, 1); // Keep stable base date
    
    // Calculate where current month should be and scroll there
    final currentMonthIndex = _getMonthIndex(_currentMonth);
    final approximateHeight = _weekRowHeight * 5 + _bannerHeight;
    final currentMonthPosition = currentMonthIndex * approximateHeight;
    
    _scrollController = ScrollController(
      initialScrollOffset: currentMonthPosition, // Start at current month position
    );
    
    // Add scroll listener for month change detection
    _scrollController.addListener(_onScroll);
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
    if (_scrollController.hasClients) {
      final scrollOffset = _scrollController.offset;
      final approximateHeight = _weekRowHeight * 5 + _bannerHeight;
      final monthIndex = (scrollOffset / approximateHeight).round();
      final month = _getMonthForIndex(monthIndex);
      
      if (month.month != _currentMonth.month || month.year != _currentMonth.year) {
        setState(() {
          _currentMonth = month;
        });
        widget.onMonthChanged(month);
      }
    }
  }

  // Public method to scroll to a specific date
  void scrollToDate(DateTime targetDate) {
    if (!_scrollController.hasClients) return;
    
    final targetMonth = DateTime(targetDate.year, targetDate.month);
    final currentScrollMonth = _currentMonth;
    
    // Calculate how many months to move from current position
    final monthsDifference = (targetMonth.year - currentScrollMonth.year) * 12 + 
                            (targetMonth.month - currentScrollMonth.month);
    
    if (monthsDifference == 0) return; // Already at target month
    
    // Calculate approximate offset change needed
    final approximateHeight = _weekRowHeight * 5 + _bannerHeight;
    final currentOffset = _scrollController.offset;
    final targetOffset = currentOffset + (monthsDifference * approximateHeight);
    
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    
    // Update current month and trigger callback
    setState(() {
      _currentMonth = targetMonth;
    });
    widget.onMonthChanged(_currentMonth);
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildWeekdayHeaders(context),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.vertical,
            itemCount: _centerOffset * 2, // Provide reasonable range (2020-2070)
            itemBuilder: (context, index) {
              final month = _getMonthForIndex(index);
              return Column(
                children: [
                  _buildMonthBanner(context, month),
                  SizedBox(
                    height: _getMonthHeight(month),
                    child: _buildMonthGrid(context, month),
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
    
    // Calculate first day of week (0 = Sunday, 1 = Monday, etc.)
    final firstDayOfWeek = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;
    
    
    final cells = <Widget>[];
    
    // Add empty cells for previous month days
    for (int i = 0; i < firstDayOfWeek; i++) {
      cells.add(_buildEmptyCell(context));
    }
    
    // Add current month days
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      cells.add(_buildDayCell(context, date, true, month));
    }
    
    // Calculate how many weeks we need and fill to complete those weeks only
    final weeksNeeded = _getWeeksNeeded(month);
    final totalCells = weeksNeeded * 7;
    final remainingCells = totalCells - cells.length;
    for (int i = 0; i < remainingCells; i++) {
      cells.add(_buildEmptyCell(context));
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: cells,
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime date, bool isCurrentMonth, DateTime displayMonth) {
    final dayEntries = widget.entries.where((entry) => _isSameDay(entry.createdAt, date)).toList();
    final isSelected = widget.selectedDay != null && _isSameDay(widget.selectedDay!, date);
    final isToday = _isSameDay(DateTime.now(), date);
    
    return CalendarDayCell(
      dayNumber: date.day,
      isCurrentMonth: isCurrentMonth,
      isSelected: isSelected,
      isToday: isToday,
      entries: dayEntries,
      onTap: () => widget.onDaySelected(date),
    );
  }

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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

}