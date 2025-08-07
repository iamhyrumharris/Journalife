import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/user_service.dart';

// UserService instance provider
final userServiceProvider = Provider<UserService>((ref) => UserService());

// Current user provider
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, User?>((ref) {
  final userService = ref.watch(userServiceProvider);
  return CurrentUserNotifier(userService);
});

// User lookup provider - gets a user by ID
final userByIdProvider = FutureProvider.family<User?, String>((ref, userId) async {
  final userService = ref.watch(userServiceProvider);
  return await userService.getUserById(userId);
});

// Multiple users lookup provider - gets multiple users by IDs
final usersByIdsProvider = FutureProvider.family<Map<String, User>, List<String>>((ref, userIds) async {
  final userService = ref.watch(userServiceProvider);
  return await userService.getUsersByIds(userIds);
});

// User search provider
final userSearchProvider = StateNotifierProvider<UserSearchNotifier, AsyncValue<List<User>>>((ref) {
  final userService = ref.watch(userServiceProvider);
  return UserSearchNotifier(userService);
});

// Recent users provider
final recentUsersProvider = FutureProvider<List<User>>((ref) async {
  final userService = ref.watch(userServiceProvider);
  return await userService.getRecentUsers();
});

// All users provider (use with caution for large user bases)
final allUsersProvider = FutureProvider.family<List<User>, int?>((ref, limit) async {
  final userService = ref.watch(userServiceProvider);
  return await userService.getAllUsers(limit: limit);
});

/// StateNotifier for managing the current user
class CurrentUserNotifier extends StateNotifier<User?> {
  CurrentUserNotifier(this._userService) : super(null) {
    _loadCurrentUser();
  }

  final UserService _userService;

  void _loadCurrentUser() {
    state = _userService.currentUser;
  }

  /// Sets the current user
  void setCurrentUser(User user) {
    _userService.setCurrentUser(user);
    state = user;
  }

  /// Clears the current user
  void clearCurrentUser() {
    _userService.setCurrentUser(User(
      id: '',
      name: '',
      email: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    state = null;
  }

  /// Updates the current user
  Future<void> updateCurrentUser(User updatedUser) async {
    final result = await _userService.updateUser(updatedUser);
    if (result != null) {
      _userService.setCurrentUser(result);
      state = result;
    }
  }
}

/// StateNotifier for managing user search
class UserSearchNotifier extends StateNotifier<AsyncValue<List<User>>> {
  UserSearchNotifier(this._userService) : super(const AsyncValue.data([]));

  final UserService _userService;
  String _lastQuery = '';

  /// Searches for users with the given query
  Future<void> searchUsers(String query) async {
    // Don't search for empty or very short queries
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      _lastQuery = '';
      return;
    }

    // Don't repeat the same search
    if (query == _lastQuery) {
      return;
    }

    _lastQuery = query;
    state = const AsyncValue.loading();

    try {
      final users = await _userService.searchUsers(query);
      if (mounted) {
        state = AsyncValue.data(users);
      }
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  /// Clears the search results
  void clearSearch() {
    state = const AsyncValue.data([]);
    _lastQuery = '';
  }

  /// Gets the current search query
  String get currentQuery => _lastQuery;
}

/// Provider for user cache statistics (useful for debugging)
final userCacheStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final userService = ref.watch(userServiceProvider);
  return userService.getCacheStats();
});

/// Utility provider for checking if a user exists by email
final userExistsByEmailProvider = FutureProvider.family<bool, String>((ref, email) async {
  final userService = ref.watch(userServiceProvider);
  return await userService.userExistsByEmail(email);
});

/// Provider for creating sample users (development only)
final createSampleUsersProvider = FutureProvider<void>((ref) async {
  final userService = ref.watch(userServiceProvider);
  await userService.createSampleUsers();
});

/// Computed provider that gives display name for a user ID
final userDisplayNameProvider = Provider.family<String, String>((ref, userId) {
  final userAsync = ref.watch(userByIdProvider(userId));
  
  return userAsync.when(
    data: (user) => user?.name ?? 'Unknown User',
    loading: () => 'Loading...',
    error: (_, __) => 'Unknown User',
  );
});

/// Computed provider that checks if a user ID is the current user
final isCurrentUserProvider = Provider.family<bool, String>((ref, userId) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser?.id == userId;
});

/// Provider for getting user initials for avatars
final userInitialsProvider = Provider.family<String, String>((ref, userId) {
  final userAsync = ref.watch(userByIdProvider(userId));
  
  return userAsync.when(
    data: (user) => _getUserInitials(user?.name ?? 'Unknown User'),
    loading: () => '...',
    error: (_, __) => 'UU',
  );
});

/// Helper function to get user initials
String _getUserInitials(String name) {
  if (name.isEmpty) return 'UU';
  
  final parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  } else if (parts.isNotEmpty) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  
  return 'U';
}