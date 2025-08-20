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
- **No Weather Feature (for now)**: User has decided to postpone weather integration (Aug 20, 2025)
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
- **Scrolling in calendar view**: When scrolling in calendar view it seems like it hiccups for a super brief second after it passes a month.
- **Calendar needs to be variable**: Calendar needs to be variable between 4-6 weeks since each month is different.j

## Next Features to Implement
*[List upcoming features in priority order]*

## Backlog Features (Not Currently Prioritized)
- **Weather Integration**: Postponed (Aug 20, 2025)
  - Research completed: Open-Meteo API (no key required) or WeatherKit (iOS only, requires dev account)
  - Would add weather fields to Entry model (weatherCondition, temperature, weatherDescription)
  - Could auto-fetch based on location or allow manual entry

## Recent Completed Work

### ✅ Location Text Overflow Fix (August 20, 2025)
**Fixed location text overflow on small screens:**
- **Issue**: Location names causing RenderFlex overflow (121 pixels) on entry edit screen and other location displays
- **Root Cause**: Location text in Row widgets not properly constrained for long location names
- **Solution**: Added proper text overflow handling with ellipsis across all location displays

**Code Changes:**
- **LocationCard** (`lib/widgets/common/location_card.dart:59-60`): Added `maxLines: 1` and `overflow: TextOverflow.ellipsis`
- **MetadataCard** (`lib/widgets/common/metadata_card.dart:127-128`): Added `maxLines: 1` and `overflow: TextOverflow.ellipsis` 
- **Entry Edit Screen** (`lib/screens/entry/entry_edit_screen.dart:240-272`): Wrapped journal name in `Flexible` and location in `Expanded` with ellipsis overflow

**Technical Details:**
- **Files modified**: 3 files (location_card.dart, metadata_card.dart, entry_edit_screen.dart)
- **Lines changed**: ~15 lines total
- **Strategy**: Simple ellipsis truncation with proper widget constraints
- **Priority**: Location text gets expansion priority over journal name
- **Result**: No more RenderFlex overflow errors, clean text display on all screen sizes
- **Validation**: Flutter analyze passes, no new warnings introduced

### ✅ Calendar Day Selection Fix (August 20, 2025)
**Fixed calendar day selection to navigate to correct date:**
- **Issue**: Clicking any day on calendar always opened current day's edit page instead of selected day
- **Root Cause**: EntryEditScreen was displaying `DateTime.now()` instead of selected date
- **Solution**: Modified date display logic to use `widget.entry?.createdAt ?? widget.initialDate ?? DateTime.now()`
- **Code Changes**: Updated `entry_edit_screen.dart:142` to properly handle date precedence
- **Result**: Calendar day selection now correctly navigates to and displays the selected date
- **Impact**: Improved user experience and fixed core calendar functionality

**Technical Details:**
- Files modified: `lib/screens/entry/entry_edit_screen.dart`
- Lines changed: 4 lines (date calculation logic)
- Date precedence: existing entry date → calendar selected date → current date (fallback)
- Validated: Flutter analyze passes, iOS build successful

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