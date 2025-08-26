extension DateTimeExtensions on DateTime {
  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  bool isSameMonth(DateTime other) {
    return year == other.year && month == other.month;
  }

  DateTime get firstDayOfMonth {
    return DateTime(year, month, 1);
  }

  DateTime get lastDayOfMonth {
    return DateTime(year, month + 1, 0);
  }

  int get daysInMonth {
    return lastDayOfMonth.day;
  }

  int get weekdayStartingSunday {
    return weekday == 7 ? 0 : weekday;
  }

  DateTime copyWith({
    int? year,
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
  }) {
    return DateTime(
      year ?? this.year,
      month ?? this.month,
      day ?? this.day,
      hour ?? this.hour,
      minute ?? this.minute,
      second ?? this.second,
    );
  }

  List<DateTime> getDaysInMonth() {
    final days = <DateTime>[];
    final lastDay = lastDayOfMonth;
    
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(year, month, i));
    }
    
    return days;
  }

  List<DateTime?> getCalendarDaysForMonth() {
    final days = <DateTime?>[];
    final firstDay = firstDayOfMonth;
    final daysInMonth = this.daysInMonth;
    
    final leadingEmptyDays = firstDay.weekdayStartingSunday;
    for (int i = 0; i < leadingEmptyDays; i++) {
      days.add(null);
    }
    
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(year, month, i));
    }
    
    while (days.length % 7 != 0) {
      days.add(null);
    }
    
    return days;
  }
}