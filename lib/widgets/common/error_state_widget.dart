import 'package:flutter/material.dart';

class ErrorStateWidget extends StatelessWidget {
  final String? title;
  final String error;
  final VoidCallback? onRetry;
  final IconData icon;
  final double iconSize;
  final bool showDetails;

  const ErrorStateWidget({
    super.key,
    this.title,
    required this.error,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.iconSize = 72,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _AnimatedErrorIcon(
              icon: icon,
              size: iconSize,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              title ?? 'Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (showDetails) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnimatedErrorIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;

  const _AnimatedErrorIcon({
    required this.icon,
    required this.size,
    required this.color,
  });

  @override
  State<_AnimatedErrorIcon> createState() => _AnimatedErrorIconState();
}

class _AnimatedErrorIconState extends State<_AnimatedErrorIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: -0.015,
      end: 0.015,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticIn,
      ),
    );

    _startShakeAnimation();
  }

  void _startShakeAnimation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _controller.repeat(reverse: true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _shakeAnimation.value,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.color,
          ),
        );
      },
    );
  }
}

// Preset error states for common scenarios
class NetworkErrorState extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorState({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorStateWidget(
      icon: Icons.wifi_off,
      title: 'No internet connection',
      error: 'Please check your network settings and try again',
      onRetry: onRetry,
      showDetails: false,
    );
  }
}

class LoadingErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const LoadingErrorState({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorStateWidget(
      title: 'Failed to load data',
      error: message ?? 'An unexpected error occurred while loading',
      onRetry: onRetry,
    );
  }
}

class SyncErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const SyncErrorState({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorStateWidget(
      icon: Icons.sync_problem,
      title: 'Sync failed',
      error: message ?? 'Unable to sync your data. Changes are saved locally.',
      onRetry: onRetry,
    );
  }
}

class PermissionErrorState extends StatelessWidget {
  final String permission;
  final VoidCallback? onOpenSettings;

  const PermissionErrorState({
    super.key,
    required this.permission,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 72,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Permission required',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'This app needs $permission permission to continue',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onOpenSettings != null) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}