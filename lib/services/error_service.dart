import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ErrorService {
  static void reportError(dynamic error, StackTrace? stackTrace, {String? hint}) {
    if (kDebugMode) {
      debugPrint('Error: $error');
      debugPrint('StackTrace: $stackTrace');
    }
    
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: hint != null ? Hint.withMap({'message': hint}) : null,
    );
  }
  
  static void reportMessage(String message, {SentryLevel level = SentryLevel.info}) {
    Sentry.captureMessage(message, level: level);
  }
  
  static void addBreadcrumb(String message, {String? category}) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        category: category ?? 'app',
        level: SentryLevel.info,
        timestamp: DateTime.now(),
      ),
    );
  }
  
  static void setUserContext({
    String? id,
    String? email,
    String? username,
    Map<String, dynamic>? extras,
  }) {
    Sentry.configureScope((scope) {
      scope.setUser(SentryUser(
        id: id,
        email: email,
        username: username,
        data: extras,
      ));
    });
  }
  
  static void setTag(String key, String value) {
    Sentry.configureScope((scope) {
      scope.setTag(key, value);
    });
  }
  
  static void setContext(String key, Map<String, dynamic> context) {
    Sentry.configureScope((scope) {
      scope.setContexts(key, context);
    });
  }
}