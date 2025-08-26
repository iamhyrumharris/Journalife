import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_models.dart';
import '../../providers/calendar_state_provider.dart';
import '../../utils/calendar_constants.dart';
import '../../utils/date_extensions.dart';
import 'day_cell.dart';

class MonthSliver extends ConsumerWidget {
  final DateTime month;

  const MonthSliver({
    super.key,
    required this.month,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthData = ref.watch(monthDataProvider(month));
    
    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.only(bottom: CalendarConstants.monthSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthHeader(context),
              _buildDayGrid(context, monthData),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = DateFormat.yMMMM().format(month);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        monthName,
        style: theme.textTheme.titleLarge?.copyWith(
          fontSize: CalendarConstants.monthHeaderFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDayGrid(BuildContext context, MonthData? monthData) {
    final calendarDays = month.getCalendarDaysForMonth();
    final dayMap = <DateTime, CalendarDay>{};
    
    if (monthData != null) {
      for (final day in monthData.days) {
        dayMap[day.date] = day;
      }
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: CalendarConstants.dayGap),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: CalendarConstants.dayGap,
        crossAxisSpacing: CalendarConstants.dayGap,
        childAspectRatio: 1.0,
      ),
      itemCount: calendarDays.length,
      itemBuilder: (context, index) {
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
    );
  }
}

class MonthSection extends ConsumerWidget {
  final DateTime month;

  const MonthSection({
    super.key,
    required this.month,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthData = ref.watch(monthDataProvider(month));
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: CalendarConstants.monthSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, theme),
          _buildGrid(monthData),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final monthName = DateFormat.yMMMM().format(month);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        monthName,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontSize: CalendarConstants.monthHeaderFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGrid(MonthData? monthData) {
    final calendarDays = month.getCalendarDaysForMonth();
    final dayMap = <DateTime, CalendarDay>{};
    
    if (monthData != null) {
      for (final day in monthData.days) {
        dayMap[day.date] = day;
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CalendarConstants.dayGap),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = (constraints.maxWidth - (6 * CalendarConstants.dayGap)) / 7;
          final rows = (calendarDays.length / 7).ceil();
          
          return SizedBox(
            height: rows * cellWidth + (rows - 1) * CalendarConstants.dayGap,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: CalendarConstants.dayGap,
                crossAxisSpacing: CalendarConstants.dayGap,
                childAspectRatio: 1.0,
              ),
              itemCount: calendarDays.length,
              itemBuilder: (context, index) {
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
            ),
          );
        },
      ),
    );
  }
}