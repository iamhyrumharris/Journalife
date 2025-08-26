import 'package:flutter/material.dart';
import '../../utils/calendar_constants.dart';

class StickyWeekHeader extends StatelessWidget {
  const StickyWeekHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CalendarConstants.dayGap),
        child: Row(
          children: CalendarConstants.weekDays.map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: CalendarConstants.weekHeaderFontSize,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class FixedWeekHeader extends StatelessWidget {
  const FixedWeekHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverPersistentHeader(
      pinned: true,
      delegate: _WeekHeaderDelegate(),
    );
  }
}

class _WeekHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _WeekHeaderDelegate();

  @override
  double get minExtent => 40.0;

  @override
  double get maxExtent => 40.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return const StickyWeekHeader();
  }

  @override
  bool shouldRebuild(_WeekHeaderDelegate oldDelegate) => false;
}