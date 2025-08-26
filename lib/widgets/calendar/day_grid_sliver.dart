import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/calendar_models.dart';
import '../../utils/calendar_constants.dart';
import '../../utils/date_extensions.dart';
import 'day_cell.dart';

class DayGridSliver extends ConsumerWidget {
  final DateTime month;
  final List<CalendarDay> days;

  const DayGridSliver({
    super.key,
    required this.month,
    required this.days,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarDays = month.getCalendarDaysForMonth();
    final dayMap = <DateTime, CalendarDay>{};
    
    for (final day in days) {
      dayMap[day.date] = day;
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: CalendarConstants.dayGap),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: CalendarConstants.dayGap,
          crossAxisSpacing: CalendarConstants.dayGap,
          childAspectRatio: 1.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= calendarDays.length) return null;
            
            final date = calendarDays[index];
            
            if (date == null) {
              return const DayCell(isEmpty: true);
            }
            
            final calendarDay = dayMap[date];
            
            return DayCell(
              day: calendarDay,
              date: date,
            );
          },
          childCount: calendarDays.length,
        ),
      ),
    );
  }
}