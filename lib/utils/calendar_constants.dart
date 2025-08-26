import 'package:flutter/material.dart';

class CalendarConstants {
  static const int monthsInViewport = 6;
  static const int maxCachedMonths = 12;
  static const int yearsToLoad = 10;
  
  static const double dayNumberFontSize = 16.0;
  static const double monthHeaderFontSize = 20.0;
  static const double weekHeaderFontSize = 14.0;
  
  static const double dayGap = 1.0;
  static const double monthSpacing = 24.0;
  
  static const int thumbnailSize = 150;
  static const int thumbnailQuality = 85;
  
  static const Duration scrollDebounce = Duration(milliseconds: 100);
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  static const double pullToLoadThreshold = 80.0;
  static const Duration pullToLoadAnimationDuration = Duration(milliseconds: 200);
  static const int monthsToLoadOnPull = 3;
  
  static const List<String> weekDays = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];
}

class CalendarColors {
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color darkBackground = Color(0xFF121212);
  
  static const Color lightDayBackground = Colors.white;
  static const Color darkDayBackground = Color(0xFF1E1E1E);
  
  static const Color emptyDayLight = Color(0xFFE0E0E0);
  static const Color emptyDayDark = Color(0xFF2C2C2C);
  
  static const Color todayBorderLight = Colors.blue;
  static const Color todayBorderDark = Colors.blueAccent;
  
  static const double todayBorderWidth = 2.0;
}