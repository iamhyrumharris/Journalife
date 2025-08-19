# Variable-Height Calendar Implementation Research

## Executive Summary

Research for implementing a variable-height calendar (4-6 weeks) that adapts to each month's actual week count for optimal scrolling performance. The current implementation uses a fixed 6-week (42 cells) grid for every month, creating unnecessary empty rows and scrolling issues.

## Current Implementation Analysis

### Architecture Overview
- **File**: `/Users/hyrumharris/src/journal_new/lib/widgets/scrollable_calendar.dart`
- **Structure**: ListView.builder with fixed `itemExtent` for predictable scrolling
- **Height Calculation**: `_monthItemExtent = _bannerHeight + fullGridHeight`
  - Banner: 40.0px
  - Grid: `(_rowHeight * 6) + (_gridMainAxisSpacing * 5)` (always 6 rows)
- **Cell Generation**: Always creates 42 cells (6 weeks × 7 days)

### Performance Characteristics
- **Advantages**: Consistent scroll physics, predictable positioning, smooth infinite scrolling
- **Disadvantages**: Visual gaps for 4-5 week months, wasted screen space, layout jumps

## Week Count Calculation Algorithms

### Core Algorithm for Month Week Count
```dart
int getMonthWeekCount(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  final lastDay = DateTime(month.year, month.month + 1, 0);
  
  // Sunday = 0, Monday = 1, ..., Saturday = 6
  final firstDayOfWeek = firstDay.weekday == 7 ? 0 : firstDay.weekday;
  final daysInMonth = lastDay.day;
  
  // Calculate total cells needed for this month
  final totalCells = firstDayOfWeek + daysInMonth;
  
  // Return number of weeks (rows) needed
  return (totalCells / 7).ceil();
}
```

### Month-Specific Week Counts
Based on calendar mathematics:
- **February (non-leap)**: 4 weeks if starts on Sunday, 5 weeks otherwise
- **February (leap year)**: 4 weeks if starts on Saturday/Sunday, 5 weeks otherwise  
- **30-day months**: 5 weeks if starts Sat/Sun, 6 weeks otherwise
- **31-day months**: 5 weeks if starts Sun, 6 weeks otherwise

### Threshold-Based Approach (Optimized)
```dart
static const List<int> dayThresholds = [5, 1, 5, 6, 5, 6, 5, 5, 6, 5, 6, 5];

int getMonthWeekCountFast(int month, int year) {
  final firstDay = DateTime(year, month, 1).weekday;
  final adjustedFirstDay = firstDay == 7 ? 0 : firstDay; // Convert to 0-6
  final baseWeeks = month == 2 ? 4 : 5; // February special case
  return baseWeeks + (adjustedFirstDay >= dayThresholds[month - 1] ? 1 : 0);
}
```

## Flutter Variable-Height ListView Techniques

### Option 1: Remove itemExtent (Simplest)
**Approach**: Remove fixed `itemExtent`, let ListView calculate heights dynamically
```dart
ListView.builder(
  controller: _scrollController,
  scrollDirection: Axis.vertical,
  // Remove: itemExtent: _monthItemExtent,
  itemCount: _centerOffset * 2,
  itemBuilder: (context, index) {
    final month = _getMonthForIndex(index);
    final weekCount = getMonthWeekCount(month);
    final gridHeight = (_rowHeight * weekCount) + (_gridMainAxisSpacing * (weekCount - 1));
    
    return Column(
      children: [
        _buildMonthBanner(context, month),
        SizedBox(
          height: gridHeight,
          child: _buildMonthGrid(context, month, weekCount),
        ),
      ],
    );
  },
)
```

**Pros**: Simple implementation, automatic height calculation
**Cons**: Less predictable scrolling, potential performance impact on scroll position calculations

### Option 2: Dynamic itemExtent with Manual Caching
**Approach**: Pre-calculate and cache month heights, use custom scroll physics
```dart
class VariableHeightCalendar extends StatefulWidget {
  // Cache for month heights
  final Map<int, double> _monthHeights = {};
  
  double _getMonthHeight(int monthIndex) {
    return _monthHeights.putIfAbsent(monthIndex, () {
      final month = _getMonthForIndex(monthIndex);
      final weekCount = getMonthWeekCount(month);
      final gridHeight = (_rowHeight * weekCount) + (_gridMainAxisSpacing * (weekCount - 1));
      return _bannerHeight + gridHeight;
    });
  }
  
  double _getOffsetForMonth(int targetMonthIndex) {
    double offset = 0;
    for (int i = 0; i < targetMonthIndex; i++) {
      offset += _getMonthHeight(i);
    }
    return offset;
  }
}
```

**Pros**: Precise scroll control, maintains smooth scrolling
**Cons**: Complex implementation, memory overhead for height cache

### Option 3: SliverList with SliverChildBuilderDelegate
**Approach**: Use CustomScrollView with SliverList for better control
```dart
CustomScrollView(
  controller: _scrollController,
  slivers: [
    SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final month = _getMonthForIndex(index);
          final weekCount = getMonthWeekCount(month);
          return _buildVariableMonthWidget(context, month, weekCount);
        },
        childCount: _centerOffset * 2,
      ),
    ),
  ],
)
```

**Pros**: Built-in support for variable heights, excellent performance
**Cons**: Different scroll behavior, requires refactoring scroll position logic

## Scroll Position Management

### Challenge: Maintaining Smooth Scrolling
With variable heights, scroll position calculations become complex:

1. **Scroll-to-Date**: Must calculate cumulative height to target month
2. **Month Change Detection**: Can't use simple offset/itemExtent division
3. **Centering**: Must account for variable viewport positioning

### Solution: Cumulative Height Tracking
```dart
class ScrollPositionManager {
  final Map<int, double> _cumulativeHeights = {};
  
  void _updateCumulativeHeights() {
    double cumulative = 0;
    for (int i = 0; i < _centerOffset * 2; i++) {
      _cumulativeHeights[i] = cumulative;
      cumulative += _getMonthHeight(i);
    }
  }
  
  int _getMonthIndexFromOffset(double offset) {
    // Binary search through cumulative heights
    int left = 0, right = _cumulativeHeights.length - 1;
    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final height = _cumulativeHeights[mid]!;
      if (height <= offset && offset < _cumulativeHeights[mid + 1]!) {
        return mid;
      } else if (height > offset) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    return left.clamp(0, _cumulativeHeights.length - 1);
  }
}
```

## Performance Optimization Strategies

### 1. Lazy Height Calculation
Only calculate heights for visible and near-visible months:
```dart
final Map<int, double> _heightCache = {};
final Set<int> _visibleRange = {};

void _updateVisibleRange(double scrollOffset, double viewportHeight) {
  // Update which months are visible/near-visible
  // Only cache heights for months in this range
}
```

### 2. RepaintBoundary Isolation
Wrap month widgets in RepaintBoundary to prevent unnecessary repaints:
```dart
RepaintBoundary(
  key: ValueKey(monthIndex),
  child: _buildVariableMonthWidget(context, month, weekCount),
)
```

### 3. const Widget Optimization
Use const constructors where possible:
```dart
const CalendarDayCell(
  key: ValueKey('${month.year}-${month.month}-$day'),
  // ... other properties
)
```

### 4. Memory-Efficient Caching
Implement LRU cache for month heights to prevent memory leaks:
```dart
class LRUMonthHeightCache {
  final int maxSize;
  final LinkedHashMap<int, double> _cache = LinkedHashMap();
  
  double? get(int monthIndex) {
    final value = _cache.remove(monthIndex);
    if (value != null) {
      _cache[monthIndex] = value; // Move to end (most recent)
    }
    return value;
  }
  
  void put(int monthIndex, double height) {
    _cache.remove(monthIndex);
    _cache[monthIndex] = height;
    if (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }
}
```

## Edge Cases and Considerations

### 1. Year Transitions
Ensure consistent week calculations across year boundaries:
```dart
// Handle December 31 → January 1 transitions
// Verify week counts for edge months (Jan, Dec, Feb)
```

### 2. Leap Year Handling
February week count changes based on leap year status:
```dart
bool isLeapYear(int year) => 
    (year % 4 == 0) && (year % 100 != 0) || (year % 400 == 0);

int getFebruaryWeekCount(int year) {
  final febFirst = DateTime(year, 2, 1);
  final isLeap = isLeapYear(year);
  final firstDayOfWeek = febFirst.weekday == 7 ? 0 : febFirst.weekday;
  
  if (isLeap) {
    return firstDayOfWeek >= 6 ? 5 : 4; // 29 days
  } else {
    return firstDayOfWeek == 0 ? 4 : 5; // 28 days
  }
}
```

### 3. Resize Handling
Variable heights complicate resize operations:
```dart
void _handleResize() {
  // Clear height cache
  _monthHeights.clear();
  _cumulativeHeights.clear();
  
  // Recalculate for current viewport
  _updateHeightCache();
  
  // Preserve current month position
  final currentMonth = _currentMonth;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _scrollToMonth(currentMonth);
  });
}
```

## Implementation Strategy Recommendation

### Recommended Approach: Hybrid Solution

1. **Phase 1**: Remove `itemExtent`, implement basic variable heights
2. **Phase 2**: Add height caching for performance
3. **Phase 3**: Implement cumulative height tracking for precise scroll control

### Rationale:
- **Progressive Enhancement**: Start simple, add complexity as needed
- **Performance Testing**: Measure impact at each phase
- **Maintainability**: Keep core logic readable and debuggable

### Code Structure:
```dart
class ScrollableCalendar extends StatefulWidget {
  // Core calendar logic remains the same
}

class _ScrollableCalendarState extends State<ScrollableCalendar> {
  // Add height management
  late final MonthHeightManager _heightManager;
  
  @override
  void initState() {
    super.initState();
    _heightManager = MonthHeightManager(
      baseDate: _baseDate,
      centerOffset: _centerOffset,
    );
  }
  
  Widget build(BuildContext context) {
    // Modified ListView.builder without itemExtent
    return ListView.builder(
      controller: _scrollController,
      itemBuilder: _buildVariableHeightMonth,
    );
  }
}

class MonthHeightManager {
  // Encapsulate all height calculation logic
  // Handle caching, performance optimization
  // Provide clean API for scroll position management
}
```

## Testing Strategy

### Unit Tests
- Week count calculation for all months (2020-2030)
- Edge cases: leap years, month boundaries
- Height calculation accuracy

### Performance Tests
- Scroll smoothness with 100+ months
- Memory usage with height caching
- Frame rate during rapid scrolling

### Visual Tests  
- Calendar appearance consistency
- Month transition smoothness
- Resize behavior validation

## Migration Impact

### Benefits
- **Visual**: Eliminates empty rows, better space utilization
- **Performance**: Reduced scroll distances, faster navigation
- **UX**: More intuitive month boundaries, cleaner appearance

### Risks
- **Scroll Behavior**: May feel different to users
- **Performance**: Potential frame drops during implementation
- **Complexity**: More complex scroll position calculations

### Mitigation
- Feature flag for A/B testing
- Performance monitoring during rollout
- Fallback to fixed-height mode if issues detected

## Conclusion

Variable-height calendar implementation is feasible with careful attention to scroll performance and position management. The hybrid approach provides the best balance of functionality, performance, and maintainability. Key success factors:

1. **Accurate week count algorithms** for consistent layout
2. **Efficient height caching** to maintain scroll smoothness  
3. **Robust scroll position management** for navigation features
4. **Comprehensive testing** to validate edge cases and performance

The implementation should prioritize scroll smoothness over perfect space optimization, with progressive enhancement to add advanced features once core functionality is stable.