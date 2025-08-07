# Sentry Setup Instructions

Sentry has been integrated into your Flutter journal app for bug reporting and error tracking.

## Setup Steps

1. **Create a Sentry Account**: Go to [sentry.io](https://sentry.io) and create an account
2. **Create a New Project**: Choose "Flutter" as the platform
3. **Get Your DSN**: Copy the DSN from your Sentry project settings
4. **Update Configuration**: Replace `YOUR_SENTRY_DSN_HERE` in `lib/main.dart:10` with your actual DSN

## Features Included

- **Automatic Error Capture**: Flutter errors are automatically sent to Sentry
- **Manual Error Reporting**: Use `ErrorService` methods throughout your app
- **Breadcrumbs**: Track user actions leading up to errors
- **User Context**: Set user information for better debugging
- **Performance Monitoring**: Track app performance with traces

## Usage Examples

```dart
import '../services/error_service.dart';

// Report an error manually
try {
  // risky code
} catch (error, stackTrace) {
  ErrorService.reportError(error, stackTrace, hint: 'Failed to save entry');
}

// Add breadcrumbs for user actions
ErrorService.addBreadcrumb('User opened settings');

// Set user context
ErrorService.setUserContext(
  id: 'user123',
  email: 'user@example.com',
);

// Add custom tags
ErrorService.setTag('feature', 'journal-entry');

// Report custom messages
ErrorService.reportMessage('User completed onboarding');
```

## Environment Setup

The current configuration is set to 'development'. For production:

1. Change `options.environment = 'production'` in `main.dart`
2. Set `options.debug = false` for production
3. Consider reducing `options.tracesSampleRate` for production (e.g., 0.1)

## Testing

To test if Sentry is working:

1. Throw a deliberate error in your app
2. Check your Sentry dashboard for the captured error
3. Verify breadcrumbs and context are being sent

The integration is ready to use once you add your Sentry DSN!