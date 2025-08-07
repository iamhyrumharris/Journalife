# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Flutter journal application with multi-user support, WebDAV sync, and journal sharing capabilities. The app features five main views (Calendar, Timeline, Map, Attachments, Search) and comprehensive entry management with rich media support.

## Key Commands

### Development
- `flutter analyze` - Always run before committing; this is the primary code quality check
- `flutter pub get` - Install dependencies after pubspec.yaml changes
- `flutter run` - Launch the app for development
- `flutter test` - Run widget tests (currently needs test updates for new architecture)
- `flutter clean` - Clean build artifacts when having build issues
- Always use flutter analyze only when the flutter code changes

### Platform-specific Builds
- `flutter run -d chrome` - Run on web
- `flutter run -d macos` - Run on macOS
- `flutter run -d ios` - Run on iOS simulator

## Architecture Overview

### State Management
Uses **Riverpod** for state management with a provider-based architecture:
- `lib/providers/database_provider.dart` - Database service provider
- `lib/providers/journal_provider.dart` - Journal CRUD operations and state
- `lib/providers/entry_provider.dart` - Entry CRUD operations per journal

### Data Layer
- **SQLite** database with `sqflite` package
- `lib/services/database_service.dart` - Central database operations
- `lib/models/` - Data models (User, Journal, Entry, Attachment)
- Full relational structure with foreign keys and indexes

### Screen Architecture
Bottom navigation with 5 main views:
- **Calendar**: Monthly view with entry indicators, day selection
- **Timeline**: Chronological feed with rich previews
- **Map**: Google Maps with geotagged entries
- **Attachments**: Tabbed interface for media organization
- **Search**: Real-time search with suggestions

### Key Architectural Patterns
1. **Family Providers**: `entryProvider.family` creates journal-specific entry providers
2. **Current Selection**: `currentJournalProvider` tracks active journal across screens
3. **Error Handling**: Sentry integration in `lib/services/error_service.dart`
4. **Async State**: All providers handle loading/error/data states consistently

## Important Implementation Notes

### Journal Context Management
- All screens depend on `currentJournalProvider` for active journal
- First journal auto-selected if none chosen
- Journal switching clears dependent state (search, etc.)

### Database Transactions
- Entry creation includes attachment handling in single transaction
- Attachment deletion cascades through foreign key constraints
- Date range queries optimized with indexes

### Media Attachments
- Placeholder implementations in entry editing (marked with TODOs)
- Support for photos, audio, files, and location data
- Attachment-to-entry relationships via database foreign keys

### Error Reporting
- Sentry configured in `main.dart` for crash reporting
- `ErrorService.addBreadcrumb()` for user action tracking
- Development vs production error handling

## Testing Notes

- Default widget test expects counter app - needs updating for journal app
- Run `flutter test` will fail until test is updated to match current UI
- Database service has comprehensive CRUD operations but lacks unit tests

## Known Issues

- Several deprecation warnings for `withOpacity()` - should migrate to `withValues()`
- `use_build_context_synchronously` warning in search screen async operations
- Plugin configuration warnings for file_picker (non-blocking)
- Sentry `extras` deprecation in `error_service.dart`

## Future Development Areas

1. **Media Implementation**: Complete TODOs in `entry_edit_screen.dart`
2. **Location Services**: Implement actual GPS integration
3. **WebDAV Sync**: Service structure exists but not implemented
4. **Multi-user**: User models ready but authentication needed
5. **Journal Sharing**: Logic in providers but UI flow incomplete