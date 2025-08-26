import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/calendar_constants.dart';

class MonthHeader extends StatelessWidget {
  final DateTime month;

  const MonthHeader({
    super.key,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = DateFormat.yMMMM().format(month);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        monthName,
        style: theme.textTheme.titleLarge?.copyWith(
          fontSize: CalendarConstants.monthHeaderFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}