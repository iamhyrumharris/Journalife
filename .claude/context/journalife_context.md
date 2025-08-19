# JournaLife Project Context

## Project Status
- **Version**: Single-user journal application (recently converted from multi-user)
- **Architecture**: Flutter + Riverpod + SQLite + WebDAV
- **Platforms**: iOS, Android, macOS, Windows, Linux, Web
- **Last Updated**: August 18, 2025

## Core Features (Implemented)
- ✅ Multi-journal management (single-user)
- ✅ Five main navigation views (Calendar, Timeline, Map, Attachments, Reflect)
- ✅ WebDAV synchronization (single-user)
- ✅ Rich media attachments (images, audio, files)
- ✅ Cross-platform file storage abstraction
- ✅ Offline-first architecture with sync queue
- ✅ SQLite database with relational structure
- ✅ Riverpod state management with family providers

## Current Development Focus
- **COMPLETED**: Major single-user conversion (Aug 18, 2025)
- **Architecture Simplification**: Successfully removed all multi-user infrastructure
- **Next Priority**: Address calendar scrolling performance issues

## Architecture Decisions

### State Management - Riverpod
- **Main Providers**: `databaseProvider`, `journalProvider`, `entryProvider`
- **Family Providers**: `entryProvider.family(journalId)` for journal-specific entries
- **Current Selection**: `currentJournalProvider` for cross-screen state
- **AsyncValue Pattern**: Consistent loading/error states throughout app

### Database Layer - SQLite
- **Primary Models**: Journal, Entry, Attachment, SyncConfig, SyncManifest, SyncStatus (User model removed)
- **Service**: `lib/services/database_service.dart` handles all database operations
- **Cross-Platform**: Uses `sqflite` and `sqflite_common_ffi` for platform compatibility
- **Schema Version**: v5 (simplified for single-user, removed users table and ownership fields)
- **Relationships**: Simplified foreign key relationships without user ownership

### Synchronization - WebDAV
- **Single-User**: Personal journal sync across devices (simplified paths: `/journal_app`)
- **Conflict Resolution**: Device-based conflict resolution for same-user edits
- **File Storage**: `*_file_storage_service.dart` abstracts file operations
- **Testing Tools**: Comprehensive WebDAV testing utilities included
- **Path Structure**: Simplified from username-based to fixed paths

### UI Architecture - Flutter
- **Navigation**: Bottom navigation with 5 main screens
- **Responsive**: Works across mobile, desktop, and web
- **Material Design**: Follows Material Design 3 principles
- **Cross-Platform**: Consistent UI across all supported platforms

## Key Constraints & Preferences
- **No Mood Tracking**: User has explicitly requested no mood/rating functionality
- **Single-User Focus**: Currently building for single-user experience (no sharing/collaboration)
- **Offline-First**: Must work without internet connection
- **Cross-Platform**: Must maintain feature parity across all platforms
- **Performance**: Handle large datasets (many journals/entries) efficiently

## File Structure Key Areas
```
lib/
├── models/           # Data models
├── providers/        # Riverpod providers
├── screens/          # Main UI screens
├── services/         # Business logic & external services
└── widgets/          # Reusable UI components
```

## Testing Infrastructure
- **Unit Tests**: `flutter test`
- **Integration Tests**: `dart run_integration_test.dart`
- **WebDAV Testing**: Multiple WebDAV-specific test utilities
- **Code Quality**: `flutter analyze` before all commits

## Current Challenges
*[List current technical challenges or issues]*

## Next Features to Implement
*[List upcoming features in priority order]*

## Recent Completed Work

### ✅ Today Button Calendar Navigation Fix (August 19, 2025)
**Fixed "Today" button disappearing after current month navigation bug:**
- **Root Cause**: Month detection algorithm using raw scroll offset instead of viewport center
- **Solution**: Modified `_getMonthIndexFromOffset()` to use `centerOffset = offset + (_viewportHeight ?? 0) / 2`
- **Files Changed**: `lib/widgets/scrollable_calendar.dart` (lines 150, 155-166)
- **Behavior Fixed**: Today button now correctly appears when viewing any month except current month
- **Testing**: Validated with debug logging showing proper month detection alignment
- **Impact**: Resolved core UI navigation bug affecting user experience

**Implementation Details:**
- Modified viewport center calculation for accurate month detection
- Maintained existing scroll performance and variable-height month support
- No regression in Today button navigation functionality
- Quick targeted fix addressing specific calculation error

### ✅ Calendar UI Refinement - Removed Greyed Day Interaction (August 19, 2025)
**Removed numbers and touch functionality from greyed out calendar days:**
- **Visual Cleanup**: Greyed out days (previous/future months) now appear as blank cells without day numbers
- **Interaction Removal**: Non-current month days no longer respond to touch/tap events
- **Navigation Simplification**: Month navigation limited to year picker, keyboard shortcuts, and swipe gestures
- **UX Improvement**: Eliminates confusion and accidental navigation to adjacent months via day taps
- **Accessibility Update**: Improved semantic labels to reflect non-interactive nature of greyed days
- **Code Simplification**: Removed `onNavigateToMonth` callback system and related navigation logic

**Implementation Details:**
- Files modified: `lib/widgets/calendar_day_cell.dart`, `lib/widgets/scrollable_calendar.dart`, `lib/screens/calendar/calendar_screen.dart`
- Lines changed: ~40 lines removed/modified across 3 files
- Methods removed: `_handleMonthNavigation()` from calendar screen
- Architecture: Simplified conditional rendering and interaction handling

### ✅ Variable-Height Calendar Implementation (August 19, 2025)
**Fixed calendar to show only necessary weeks (4-6) per month:**
- **Week Count Algorithm**: Implemented dynamic calculation to determine actual weeks needed per month
- **Visual Fix**: Eliminated empty grey rows by showing only required weeks (4-6 instead of always 6)
- **Scroll Performance**: Removed fixed itemExtent, implemented variable-height ListView with height caching
- **Position Management**: Added cumulative height tracking and binary search for scroll position
- **UI Improvements**: Each month now uses exactly the space it needs, creating cleaner appearance
- **Performance**: Smooth scrolling maintained through efficient height caching and position calculations
- **Edge Cases**: Properly handles February (4-5 weeks), 30-day months (5-6 weeks), 31-day months (5-6 weeks)

**Implementation Details:**
- Files modified: `lib/widgets/scrollable_calendar.dart`
- Lines changed: ~150 lines modified/added
- New methods: `_getMonthWeekCount()`, `_getMonthHeight()`, `_getMonthIndexFromOffset()`
- Architecture: Progressive enhancement approach with height caching for performance

### ✅ Calendar Single Thumbnail Display (August 19, 2025)
**Simplified calendar day cell to show single thumbnail:**
- **Smart Photo Selection**: Implemented intelligent photo selection based on entry content richness
- **UI Simplification**: Removed complex photo collage layouts (2x2, 3-photo grids, etc.)
- **Code Changes**: Modified `calendar_day_cell.dart` to display only first representative photo
- **Algorithm**: Prioritizes entries with more substantial content (content length + attachment count)
- **Visual Clarity**: Each calendar day now shows at most one thumbnail, creating cleaner appearance
- **Maintained Features**: Preserved day numbers, entry dots indicator, and today/selected highlighting
- **Performance**: Reduced widget complexity and image loading overhead
- **User Request**: Per user preference, removed additional photo count indicators

**Implementation Details:**
- Files modified: `lib/widgets/calendar_day_cell.dart`
- Lines changed: ~100 lines simplified
- Methods removed: `_buildMultiplePhotos()` and associated layout logic
- New method: `_getRepresentativePhoto()` for intelligent photo selection

### ✅ Single-User Conversion (August 18, 2025)
**Major architecture simplification completed:**
- **Database**: Removed users table, simplified journals schema (v4 → v5)
- **Models**: Removed User model, simplified Journal (no ownerId/sharedWithUserIds)
- **UI**: Removed profile screens, sharing tabs, and all collaboration features
- **WebDAV**: Simplified sync paths from `/journal_app/${username}_data` to `/journal_app`
- **Services**: Removed UserService, UserProvider, and all user management
- **Code Reduction**: ~15-20% codebase reduction by removing multi-user infrastructure
- **Benefits**: Cleaner architecture, easier maintenance, preserved all core features
- **Testing**: All compilation errors resolved, flutter analyze passes

**Lessons Learned:**
- Multi-user features were adding significant complexity without value
- Single-user focus dramatically simplifies state management
- WebDAV sync works perfectly without user attribution
- Database migrations handled schema changes seamlessly

---
*This context file should be read by all sub-agents before starting any research or planning work.*