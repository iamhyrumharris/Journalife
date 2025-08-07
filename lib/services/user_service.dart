import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../services/database_service.dart';

/// Service for managing user data, lookup, and search functionality
/// Provides user resolution for sharing features and profile display
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  static final DatabaseService _databaseService = DatabaseService();
  static final Map<String, User> _userCache = {};
  static User? _currentUser;

  /// Gets the current logged-in user
  /// In a real app, this would be managed by authentication
  User? get currentUser => _currentUser;

  /// Sets the current user (for demo/testing purposes)
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  /// Gets a user by ID with caching
  Future<User?> getUserById(String userId) async {
    try {
      // Check cache first
      if (_userCache.containsKey(userId)) {
        return _userCache[userId];
      }

      // Query database
      final database = await _databaseService.database;
      final result = await database.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (result.isNotEmpty) {
        final user = User.fromMap(result.first);
        _userCache[userId] = user; // Cache the result
        return user;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  /// Gets multiple users by their IDs
  Future<Map<String, User>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return {};

    final users = <String, User>{};
    final uncachedIds = <String>[];

    // Check cache first
    for (final id in userIds) {
      if (_userCache.containsKey(id)) {
        users[id] = _userCache[id]!;
      } else {
        uncachedIds.add(id);
      }
    }

    // Query database for uncached users
    if (uncachedIds.isNotEmpty) {
      try {
        final database = await _databaseService.database;
        final placeholders = uncachedIds.map((_) => '?').join(',');

        final result = await database.rawQuery(
          'SELECT * FROM users WHERE id IN ($placeholders)',
          uncachedIds,
        );

        for (final userMap in result) {
          final user = User.fromMap(userMap);
          users[user.id] = user;
          _userCache[user.id] = user; // Cache the result
        }
      } catch (e) {
        debugPrint('Error getting users by IDs: $e');
      }
    }

    return users;
  }

  /// Searches for users by name or email
  Future<List<User>> searchUsers(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    try {
      final database = await _databaseService.database;
      final searchQuery = '%${query.trim().toLowerCase()}%';

      final result = await database.rawQuery(
        '''
        SELECT * FROM users 
        WHERE LOWER(name) LIKE ? OR LOWER(email) LIKE ?
        ORDER BY name ASC
        LIMIT ?
      ''',
        [searchQuery, searchQuery, limit],
      );

      final users = result.map((userMap) => User.fromMap(userMap)).toList();

      // Cache the results
      for (final user in users) {
        _userCache[user.id] = user;
      }

      return users;
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// Creates a new user in the database
  Future<User?> createUser({
    required String name,
    required String email,
    String? id,
  }) async {
    try {
      final now = DateTime.now();
      final user = User(
        id: id ?? _generateUserId(),
        name: name.trim(),
        email: email.trim().toLowerCase(),
        createdAt: now,
        updatedAt: now,
      );

      await _databaseService.insertUser(user);

      _userCache[user.id] = user; // Cache the new user
      return user;
    } catch (e) {
      debugPrint('Error creating user: $e');
      return null;
    }
  }

  /// Updates an existing user
  Future<User?> updateUser(User updatedUser) async {
    try {
      final user = updatedUser.copyWith(updatedAt: DateTime.now());

      await _databaseService.updateUser(user);
      final rowsAffected = 1; // Assume success if no exception

      if (rowsAffected > 0) {
        _userCache[user.id] = user; // Update cache
        return user;
      }

      return null;
    } catch (e) {
      debugPrint('Error updating user: $e');
      return null;
    }
  }

  /// Deletes a user from the database
  Future<bool> deleteUser(String userId) async {
    try {
      final database = await _databaseService.database;
      final rowsAffected = await database.delete(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (rowsAffected > 0) {
        _userCache.remove(userId); // Remove from cache
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return false;
    }
  }

  /// Checks if a user exists by email
  Future<bool> userExistsByEmail(String email) async {
    try {
      final database = await _databaseService.database;
      final result = await database.query(
        'users',
        where: 'LOWER(email) = ?',
        whereArgs: [email.trim().toLowerCase()],
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if user exists: $e');
      return false;
    }
  }

  /// Gets all users (for admin purposes or small user bases)
  Future<List<User>> getAllUsers({int? limit}) async {
    try {
      final database = await _databaseService.database;
      final result = await database.query(
        'users',
        orderBy: 'name ASC',
        limit: limit,
      );

      final users = result.map((userMap) => User.fromMap(userMap)).toList();

      // Cache the results
      for (final user in users) {
        _userCache[user.id] = user;
      }

      return users;
    } catch (e) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }

  /// Gets recently active or created users
  Future<List<User>> getRecentUsers({int limit = 10}) async {
    try {
      final database = await _databaseService.database;
      final result = await database.query(
        'users',
        orderBy: 'updated_at DESC',
        limit: limit,
      );

      final users = result.map((userMap) => User.fromMap(userMap)).toList();

      // Cache the results
      for (final user in users) {
        _userCache[user.id] = user;
      }

      return users;
    } catch (e) {
      debugPrint('Error getting recent users: $e');
      return [];
    }
  }

  /// Clears the user cache (useful for memory management)
  void clearCache() {
    _userCache.clear();
  }

  /// Gets cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_users': _userCache.length,
      'current_user': _currentUser?.toString(),
      'cache_keys': _userCache.keys.toList(),
    };
  }

  /// Generates a unique user ID
  String _generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}';
  }

  /// Generates a random string for ID uniqueness
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) {
      return chars[(random + index) % chars.length];
    }).join();
  }

  /// Creates sample users for development/testing
  Future<void> createSampleUsers() async {
    final sampleUsers = [
      {'name': 'Alice Johnson', 'email': 'alice@example.com'},
      {'name': 'Bob Smith', 'email': 'bob@example.com'},
      {'name': 'Carol Williams', 'email': 'carol@example.com'},
      {'name': 'David Brown', 'email': 'david@example.com'},
      {'name': 'Emma Davis', 'email': 'emma@example.com'},
    ];

    for (final userData in sampleUsers) {
      final exists = await userExistsByEmail(userData['email']!);
      if (!exists) {
        await createUser(name: userData['name']!, email: userData['email']!);
      }
    }

    // Set the first user as current user if none exists
    if (_currentUser == null) {
      final users = await getAllUsers(limit: 1);
      if (users.isNotEmpty) {
        setCurrentUser(users.first);
      }
    }

    debugPrint('Sample users created/verified');
  }
}
