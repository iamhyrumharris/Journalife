import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/entry/entry_edit_screen.dart';
import 'screens/journals/journal_list_screen.dart';
import 'models/entry.dart';
import 'services/error_service.dart';
import 'providers/user_provider.dart';

Future<void> main() async {
  await SentryFlutter.init((options) {
    options.dsn =
        'https://af6b9dbff6ecda8f350e487be99b3049@o4509794279817217.ingest.us.sentry.io/4509794321825792';
    options.debug = false;
    options.tracesSampleRate = 1.0;
    options.environment = 'development';
    options.beforeSend = (SentryEvent event, Hint hint) {
      return event;
    };
  }, appRunner: () => runApp(const ProviderScope(child: MyApp())));

  FlutterError.onError = (FlutterErrorDetails details) {
    ErrorService.reportError(
      details.exception,
      details.stack,
      hint: 'Flutter Error: ${details.context}',
    );
  };
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize sample users for development
    ref.watch(createSampleUsersProvider);

    return MaterialApp(
      title: 'Journal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      routes: {'/journals': (context) => const JournalListScreen()},
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/entry/create':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (context) => EntryEditScreen(
                initialLatitude: args?['latitude'],
                initialLongitude: args?['longitude'],
                initialLocationName: args?['locationName'],
              ),
            );
          case '/entry/edit':
            final entry = settings.arguments as Entry?;
            return MaterialPageRoute(
              builder: (context) => EntryEditScreen(entry: entry),
            );
          default:
            return null;
        }
      },
    );
  }
}
