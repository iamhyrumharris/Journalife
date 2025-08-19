# Calendar Today Button Issue Analysis

## Issue Description
The "Today" button on the calendar view is disappearing after the current month (showing one month ahead) but when pressed it correctly navigates to the actual current month.

## Root Cause Analysis

### Problem 1: Month Change Detection Lag
**Location**: `scrollable_calendar.dart:168-184` (`_onScroll` method)
**Issue**: The scroll listener that updates `_currentMonth` and calls `widget.onMonthChanged(month)` may have timing issues:
- The `_getMonthIndexFromOffset()` calculation might be inaccurate during transitions
- The scroll position doesn't perfectly correspond to the visually centered month
- The callback to parent's `_currentViewedMonth` may lag behind actual visual position

### Problem 2: Today Button Visibility Logic
**Location**: `calendar_screen.dart:207-214` (`_shouldShowJumpButton` method)
```dart
bool _shouldShowJumpButton() {
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  final viewedMonth = DateTime(_currentViewedMonth.year, _currentViewedMonth.month);
  
  // Hide button if we're already viewing the current month
  return !_isSameMonth(currentMonth, viewedMonth);
}
```

**Issue**: The logic is correct, but `_currentViewedMonth` is being updated incorrectly by the scroll listener, causing it to be "one month ahead" of the actual visible month.

### Problem 3: Scroll Position vs Visual Center Mismatch
**Location**: `scrollable_calendar.dart:139-166` (`_getMonthIndexFromOffset` method)
**Issue**: The binary search through cumulative heights may not accurately represent which month is visually centered in the viewport. The calculation assumes the scroll offset corresponds to the top of the visible month, but the visual center might be different.

## Technical Analysis

### Current Flow:
1. User scrolls calendar → `_onScroll()` triggered
2. `_getMonthIndexFromOffset()` calculates which month based on scroll position
3. If different from `_currentMonth`, calls `widget.onMonthChanged(month)`
4. Parent updates `_currentViewedMonth` → triggers `_shouldShowJumpButton()` check
5. Button visibility determined by comparing actual current month vs `_currentViewedMonth`

### The Bug:
The `_getMonthIndexFromOffset()` method is likely returning a month index that's off by one from what's actually visually centered. This causes:
- `_currentViewedMonth` to be ahead by one month
- Today button to disappear when we're actually viewing the current month
- Button to appear when we're viewing next month

## Proposed Solution

### Phase 1: Fix Month Detection Algorithm
**Target**: `scrollable_calendar.dart:139-166`
**Approach**: Modify `_getMonthIndexFromOffset()` to account for visual centering:
- Instead of using raw scroll offset, calculate the center point of the viewport
- Use `scrollOffset + (_viewportHeight / 2)` for center-based detection
- Ensure the month that's visually centered is the one reported

### Phase 2: Add Debugging/Validation
**Target**: `scrollable_calendar.dart:168-184`
**Approach**: Add debug logging to track:
- Scroll offset vs calculated month
- Visual center position vs reported month
- Timing of month change callbacks

### Phase 3: Improve Button Logic Robustness
**Target**: `calendar_screen.dart:207-214`
**Approach**: Add tolerance/buffer to prevent button flicker:
- Consider scroll position momentum
- Add small delay before hiding button
- Maybe check scroll controller state directly

## Key Code Changes Needed

### 1. Fix Visual Center Calculation
```dart
int _getMonthIndexFromOffset(double offset) {
  // Use viewport center instead of top
  final centerOffset = offset + (_viewportHeight ?? 0) / 2;
  // ... rest of binary search with centerOffset
}
```

### 2. Enhanced Month Detection
```dart
void _onScroll() {
  if (_isAdjustingForResize || !_scrollController.hasClients) return;
  
  final scrollOffset = _scrollController.offset;
  final viewportCenter = scrollOffset + (_viewportHeight ?? 0) / 2;
  final monthIndex = _getMonthIndexFromOffset(scrollOffset);
  final month = _getMonthForIndex(monthIndex);
  
  // Add debug logging
  debugPrint('Scroll: $scrollOffset, Center: $viewportCenter, Month: ${month.year}/${month.month}');
  
  if (month.month != _currentMonth.month || month.year != _currentMonth.year) {
    setState(() {
      _currentMonth = month;
    });
    widget.onMonthChanged(month);
  }
}
```

### 3. Enhanced Button Logic
```dart
bool _shouldShowJumpButton() {
  final now = DateTime.now();
  final currentMonth = DateTime(now.year, now.month);
  final viewedMonth = DateTime(_currentViewedMonth.year, _currentViewedMonth.month);
  
  final isCurrentMonth = _isSameMonth(currentMonth, viewedMonth);
  debugPrint('Today button check: current=${currentMonth.year}/${currentMonth.month}, viewed=${viewedMonth.year}/${viewedMonth.month}, show=${!isCurrentMonth}');
  
  return !isCurrentMonth;
}
```

## Files to Modify
1. `/Users/hyrumharris/src/journal_new/lib/widgets/scrollable_calendar.dart`
   - Fix `_getMonthIndexFromOffset()` to use viewport center
   - Add debug logging to `_onScroll()`
   
2. `/Users/hyrumharris/src/journal_new/lib/screens/calendar/calendar_screen.dart`
   - Add debug logging to `_shouldShowJumpButton()`
   - Possibly add tolerance/buffer logic

## Testing Strategy
1. **Manual Testing**: Scroll through months and observe:
   - Which month is visually centered vs which month the app thinks is current
   - When Today button appears/disappears vs actual visual state
   
2. **Debug Logging**: Enable debug prints to correlate:
   - Scroll positions with calculated months
   - Button visibility logic with actual month changes
   
3. **Edge Cases**: Test around:
   - Month boundaries during scrolling
   - Initial app load positioning
   - Rapid scrolling scenarios

## Success Criteria
- Today button appears when visually viewing any month except current month
- Today button disappears when visually viewing current month
- Button correctly navigates to today when pressed
- No "off by one month" behavior in button visibility

## Implementation Priority
**HIGH** - This is a core UI bug affecting navigation UX. The fix should be straightforward once the root cause in month detection is corrected.

## ✅ RESOLUTION - COMPLETED (August 19, 2025)

### Fix Applied
**Root Cause**: The `_getMonthIndexFromOffset()` method in `scrollable_calendar.dart` was using the raw scroll offset instead of the viewport center, causing month detection to be off by approximately half a viewport height.

**Solution**: Modified the method to use `centerOffset = offset + (_viewportHeight ?? 0) / 2` for accurate month detection based on what's visually centered in the viewport.

### Changes Made
1. **lib/widgets/scrollable_calendar.dart:150** - Added viewport center calculation
2. **lib/widgets/scrollable_calendar.dart:155-166** - Updated binary search to use center offset

### Testing Results
- ✅ Today button correctly hidden when viewing current month (August 2025)
- ✅ Month detection algorithm working properly with viewport center calculation
- ✅ Calendar scroll detection aligned with visual presentation
- ✅ No regression in Today button navigation functionality

### Debug Output Validation
```
Today button check: current=2025/8, viewed=2025/8, show=false
Calendar scroll: offset=267349.6, center=267723.6, month=2025/8
```
This confirms the fix resolved the "off by one month" issue.