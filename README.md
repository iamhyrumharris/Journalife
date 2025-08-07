# Journal App

A cross-platform journal application built with Flutter that supports multi-user collaboration, WebDAV synchronization, and shared journals.

## Features

- 📝 **Multiple Journals**: Create and manage multiple journals for different purposes
- 👥 **Multi-User Support**: Collaborate with others on shared journals
- 🔄 **WebDAV Sync**: Synchronize your journals across devices using WebDAV
- 📊 **Timeline View**: Visualize your entries over time
- 📅 **Calendar Integration**: View entries by date with calendar interface
- 🗺️ **Map Integration**: Attach location data to your entries
- 📎 **Rich Attachments**: Add images, audio recordings, and files to entries
- 🔍 **Search Functionality**: Find entries quickly with built-in search
- 📱 **Cross-Platform**: Runs on iOS, Android, macOS, Windows, Linux, and Web

## Screenshots

See the `src_docs/` folder for app screenshots and design mockups.

## Technology Stack

- **Framework**: Flutter 3.8.1+
- **State Management**: Riverpod
- **Database**: SQLite (via sqflite)
- **Synchronization**: WebDAV
- **Maps**: Google Maps
- **Error Reporting**: Sentry

## Getting Started

### Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart SDK
- For mobile development: Android Studio/Xcode
- For desktop development: Platform-specific toolchains

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/journal-app.git
cd journal-app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Configuration

For WebDAV synchronization, configure your WebDAV server settings in the app's sync settings.

## Project Structure

- `lib/models/` - Data models (Entry, Journal, User, etc.)
- `lib/providers/` - Riverpod providers for state management
- `lib/screens/` - UI screens and pages
- `lib/services/` - Business logic and external service integrations
- `lib/widgets/` - Reusable UI components
- `test/` - Unit and integration tests

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions or support, please open an issue on GitHub.
