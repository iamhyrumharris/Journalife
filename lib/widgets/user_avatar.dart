import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../providers/user_provider.dart';

/// A reusable user avatar widget that displays user profile picture or initials
class UserAvatar extends ConsumerWidget {
  final String? userId;
  final User? user;
  final double radius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const UserAvatar({
    super.key,
    this.userId,
    this.user,
    this.radius = 20,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  }) : assert(userId != null || user != null, 'Either userId or user must be provided');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If user is provided directly, use it
    if (user != null) {
      return _buildAvatar(context, user!);
    }

    // Otherwise, load user by ID
    final userAsync = ref.watch(userByIdProvider(userId!));

    return userAsync.when(
      data: (userData) => userData != null 
        ? _buildAvatar(context, userData)
        : _buildPlaceholderAvatar(context),
      loading: () => _buildLoadingAvatar(context),
      error: (_, __) => _buildErrorAvatar(context),
    );
  }

  Widget _buildAvatar(BuildContext context, User user) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? _getAvatarColor(user.name),
      foregroundColor: foregroundColor ?? Colors.white,
      child: Text(
        _getUserInitials(user.name),
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildPlaceholderAvatar(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      foregroundColor: Colors.grey[600],
      child: Icon(
        Icons.person,
        size: radius,
      ),
    );
  }

  Widget _buildLoadingAvatar(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[200],
      child: SizedBox(
        width: radius,
        height: radius,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildErrorAvatar(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.red[100],
      foregroundColor: Colors.red[700],
      child: Icon(
        Icons.error,
        size: radius,
      ),
    );
  }

  /// Generates a color based on the user's name for consistent avatar colors
  Color _getAvatarColor(String name) {
    if (backgroundColor != null) return backgroundColor!;

    // Generate a consistent color based on the name
    final hash = name.hashCode;
    final colors = [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.purple[400]!,
      Colors.orange[400]!,
      Colors.teal[400]!,
      Colors.pink[400]!,
      Colors.indigo[400]!,
      Colors.cyan[400]!,
      Colors.amber[400]!,
      Colors.red[400]!,
    ];

    return colors[hash.abs() % colors.length];
  }

  /// Gets user initials from name
  String _getUserInitials(String name) {
    if (name.isEmpty) return 'U';
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    
    return 'U';
  }
}

/// A larger user avatar for profile screens
class UserAvatarLarge extends UserAvatar {
  const UserAvatarLarge({
    super.key,
    super.userId,
    super.user,
    super.onTap,
    super.backgroundColor,
    super.foregroundColor,
  }) : super(radius: 40);
}

/// A small user avatar for compact displays
class UserAvatarSmall extends UserAvatar {
  const UserAvatarSmall({
    super.key,
    super.userId,
    super.user,
    super.onTap,
    super.backgroundColor,
    super.foregroundColor,
  }) : super(radius: 16);
}

/// A user avatar with status indicator
class UserAvatarWithStatus extends ConsumerWidget {
  final String? userId;
  final User? user;
  final double radius;
  final VoidCallback? onTap;
  final bool isOnline;
  final Color statusColor;

  const UserAvatarWithStatus({
    super.key,
    this.userId,
    this.user,
    this.radius = 20,
    this.onTap,
    this.isOnline = false,
    this.statusColor = Colors.green,
  }) : assert(userId != null || user != null, 'Either userId or user must be provided');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        UserAvatar(
          userId: userId,
          user: user,
          radius: radius,
          onTap: onTap,
        ),
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: radius * 0.6,
              height: radius * 0.6,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Multiple user avatars in a stack (for showing shared users)
class UserAvatarStack extends ConsumerWidget {
  final List<String> userIds;
  final double radius;
  final int maxVisible;
  final VoidCallback? onTap;

  const UserAvatarStack({
    super.key,
    required this.userIds,
    this.radius = 20,
    this.maxVisible = 3,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleUserIds = userIds.take(maxVisible).toList();
    final remainingCount = userIds.length - visibleUserIds.length;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...visibleUserIds.asMap().entries.map((entry) {
            final index = entry.key;
            final userId = entry.value;
            
            return Container(
              margin: EdgeInsets.only(left: index == 0 ? 0 : radius * 0.3),
              child: UserAvatar(
                userId: userId,
                radius: radius,
              ),
            );
          }),
          if (remainingCount > 0)
            Container(
              margin: EdgeInsets.only(left: radius * 0.3),
              child: CircleAvatar(
                radius: radius,
                backgroundColor: Colors.grey[300],
                child: Text(
                  '+$remainingCount',
                  style: TextStyle(
                    fontSize: radius * 0.6,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}