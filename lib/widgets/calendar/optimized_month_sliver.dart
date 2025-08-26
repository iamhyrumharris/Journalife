import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/calendar_models.dart';
import '../../models/attachment.dart';
import '../../providers/calendar_state_provider.dart';
import '../../utils/calendar_constants.dart';
import '../../utils/date_extensions.dart';
import '../../services/local_file_storage_service.dart';

class OptimizedMonthSliver extends ConsumerStatefulWidget {
  final DateTime month;
  final void Function(DateTime)? onDayTapped;
  
  const OptimizedMonthSliver({
    super.key,
    required this.month,
    this.onDayTapped,
  });

  @override
  ConsumerState<OptimizedMonthSliver> createState() => _OptimizedMonthSliverState();
}

class _OptimizedMonthSliverState extends ConsumerState<OptimizedMonthSliver> 
    with AutomaticKeepAliveClientMixin {
  late String _monthName;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _monthName = DateFormat.yMMMM().format(widget.month);
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final calendarDays = ref.watch(calendarDaysProvider(widget.month));
    
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _MonthHeader(monthName: _monthName),
        ),
        _MonthGrid(
          month: widget.month,
          calendarDays: calendarDays,
          onDayTapped: widget.onDayTapped,
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: CalendarConstants.monthSpacing),
        ),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final String monthName;
  
  const _MonthHeader({required this.monthName});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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

class _MonthGrid extends ConsumerWidget {
  final DateTime month;
  final List<DateTime?> calendarDays;
  final void Function(DateTime)? onDayTapped;
  
  const _MonthGrid({
    required this.month,
    required this.calendarDays,
    this.onDayTapped,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthData = ref.watch(monthDataProvider(month));
    final dayMap = <DateTime, CalendarDay>{};
    
    if (monthData != null) {
      for (final day in monthData.days) {
        dayMap[day.date] = day;
      }
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
              return const _EmptyCell();
            }
            
            final calendarDay = dayMap[date];
            
            return OptimizedDayCell(
              key: ValueKey(date),
              day: calendarDay,
              date: date,
              onTapped: onDayTapped,
            );
          },
          childCount: calendarDays.length,
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
        ),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();
  
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

class OptimizedDayCell extends ConsumerWidget {
  final CalendarDay? day;
  final DateTime date;
  final void Function(DateTime)? onTapped;
  
  const OptimizedDayCell({
    super.key,
    this.day,
    required this.date,
    this.onTapped,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday = date.isSameDay(now);
    final selectedDate = ref.watch(selectedDateProvider);
    final isSelected = selectedDate != null && date.isSameDay(selectedDate);
    
    return GestureDetector(
      onTap: onTapped != null ? () => onTapped!(date) : null,
      child: Container(
        decoration: BoxDecoration(
          color: day?.hasImage == true 
              ? null 
              : (isDark ? CalendarColors.emptyDayDark : CalendarColors.emptyDayLight),
          border: isSelected
              ? Border.all(
                  color: theme.primaryColor,
                  width: 2.0,
                )
              : isToday
                  ? Border.all(
                      color: isDark
                          ? CalendarColors.todayBorderDark
                          : CalendarColors.todayBorderLight,
                      width: CalendarColors.todayBorderWidth,
                    )
                  : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image if available
              if (day?.hasImage == true) _buildImage(day!),
              
              // Dark overlay for better text readability on images
              if (day?.hasImage == true)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),
              
              // Day number
              Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: day?.hasImage == true
                        ? Colors.white
                        : (isSelected 
                            ? theme.primaryColor
                            : (isToday
                                ? theme.primaryColor
                                : (isDark ? Colors.white : Colors.black87))),
                    fontSize: CalendarConstants.dayNumberFontSize,
                    fontWeight: (isToday || isSelected) ? FontWeight.bold : FontWeight.w600,
                    shadows: day?.hasImage == true
                        ? const [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black54,
                              offset: Offset(1, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              
              // Entry indicator dots at bottom
              if (day != null && day!.entryCount > 0)
                _buildEntryIndicator(day!.entryCount),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildImage(CalendarDay day) {
    if (day.thumbnailPath == null) return const SizedBox.shrink();
    
    return _LazyImageLoader(
      imagePath: day.thumbnailPath!,
    );
  }
  
  Widget _buildEntryIndicator(int entryCount) {
    // Determine number of dots to show (max 3)
    final dotsToShow = entryCount > 3 ? 3 : entryCount;
    final showPlus = entryCount > 3;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show dots
              for (int i = 0; i < dotsToShow; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              // Show + if more than 3 entries
              if (showPlus) ...[
                const SizedBox(width: 3),
                const Text(
                  '+',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lazy image loader widget for calendar day cells
class _LazyImageLoader extends StatefulWidget {
  final String imagePath;
  
  const _LazyImageLoader({
    required this.imagePath,
  });
  
  @override
  State<_LazyImageLoader> createState() => _LazyImageLoaderState();
}

class _LazyImageLoaderState extends State<_LazyImageLoader> {
  static final LocalFileStorageService _storageService = LocalFileStorageService();
  File? _imageFile;
  bool _isLoading = true;
  bool _hasError = false;
  
  @override
  void initState() {
    super.initState();
    _loadImage();
  }
  
  @override
  void didUpdateWidget(_LazyImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImage();
    }
  }
  
  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      File? file;
      
      // Check if it's an absolute path
      if (widget.imagePath.startsWith('/') || widget.imagePath.contains(':')) {
        file = File(widget.imagePath);
        if (!await file.exists()) {
          file = null;
        }
      } else {
        // Relative path - use storage service
        file = await _storageService.getFile(widget.imagePath);
        if (file != null && !await file.exists()) {
          file = null;
        }
      }
      
      if (mounted) {
        setState(() {
          _imageFile = file;
          _isLoading = false;
          _hasError = file == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey[300],
      );
    }
    
    if (_hasError || _imageFile == null) {
      return Container(
        color: Colors.grey[300],
      );
    }
    
    return Image.file(
      _imageFile!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
        );
      },
    );
  }
}