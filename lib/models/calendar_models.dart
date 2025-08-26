import 'package:flutter/material.dart';

@immutable
class CalendarDay {
  final DateTime date;
  final String? imagePath;
  final String? thumbnailPath;
  final bool hasEntry;
  final int entryCount;

  const CalendarDay({
    required this.date,
    this.imagePath,
    this.thumbnailPath,
    this.hasEntry = false,
    this.entryCount = 0,
  });

  bool get hasImage => imagePath != null || thumbnailPath != null;

  CalendarDay copyWith({
    DateTime? date,
    String? imagePath,
    String? thumbnailPath,
    bool? hasEntry,
    int? entryCount,
  }) {
    return CalendarDay(
      date: date ?? this.date,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      hasEntry: hasEntry ?? this.hasEntry,
      entryCount: entryCount ?? this.entryCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarDay &&
        other.date.year == date.year &&
        other.date.month == date.month &&
        other.date.day == date.day &&
        other.imagePath == imagePath &&
        other.thumbnailPath == thumbnailPath &&
        other.hasEntry == hasEntry &&
        other.entryCount == entryCount;
  }

  @override
  int get hashCode {
    return Object.hash(
      date.year,
      date.month,
      date.day,
      imagePath,
      thumbnailPath,
      hasEntry,
      entryCount,
    );
  }
}

@immutable
class MonthData {
  final DateTime month;
  final List<CalendarDay> days;
  final bool isLoaded;

  const MonthData({
    required this.month,
    required this.days,
    this.isLoaded = false,
  });

  int get year => month.year;
  int get monthNumber => month.month;

  MonthData copyWith({
    DateTime? month,
    List<CalendarDay>? days,
    bool? isLoaded,
  }) {
    return MonthData(
      month: month ?? this.month,
      days: days ?? this.days,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonthData &&
        other.month == month &&
        other.isLoaded == isLoaded;
  }

  @override
  int get hashCode => Object.hash(month, isLoaded);
}

class CalendarViewportInfo {
  final DateTime firstVisibleMonth;
  final DateTime lastVisibleMonth;
  final double scrollOffset;

  const CalendarViewportInfo({
    required this.firstVisibleMonth,
    required this.lastVisibleMonth,
    required this.scrollOffset,
  });
}