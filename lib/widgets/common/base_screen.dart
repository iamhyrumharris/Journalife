import 'package:flutter/material.dart';

abstract class BaseScreen extends StatefulWidget {
  const BaseScreen({super.key});
}

abstract class BaseScreenState<T extends BaseScreen> extends State<T> {
  bool _isLoading = false;
  String? _errorMessage;
  VoidCallback? _onRetry;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  void setError(String? error, {VoidCallback? onRetry}) {
    if (mounted) {
      setState(() {
        _errorMessage = error;
        _onRetry = onRetry;
      });
    }
  }

  void clearError() {
    if (mounted) {
      setState(() {
        _errorMessage = null;
        _onRetry = null;
      });
    }
  }

  // To be implemented by subclasses
  Widget buildContent(BuildContext context);
  
  // Optional methods for customization
  Widget buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget buildErrorWidget(String error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (_onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildEmptyWidget({
    String? title,
    String? message,
    IconData? icon,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.inbox,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title ?? 'No content',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }

  // Pull to refresh support
  Future<void> onRefresh() async {
    // Override in subclasses
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: buildLoadingWidget(),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: buildErrorWidget(_errorMessage!),
      );
    }

    // Wrap content with RefreshIndicator if onRefresh is overridden
    final content = buildContent(context);
    
    // Check if the subclass has overridden onRefresh
    if (onRefresh != BaseScreenState.prototype.onRefresh) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: content,
      );
    }

    return content;
  }
  
  static final BaseScreenState prototype = _BaseScreenStatePrototype();
}

// Helper class for checking if onRefresh is overridden
class _BaseScreenStatePrototype extends BaseScreenState<BaseScreen> {
  @override
  Widget buildContent(BuildContext context) {
    throw UnimplementedError();
  }

  BaseScreen createWidget() => throw UnimplementedError();
}