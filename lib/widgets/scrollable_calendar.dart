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
  State<ScrollableCalendar> createState() => _ScrollableCalendarState();
}

class _ScrollableCalendarState extends State<ScrollableCalendar> {
  late ScrollController _scrollController;
  late DateTime _currentMonth;
  final double _monthHeight = 600.0; // Much larger height to ensure all 6 rows are visible
  final double _bannerHeight = 64.0; // Height of month banner (padding + text)
  double get _totalMonthHeight => _monthHeight + _bannerHeight; // Total height per month item
  
  // Use a fixed base date for consistent calculations
  final DateTime _baseDate = DateTime(2020, 1); // January 2020 as base
  final int _centerOffset = 600; // Center point for infinite scrolling

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedYear, DateTime.now().month);
    
    // Calculate initial scroll position for current month
    final currentMonthIndex = _getMonthIndex(_currentMonth);
    final initialScrollOffset = currentMonthIndex * _totalMonthHeight;
    
    _scrollController = ScrollController(
      initialScrollOffset: initialScrollOffset,
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
      final monthIndex = (scrollOffset / _totalMonthHeight).round();
      final month = _getMonthForIndex(monthIndex);
      
      if (month.month != _currentMonth.month || month.year != _currentMonth.year) {
        setState(() {
          _currentMonth = month;
        });
        widget.onMonthChanged(month);
      }
    }
  }

  void _scrollToYear(int year) {
    // Keep the same month, just change the year
    final targetMonth = DateTime(year, _currentMonth.month);
    final targetIndex = _getMonthIndex(targetMonth);
    final targetOffset = targetIndex * _totalMonthHeight;
    
    // Update current month immediately for UI consistency
    setState(() {
      _currentMonth = targetMonth;
    });
    
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildYearHeader(context),
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
                    height: _monthHeight,
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

  Widget _buildYearHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Current month display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              DateFormat('MMMM yyyy').format(_currentMonth),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          
          // Year navigation
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_left),
                onPressed: () {
                  final newYear = widget.selectedYear - 1;
                  widget.onYearChanged(newYear);
                  _scrollToYear(newYear);
                },
                tooltip: 'Previous year',
              ),
              GestureDetector(
                onTap: () => _showYearPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    '${widget.selectedYear}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_right),
                onPressed: () {
                  final newYear = widget.selectedYear + 1;
                  widget.onYearChanged(newYear);
                  _scrollToYear(newYear);
                },
                tooltip: 'Next year',
              ),
            ],
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: Text(
          DateFormat('MMMM yyyy').format(month),
          style: TextStyle(
            fontSize: 24,
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
    
    // Add empty cells for next month days to complete the grid (6 rows = 42 cells total)
    const totalCells = 42;
    final remainingCells = totalCells - cells.length;
    for (int i = 0; i < remainingCells; i++) {
      cells.add(_buildEmptyCell(context));
    }
    
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1,
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
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showYearPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Year'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: YearPicker(
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            selectedDate: DateTime(widget.selectedYear, 1),
            onChanged: (selectedDate) {
              Navigator.pop(context);
              widget.onYearChanged(selectedDate.year);
              _scrollToYear(selectedDate.year);
            },
          ),
        ),
      ),
    );
  }
}