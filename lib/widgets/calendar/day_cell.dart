import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/calendar_models.dart';
import '../../providers/calendar_state_provider.dart';
import '../../utils/calendar_constants.dart';
import '../../utils/date_extensions.dart';

class DayCell extends ConsumerWidget {
  final CalendarDay? day;
  final DateTime? date;
  final bool isEmpty;

  const DayCell({
    super.key,
    this.day,
    this.date,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isEmpty || (day == null && date == null)) {
      return const _EmptyDayCell();
    }

    final effectiveDate = day?.date ?? date!;
    final currentDate = ref.watch(currentDateProvider);
    final isToday = effectiveDate.isSameDay(currentDate);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          border: isToday
              ? Border.all(
                  color: isDark
                      ? CalendarColors.todayBorderDark
                      : CalendarColors.todayBorderLight,
                  width: CalendarColors.todayBorderWidth,
                )
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(context, isDark),
            _buildDayNumber(context, effectiveDate, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context, bool isDark) {
    if (day?.hasImage == true) {
      if (day!.thumbnailPath != null) {
        return _buildLocalImage(day!.thumbnailPath!);
      } else if (day!.imagePath != null) {
        if (day!.imagePath!.startsWith('http')) {
          return _buildNetworkImage(day!.imagePath!);
        } else {
          return _buildLocalImage(day!.imagePath!);
        }
      }
    }

    return Container(
      color: isDark ? CalendarColors.emptyDayDark : CalendarColors.emptyDayLight,
    );
  }

  Widget _buildLocalImage(String path) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).brightness == Brightness.dark
              ? CalendarColors.emptyDayDark
              : CalendarColors.emptyDayLight,
        );
      },
    );
  }

  Widget _buildNetworkImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheHeight: CalendarConstants.thumbnailSize,
      memCacheWidth: CalendarConstants.thumbnailSize,
      placeholder: (context, url) => Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? CalendarColors.emptyDayDark
            : CalendarColors.emptyDayLight,
      ),
      errorWidget: (context, url, error) => Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? CalendarColors.emptyDayDark
            : CalendarColors.emptyDayLight,
      ),
    );
  }

  Widget _buildDayNumber(BuildContext context, DateTime date, bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: day?.hasImage == true
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
            fontSize: CalendarConstants.dayNumberFontSize,
            fontWeight: isToday(date) ? FontWeight.bold : FontWeight.normal,
            shadows: day?.hasImage == true
                ? [
                    const Shadow(
                      blurRadius: 4,
                      color: Colors.black54,
                      offset: Offset(1, 1),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.isSameDay(now);
  }
}

class _EmptyDayCell extends StatelessWidget {
  const _EmptyDayCell();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: isDark 
          ? CalendarColors.darkDayBackground.withValues(alpha: 0.3)
          : CalendarColors.lightDayBackground.withValues(alpha: 0.3),
    );
  }
}