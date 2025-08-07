import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../providers/user_provider.dart';
import 'user_avatar.dart';

/// A reusable list tile widget for displaying user information
class UserListTile extends ConsumerWidget {
  final String? userId;
  final User? user;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool enabled;
  final bool showEmail;
  final EdgeInsetsGeometry? contentPadding;

  const UserListTile({
    super.key,
    this.userId,
    this.user,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.enabled = true,
    this.showEmail = true,
    this.contentPadding,
  }) : assert(userId != null || user != null, 'Either userId or user must be provided');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If user is provided directly, use it
    if (user != null) {
      return _buildListTile(context, ref, user!);
    }

    // Otherwise, load user by ID
    final userAsync = ref.watch(userByIdProvider(userId!));

    return userAsync.when(
      data: (userData) => userData != null 
        ? _buildListTile(context, ref, userData)
        : _buildPlaceholderTile(context),
      loading: () => _buildLoadingTile(context),
      error: (_, __) => _buildErrorTile(context),
    );
  }

  Widget _buildListTile(BuildContext context, WidgetRef ref, User userData) {
    final isCurrentUser = ref.watch(isCurrentUserProvider(userData.id));
    
    return ListTile(
      contentPadding: contentPadding,
      enabled: enabled,
      selected: selected,
      leading: UserAvatar(
        user: userData,
        radius: 20,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              userData.name,
              style: TextStyle(
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isCurrentUser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'You',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: _buildSubtitle(userData),
      trailing: trailing,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
    );
  }

  Widget? _buildSubtitle(User userData) {
    if (subtitle != null) {
      return Text(subtitle!);
    }

    if (showEmail) {
      return Text(
        userData.email,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14,
        ),
      );
    }

    return null;
  }

  Widget _buildPlaceholderTile(BuildContext context) {
    return ListTile(
      contentPadding: contentPadding,
      leading: const UserAvatar(userId: 'unknown'),
      title: const Text('Unknown User'),
      subtitle: showEmail ? const Text('No email available') : null,
      trailing: trailing,
      enabled: false,
    );
  }

  Widget _buildLoadingTile(BuildContext context) {
    return ListTile(
      contentPadding: contentPadding,
      leading: UserAvatar(
        user: User(
          id: '',
          name: '',
          email: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
      title: Container(
        height: 16,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      subtitle: showEmail ? Container(
        height: 14,
        width: 200,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
      ) : null,
      trailing: trailing,
      enabled: false,
    );
  }

  Widget _buildErrorTile(BuildContext context) {
    return ListTile(
      contentPadding: contentPadding,
      leading: const CircleAvatar(
        backgroundColor: Colors.red,
        child: Icon(Icons.error, color: Colors.white),
      ),
      title: const Text('Error loading user'),
      subtitle: showEmail ? const Text('Unable to load user data') : null,
      trailing: trailing,
      enabled: false,
    );
  }
}

/// A user list tile with a checkbox for selection
class UserListTileSelectable extends UserListTile {
  final bool isSelected;
  final ValueChanged<bool>? onSelected;

  const UserListTileSelectable({
    super.key,
    super.userId,
    super.user,
    super.subtitle,
    super.onTap,
    super.onLongPress,
    super.enabled,
    super.showEmail,
    super.contentPadding,
    required this.isSelected,
    this.onSelected,
  }) : super(
    selected: isSelected,
    trailing: null, // We'll build our own trailing
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build the base list tile first
    final baseWidget = super.build(context, ref);
    
    // If it's a regular ListTile, add our checkbox
    return _addCheckboxToListTile(baseWidget as ListTile);
      
    return baseWidget;
  }

  Widget _addCheckboxToListTile(ListTile originalTile) {
    // Create a new ListTile with checkbox trailing
    return ListTile(
      contentPadding: originalTile.contentPadding,
      enabled: originalTile.enabled ?? true,
      selected: originalTile.selected ?? false,
      leading: originalTile.leading,
      title: originalTile.title,
      subtitle: originalTile.subtitle,
      trailing: Checkbox(
        value: isSelected,
        onChanged: enabled ? (bool? value) => onSelected?.call(value ?? false) : null,
      ),
      onTap: enabled ? () {
        onSelected?.call(!isSelected);
        onTap?.call();
      } : null,
      onLongPress: enabled ? onLongPress : null,
    );
  }
}

/// A compact user list tile for smaller displays
class UserListTileCompact extends UserListTile {
  const UserListTileCompact({
    super.key,
    super.userId,
    super.user,
    super.subtitle,
    super.trailing,
    super.onTap,
    super.onLongPress,
    super.selected,
    super.enabled,
  }) : super(
    showEmail: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user != null) {
      return _buildCompactTile(context, ref, user!);
    }

    final userAsync = ref.watch(userByIdProvider(userId!));
    return userAsync.when(
      data: (userData) => userData != null 
        ? _buildCompactTile(context, ref, userData)
        : super.build(context, ref),
      loading: () => super.build(context, ref),
      error: (_, __) => super.build(context, ref),
    );
  }

  Widget _buildCompactTile(BuildContext context, WidgetRef ref, User userData) {
    return ListTile(
      contentPadding: contentPadding,
      dense: true,
      enabled: enabled,
      selected: selected,
      leading: UserAvatarSmall(user: userData),
      title: Text(
        userData.name,
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null ? Text(
        subtitle!,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ) : null,
      trailing: trailing,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
    );
  }
}

/// A user list tile with action buttons
class UserListTileWithActions extends UserListTile {
  final List<UserAction> actions;

  const UserListTileWithActions({
    super.key,
    super.userId,
    super.user,
    super.subtitle,
    super.onTap,
    super.onLongPress,
    super.selected,
    super.enabled,
    super.showEmail,
    super.contentPadding,
    required this.actions,
  }) : super(trailing: null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseWidget = super.build(context, ref);
    
    if (baseWidget is ListTile) {
      return ListTile(
        contentPadding: baseWidget.contentPadding,
        enabled: baseWidget.enabled ?? true,
        selected: baseWidget.selected ?? false,
        leading: baseWidget.leading,
        title: baseWidget.title,
        subtitle: baseWidget.subtitle,
        trailing: _buildActionButtons(context),
        onTap: baseWidget.onTap,
        onLongPress: baseWidget.onLongPress,
      );
    }
    
    return baseWidget;
  }

  Widget _buildActionButtons(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    
    if (actions.length == 1) {
      final action = actions.first;
      return IconButton(
        icon: Icon(action.icon),
        onPressed: enabled ? action.onPressed : null,
        tooltip: action.tooltip,
      );
    }

    return PopupMenuButton<UserAction>(
      icon: const Icon(Icons.more_vert),
      enabled: enabled,
      onSelected: (action) => action.onPressed?.call(),
      itemBuilder: (context) => actions.map((action) => 
        PopupMenuItem<UserAction>(
          value: action,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 20),
              const SizedBox(width: 12),
              Text(action.label),
            ],
          ),
        ),
      ).toList(),
    );
  }
}

/// Data class for user actions
class UserAction {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const UserAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });
}