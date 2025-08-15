import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  final double iconSize;
  final Color? iconColor;
  final bool animate;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox,
    this.action,
    this.iconSize = 72,
    this.iconColor,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? 
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4);

    Widget iconWidget = Icon(
      icon,
      size: iconSize,
      color: effectiveIconColor,
    );

    if (animate) {
      iconWidget = _AnimatedEmptyIcon(
        icon: icon,
        size: iconSize,
        color: effectiveIconColor,
      );
    }

    return Semantics(
      label: 'Empty state: $title${message != null ? '. $message' : ''}',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(child: iconWidget),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                semanticsLabel: title,
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                  semanticsLabel: message,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 32),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedEmptyIcon extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color color;

  const _AnimatedEmptyIcon({
    required this.icon,
    required this.size,
    required this.color,
  });

  @override
  State<_AnimatedEmptyIcon> createState() => _AnimatedEmptyIconState();
}

class _AnimatedEmptyIconState extends State<_AnimatedEmptyIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _rotationAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.repeat(reverse: true);
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Icon(
              widget.icon,
              size: widget.size,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

// Preset empty states for common scenarios
class NoEntriesEmptyState extends StatelessWidget {
  final VoidCallback? onCreateEntry;

  const NoEntriesEmptyState({
    super.key,
    this.onCreateEntry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.book_outlined,
      title: 'No entries yet',
      message: 'Start journaling to capture your thoughts and memories',
      action: onCreateEntry != null
          ? FilledButton.icon(
              onPressed: onCreateEntry,
              icon: const Icon(Icons.add),
              label: const Text('Create Entry'),
            )
          : null,
    );
  }
}

class NoJournalsEmptyState extends StatelessWidget {
  final VoidCallback? onCreateJournal;

  const NoJournalsEmptyState({
    super.key,
    this.onCreateJournal,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.menu_book_outlined,
      title: 'No journals yet',
      message: 'Create your first journal to start writing',
      action: onCreateJournal != null
          ? FilledButton.icon(
              onPressed: onCreateJournal,
              icon: const Icon(Icons.add),
              label: const Text('Create Journal'),
            )
          : null,
    );
  }
}

class NoSearchResultsEmptyState extends StatelessWidget {
  final String? searchQuery;

  const NoSearchResultsEmptyState({
    super.key,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.search_off,
      title: 'No results found',
      message: searchQuery != null
          ? 'Try searching with different keywords'
          : 'Your search returned no results',
      animate: false,
    );
  }
}

class NoAttachmentsEmptyState extends StatelessWidget {
  const NoAttachmentsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      icon: Icons.attachment_outlined,
      title: 'No attachments yet',
      message: 'Photos, files, and recordings from your entries will appear here',
    );
  }
}

class NoLocationEntriesEmptyState extends StatelessWidget {
  const NoLocationEntriesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      icon: Icons.location_off,
      title: 'No location entries',
      message: 'Entries with location information will appear on the map',
    );
  }
}