import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import '../../providers/calendar_state_provider.dart';
import '../../services/date_calculation_service.dart';
import '../../utils/calendar_constants.dart';
import '../../utils/date_extensions.dart';
import '../headers/sticky_week_header.dart';
import '../headers/month_header.dart';
import 'month_sliver.dart';

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

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late ScrollController _scrollController;
  Timer? _scrollDebounce;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToCurrentMonth();
    });
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final minScroll = _scrollController.position.minScrollExtent;
    
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(CalendarConstants.scrollDebounce, () {
      ref.read(scrollPositionProvider.notifier).updatePosition(offset);
      
      if (offset >= maxScroll - 500 && !_isLoadingMore) {
        _loadMoreMonths(true);
      } else if (offset <= minScroll + 500 && !_isLoadingMore) {
        _loadMoreMonths(false);
      }
      
      _updateVisibleMonths(offset);
    });
  }

  void _loadMoreMonths(bool atEnd) {
    if (_isLoadingMore) return;
    
    _isLoadingMore = true;
    
    if (atEnd) {
      ref.read(visibleMonthsProvider.notifier).addMonthsAtEnd(3);
    } else {
      final previousOffset = _scrollController.offset;
      ref.read(visibleMonthsProvider.notifier).addMonthsAtStart(3);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final monthHeight = DateCalculationService.calculateMonthHeight(DateTime.now());
          _scrollController.jumpTo(previousOffset + (3 * monthHeight));
        }
      });
    }
    
    Future.delayed(const Duration(milliseconds: 500), () {
      _isLoadingMore = false;
    });
  }

  void _updateVisibleMonths(double offset) {
    final visibleMonths = ref.read(visibleMonthsProvider);
    if (visibleMonths.isEmpty) return;
    
    final monthHeight = DateCalculationService.calculateMonthHeight(DateTime.now());
    final firstVisibleIndex = (offset / monthHeight).floor();
    final lastVisibleIndex = ((offset + MediaQuery.of(context).size.height) / monthHeight).ceil();
    
    if (firstVisibleIndex >= 0 && lastVisibleIndex < visibleMonths.length) {
      final firstMonth = visibleMonths[firstVisibleIndex];
      final lastMonth = visibleMonths[lastVisibleIndex.clamp(0, visibleMonths.length - 1)];
      
      ref.read(visibleMonthsProvider.notifier).updateVisibleRange(firstMonth, lastMonth);
    }
  }

  void _jumpToCurrentMonth() {
    final visibleMonths = ref.read(visibleMonthsProvider);
    final now = DateTime.now();
    final currentMonthIndex = visibleMonths.indexWhere((month) => month.isSameMonth(now));
    
    if (currentMonthIndex != -1 && _scrollController.hasClients) {
      final monthHeight = DateCalculationService.calculateMonthHeight(now);
      final targetOffset = currentMonthIndex * monthHeight;
      
      _scrollController.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleMonths = ref.watch(visibleMonthsProvider);
    
    if (visibleMonths.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _onScroll();
        }
        return false;
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          const SliverPersistentHeader(
            pinned: true,
            delegate: _WeekHeaderDelegate(),
          ),
          ..._buildMonthSlivers(visibleMonths),
        ],
      ),
    );
  }

  List<Widget> _buildMonthSlivers(List<DateTime> months) {
    final slivers = <Widget>[];
    
    for (final month in months) {
      slivers.add(
        SliverStickyHeader(
          header: MonthHeader(month: month),
          sliver: MonthSliver(month: month),
        ),
      );
    }
    
    return slivers;
  }
}

class OptimizedCalendarView extends ConsumerStatefulWidget {
  const OptimizedCalendarView({super.key});

  @override
  ConsumerState<OptimizedCalendarView> createState() => _OptimizedCalendarViewState();
}

class _OptimizedCalendarViewState extends ConsumerState<OptimizedCalendarView> {
  late ScrollController _scrollController;
  final GlobalKey _scrollKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentMonth();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentMonth() {
    final visibleMonths = ref.read(visibleMonthsProvider);
    final now = DateTime.now();
    
    for (int i = 0; i < visibleMonths.length; i++) {
      if (visibleMonths[i].isSameMonth(now)) {
        final monthHeight = DateCalculationService.calculateMonthHeight(now);
        _scrollController.animateTo(
          i * monthHeight,
          duration: CalendarConstants.animationDuration,
          curve: Curves.easeOutCubic,
        );
        break;
      }
    }
  }

  void jumpToDate(DateTime date) {
    ref.read(jumpToDateProvider)(date);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final visibleMonths = ref.read(visibleMonthsProvider);
      
      for (int i = 0; i < visibleMonths.length; i++) {
        if (visibleMonths[i].isSameMonth(date)) {
          final monthHeight = DateCalculationService.calculateMonthHeight(date);
          _scrollController.animateTo(
            i * monthHeight,
            duration: CalendarConstants.animationDuration,
            curve: Curves.easeOutCubic,
          );
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleMonths = ref.watch(visibleMonthsProvider);
    
    return CustomScrollView(
      key: _scrollKey,
      controller: _scrollController,
      slivers: [
        const SliverPersistentHeader(
          pinned: true,
          delegate: _WeekHeaderDelegate(),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= visibleMonths.length) return null;
              return MonthSection(month: visibleMonths[index]);
            },
            childCount: visibleMonths.length,
          ),
        ),
      ],
    );
  }
}