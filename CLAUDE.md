# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Sub-Agent Integration

When working on features, ALWAYS follow this workflow:
1. **Read Context First**: Start by reading `.claude/context/journalife_context.md`
2. **Consult Expert Agents**: Use relevant sub-agents from `.claude/agents/` for research
3. **Create Research Plans**: Save detailed plans to `.claude/research/` before implementing
4. **Update Context**: After completion, update context files with what was learned

### Available Sub-Agents
- **Flutter UI Expert**: `.claude/agents/flutter_ui_expert.md` - UI/UX patterns and widget composition
- **Riverpod State Expert**: `.claude/agents/riverpod_state_expert.md` - State management architecture
- **WebDAV Sync Expert**: `.claude/agents/webdav_sync_expert.md` - Synchronization and conflict resolution
- **Database Expert**: `.claude/agents/database_expert.md` - SQLite schema and query optimization

### Sub-Agent Rules
- Sub-agents should ONLY research and create implementation plans
- Sub-agents should NEVER implement code directly
- All research must be saved to markdown files before implementation
- Main agent implements code after reading all research plans

### **🎯 COMPLETION WORKFLOW - MANDATORY FOR ALL MAJOR FEATURES**
When completing any significant feature implementation, ALWAYS follow this comprehensive workflow:

#### 1. Context Documentation Updates
- **Update `.claude/context/journalife_context.md`:**
  - Move completed features from "Next Features" to "Recent Completed Work"
  - Add detailed implementation notes and lessons learned
  - Update "Current Development Focus" if needed
  - Note any architectural decisions made during implementation
  - Include metrics: lines changed, files modified, performance impact
  - Add completion date and benefits achieved

#### 2. Research File Organization
- **Move research files to `.claude/research/completed/`**
- **Create completion summary file:**
  - Document what was implemented vs. what was researched
  - Include key metrics and impact measurements
  - Capture lessons learned for future similar projects
  - Note any deviations from original research plans

#### 3. Feature Preferences Updates
- **Update CLAUDE.md feature preferences section** with completion status
- **Mark completed features with ✅ COMPLETED (date)**
- **Update any affected architectural documentation**

#### 4. Validation & Quality Assurance
- **Run `flutter analyze` and ensure zero errors**
- **Test build process on target platforms**
- **Validate that all affected functionality still works**
- **Update any broken tests or test helpers**

#### 5. Next Priorities Assessment
- **Identify what new priorities emerge from completion**
- **Update "Next Features" based on architectural changes**
- **Note any technical debt or follow-up work needed**

**This workflow ensures continuity across Claude Code sessions and comprehensive documentation of all architectural changes.**

## Project Overview

A Flutter journal application with single-user focus, WebDAV sync, and comprehensive entry management. The app features five main views (Calendar, Timeline, Map, Attachments, Reflect) and rich media support with cross-platform synchronization.

## User Preferences

### Feature Preferences
- **No Mood Tracking**: The user has explicitly requested removal of mood/rating functionality from the journal app. Do not implement or suggest mood tracking, rating systems, or emotional analysis features unless explicitly requested.
- **Single-User Focus**: ✅ COMPLETED (Aug 18, 2025) - Successfully converted from multi-user to single-user architecture. All sharing, collaboration, and user management features have been removed.

## Key Commands

### Development
- `flutter analyze` - Always run before committing; this is the primary code quality check
- `flutter pub get` - Install dependencies after pubspec.yaml changes
- `flutter run` - Launch the app for development
- `flutter test` - Run widget tests (currently needs test updates for new architecture)
- `flutter clean` - Clean build artifacts when having build issues
- Always use flutter analyze only when the flutter code changes

### Testing & Validation
- `flutter test` - Run unit and widget tests
- `dart run_integration_test.dart` - Run integration tests
- `dart test_webdav_connection.dart` - Test WebDAV connectivity standalone
- `dart test_webdav_terminal.dart` - Interactive WebDAV testing
- `dart webdav_verification_script.dart` - Comprehensive WebDAV validation

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
- **SQLite** database with `sqflite` package and `sqflite_common_ffi` for cross-platform support
- `lib/services/database_service.dart` - Central database operations
- `lib/models/` - Data models (Journal, Entry, Attachment, SyncConfig, SyncManifest, SyncStatus) - **User model removed Aug 18, 2025**
- Single-user optimized relational structure with foreign keys and indexes (simplified schema v5)
- Comprehensive file storage abstraction in `lib/services/*_file_storage_service.dart`

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

### WebDAV Sync Implementation
- **Active Development**: WebDAV sync is now implemented and functional
- `lib/services/webdav_sync_service.dart` - Single-user bidirectional sync with conflict resolution
- `lib/providers/sync_config_provider.dart` - Configuration management
- `lib/models/sync_*.dart` - Data models for sync manifest, status, and configuration
- Supports password storage, journal selection, and manifest-based incremental sync
- Uses date-based file organization (entries/YYYY/MM/ and attachments/YYYY/MM/)
- Implements last-writer-wins conflict resolution strategy for device-based conflicts

### Testing & Integration Test Infrastructure  
- `integration_test/webdav_sync_integration_test.dart` - WebDAV sync integration tests
- `test/integration/migration_integration_test.dart` - Database migration tests
- `test_webdav_connection.dart`, `test_webdav_terminal.dart` - Standalone WebDAV validation scripts
- `run_integration_test.dart` - Test runner for integration tests

## Sync Configuration Requirements
- **Journal Selection Required**: By design, no journals sync by default - users must explicitly select journals in sync settings
- **Debug Info Available**: Check `check_sync_config.md` for troubleshooting WebDAV sync issues
- **Password Security**: Sync passwords stored separately from config using database service methods
- **Single-User Sync**: Optimized for syncing single user's data across multiple devices

## Future Development Areas

1. **Media Implementation**: Complete TODOs in `entry_edit_screen.dart`
2. **Location Services**: Implement actual GPS integration  
3. **Enhanced Search**: Full-text search with filters and suggestions
4. **Rich Text Editing**: Advanced text formatting capabilities
5. **Conflict Resolution UI**: Currently uses last-writer-wins, needs user-facing conflict resolution for device conflicts
6. **Automatic Sync Scheduling**: Background sync based on configured frequency
7. **Export/Import**: Journal backup and restoration features

## Code Quality Guidelines

- Always consult sub-agents for complex features before implementation
- Maintain consistent Riverpod patterns across providers
- Follow existing error handling patterns with Sentry integration
- Ensure cross-platform compatibility for all new features
- Update `.claude/context/journalife_context.md` after completing features

## Utilize MCPs When Necessary

 - **IOS Simulator MCP**: Allows the ability to control IOS simualtor to do aditional testing to make sure everything is working correctly