import '../utils/date_extensions.dart';

class DateCalculationService {
  static List<DateTime> getMonthsInRange(DateTime start, DateTime end) {
    final months = <DateTime>[];
    DateTime current = start.firstDayOfMonth;
    
    while (current.isBefore(end) || current.isSameMonth(end)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    
    return months;
  }

  static DateTime getMonthFromScrollOffset(
    double offset,
    double monthHeight,
    DateTime firstMonth,
  ) {
    final monthIndex = (offset / monthHeight).floor();
    return DateTime(firstMonth.year, firstMonth.month + monthIndex, 1);
  }

  static double getScrollOffsetForMonth(
    DateTime targetMonth,
    DateTime firstMonth,
    double monthHeight,
  ) {
    int monthDifference = (targetMonth.year - firstMonth.year) * 12 +
        (targetMonth.month - firstMonth.month);
    
    return monthDifference * monthHeight;
  }

  static bool isDateInRange(DateTime date, DateTime start, DateTime end) {
    return !date.isBefore(start) && !date.isAfter(end);
  }

  static int getWeeksInMonth(DateTime month) {
    final firstDay = month.firstDayOfMonth;
    final lastDay = month.lastDayOfMonth;
    final leadingDays = firstDay.weekdayStartingSunday;
    final totalDays = leadingDays + lastDay.day;
    
    return (totalDays / 7).ceil();
  }

  static double calculateMonthHeight(DateTime month) {
    final weeks = getWeeksInMonth(month);
    const dayHeight = 80.0;
    const headerHeight = 40.0;
    const spacing = 16.0;
    
    return headerHeight + (weeks * dayHeight) + spacing;
  }
}