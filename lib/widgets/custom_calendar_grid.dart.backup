import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry.dart';
import 'calendar_day_cell.dart';

class CustomCalendarGrid extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final List<Entry> entries;
  final Function(DateTime) onDaySelected;
  final Function(DateTime) onPageChanged;
  final Function(int) onYearChanged;

  const CustomCalendarGrid({
    super.key,
    required this.focusedDay,
    this.selectedDay,
    required this.entries,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        _buildWeekdayHeaders(context),
        _buildCalendarGrid(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Year navigation only
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_left),
                onPressed: () => onYearChanged(focusedDay.year - 1),
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
                    '${focusedDay.year}',
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
                onPressed: () => onYearChanged(focusedDay.year + 1),
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
                color: Colors.grey[600],
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final firstDayOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
    final lastDayOfMonth = DateTime(focusedDay.year, focusedDay.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.weekday % 7; // Sunday = 0
    final daysInMonth = lastDayOfMonth.day;
    
    // Calculate previous month days to show
    final prevMonth = DateTime(focusedDay.year, focusedDay.month - 1);
    final daysInPrevMonth = DateTime(prevMonth.year, prevMonth.month + 1, 0).day;
    
    // Calculate total cells needed (6 weeks = 42 days)
    final totalCells = 42;
    final cells = <Widget>[];
    
    // Add previous month's trailing days
    for (int i = firstDayOfWeek - 1; i >= 0; i--) {
      final day = daysInPrevMonth - i;
      final date = DateTime(prevMonth.year, prevMonth.month, day);
      cells.add(_buildDayCell(context, date, false));
    }
    
    // Add current month days
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(focusedDay.year, focusedDay.month, day);
      cells.add(_buildDayCell(context, date, true));
    }
    
    // Add next month's leading days
    final nextMonth = DateTime(focusedDay.year, focusedDay.month + 1);
    final remainingCells = totalCells - cells.length;
    for (int day = 1; day <= remainingCells; day++) {
      final date = DateTime(nextMonth.year, nextMonth.month, day);
      cells.add(_buildDayCell(context, date, false));
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

  Widget _buildDayCell(BuildContext context, DateTime date, bool isCurrentMonth) {
    final dayEntries = entries.where((entry) => _isSameDay(entry.createdAt, date)).toList();
    final isSelected = selectedDay != null && _isSameDay(selectedDay!, date);
    final isToday = _isSameDay(DateTime.now(), date);
    
    return CalendarDayCell(
      dayNumber: date.day,
      isCurrentMonth: isCurrentMonth,
      isSelected: isSelected,
      isToday: isToday,
      entries: dayEntries,
      onTap: () => onDaySelected(date),
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
            selectedDate: focusedDay,
            onChanged: (selectedDate) {
              Navigator.pop(context);
              onYearChanged(selectedDate.year);
            },
          ),
        ),
      ),
    );
  }

}