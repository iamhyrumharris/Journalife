import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../providers/user_provider.dart';
import 'user_list_tile.dart';

/// Dialog for searching and selecting users
class UserSearchDialog extends ConsumerStatefulWidget {
  final String title;
  final String? hintText;
  final List<String> excludeUserIds;
  final bool multiSelect;
  final List<String> initialSelection;
  final Function(List<User>) onUsersSelected;

  const UserSearchDialog({
    super.key,
    this.title = 'Search Users',
    this.hintText,
    this.excludeUserIds = const [],
    this.multiSelect = false,
    this.initialSelection = const [],
    required this.onUsersSelected,
  });

  @override
  ConsumerState<UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends ConsumerState<UserSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  bool _showRecentUsers = true;

  @override
  void initState() {
    super.initState();
    _selectedUserIds.addAll(widget.initialSelection);
    
    // Load recent users initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userSearchProvider.notifier).clearSearch();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(userSearchProvider);
    final recentUsersAsync = ref.watch(recentUsersProvider);

    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search Field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(userSearchProvider.notifier).clearSearch();
                          setState(() {
                            _showRecentUsers = true;
                          });
                        },
                      )
                    : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (query) {
                  setState(() {
                    _showRecentUsers = query.isEmpty;
                  });
                  
                  if (query.isNotEmpty) {
                    ref.read(userSearchProvider.notifier).searchUsers(query);
                  } else {
                    ref.read(userSearchProvider.notifier).clearSearch();
                  }
                },
              ),
            ),

            // Results
            Expanded(
              child: _showRecentUsers
                ? _buildRecentUsers(recentUsersAsync)
                : _buildSearchResults(searchState),
            ),

            // Footer with selection info and actions
            if (widget.multiSelect) _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentUsers(AsyncValue<List<User>> recentUsersAsync) {
    return recentUsersAsync.when(
      data: (users) {
        final filteredUsers = users
            .where((user) => !widget.excludeUserIds.contains(user.id))
            .toList();

        if (filteredUsers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No recent users found',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Start typing to search for users',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Recent Users',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  return _buildUserTile(user);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Text('Error loading recent users'),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<User>> searchState) {
    return searchState.when(
      data: (users) {
        final filteredUsers = users
            .where((user) => !widget.excludeUserIds.contains(user.id))
            .toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Try a different search term',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            return _buildUserTile(user);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Search failed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(User user) {
    final isSelected = _selectedUserIds.contains(user.id);

    if (widget.multiSelect) {
      return UserListTileSelectable(
        user: user,
        isSelected: isSelected,
        onSelected: (selected) {
          setState(() {
            if (selected) {
              _selectedUserIds.add(user.id);
            } else {
              _selectedUserIds.remove(user.id);
            }
          });
        },
      );
    } else {
      return UserListTile(
        user: user,
        selected: isSelected,
        onTap: () {
          ref.read(userSearchProvider.notifier).clearSearch();
          Navigator.pop(context);
          widget.onUsersSelected([user]);
        },
      );
    }
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Selection count
          Expanded(
            child: Text(
              '${_selectedUserIds.length} user${_selectedUserIds.length == 1 ? '' : 's'} selected',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          
          // Clear selection
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedUserIds.clear();
                });
              },
              child: const Text('Clear All'),
            ),

          const SizedBox(width: 8),

          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),

          const SizedBox(width: 8),

          // Confirm button
          ElevatedButton(
            onPressed: _selectedUserIds.isNotEmpty ? () => _confirmSelection() : null,
            child: const Text('Add Users'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSelection() async {
    if (_selectedUserIds.isEmpty) return;

    // Get the selected users
    final userService = ref.read(userServiceProvider);
    final selectedUsers = await userService.getUsersByIds(_selectedUserIds.toList());
    
    if (mounted) {
      ref.read(userSearchProvider.notifier).clearSearch();
      Navigator.pop(context);
      widget.onUsersSelected(selectedUsers.values.toList());
    }
  }
}

/// Static method to show the user search dialog
class UserSearchDialogHelper {
  static Future<List<User>?> show(
    BuildContext context, {
    String title = 'Search Users',
    String? hintText,
    List<String> excludeUserIds = const [],
    bool multiSelect = false,
    List<String> initialSelection = const [],
  }) async {
    List<User>? selectedUsers;

    await showDialog<void>(
      context: context,
      builder: (context) => UserSearchDialog(
        title: title,
        hintText: hintText,
        excludeUserIds: excludeUserIds,
        multiSelect: multiSelect,
        initialSelection: initialSelection,
        onUsersSelected: (users) {
          selectedUsers = users;
        },
      ),
    );

    return selectedUsers;
  }

  /// Show dialog for selecting a single user
  static Future<User?> showSingle(
    BuildContext context, {
    String title = 'Select User',
    String? hintText,
    List<String> excludeUserIds = const [],
  }) async {
    final result = await show(
      context,
      title: title,
      hintText: hintText,
      excludeUserIds: excludeUserIds,
      multiSelect: false,
    );

    return result?.isNotEmpty == true ? result!.first : null;
  }

  /// Show dialog for selecting multiple users
  static Future<List<User>?> showMultiple(
    BuildContext context, {
    String title = 'Select Users',
    String? hintText,
    List<String> excludeUserIds = const [],
    List<String> initialSelection = const [],
  }) async {
    return await show(
      context,
      title: title,
      hintText: hintText,
      excludeUserIds: excludeUserIds,
      multiSelect: true,
      initialSelection: initialSelection,
    );
  }
}