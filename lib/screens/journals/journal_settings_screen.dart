import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/journal.dart';
import '../../models/entry.dart';
import '../../providers/entry_provider.dart';
import '../../providers/journal_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/user_list_tile.dart';
import '../../widgets/user_search_dialog.dart';
import '../../providers/sync_config_provider.dart';
import '../../providers/sync_provider.dart';
import '../../models/sync_config.dart';
import '../../models/sync_status.dart';
import 'journal_edit_screen.dart';
import '../sync/webdav_setup_screen.dart';
import '../sync/sync_management_screen.dart';

class JournalSettingsScreen extends ConsumerStatefulWidget {
  final Journal journal;

  const JournalSettingsScreen({super.key, required this.journal});

  @override
  ConsumerState<JournalSettingsScreen> createState() =>
      _JournalSettingsScreenState();
}

class _JournalSettingsScreenState extends ConsumerState<JournalSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.journal.name} Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      JournalEditScreen(journal: widget.journal),
                ),
              );
            },
            tooltip: 'Edit Journal',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Info'),
            Tab(icon: Icon(Icons.people), text: 'Sharing'),
            Tab(icon: Icon(Icons.sync), text: 'Sync'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildInfoTab(), _buildSharingTab(), _buildSyncTab()],
      ),
    );
  }

  Widget _buildInfoTab() {
    return Consumer(
      builder: (context, ref, child) {
        final entriesAsync = ref.watch(entryProvider(widget.journal.id));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Journal Preview Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (widget.journal.icon != null)
                        Text(
                          widget.journal.icon!,
                          style: const TextStyle(fontSize: 48),
                        )
                      else
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: widget.journal.color != null
                                ? Color(
                                    int.parse(widget.journal.color!, radix: 16),
                                  )
                                : Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.book,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.journal.name,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (widget.journal.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                widget.journal.description,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Statistics
              Text(
                'Statistics',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              entriesAsync.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading statistics: $error'),
                  ),
                ),
                data: (entries) => _buildStatisticsCard(entries),
              ),

              const SizedBox(height: 24),

              // Journal Details
              Text(
                'Details',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _buildDetailsCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatisticsCard(List<Entry> entries) {
    final totalEntries = entries.length;
    final totalWords = entries.fold<int>(
      0,
      (sum, entry) =>
          sum +
          (entry.title.split(' ').length + entry.content.split(' ').length),
    );
    final entriesWithAttachments = entries
        .where((e) => e.hasAttachments)
        .length;
    final entriesWithLocation = entries.where((e) => e.hasLocation).length;
    final entriesWithRating = entries.where((e) => e.hasRating).length;

    // Calculate average rating
    double? averageRating;
    if (entriesWithRating > 0) {
      final totalRating = entries
          .where((e) => e.hasRating)
          .fold<int>(0, (sum, entry) => sum + (entry.rating ?? 0));
      averageRating = totalRating / entriesWithRating;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.edit_note,
                    title: 'Entries',
                    value: totalEntries.toString(),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.article,
                    title: 'Words',
                    value: NumberFormat('#,###').format(totalWords),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.attachment,
                    title: 'With Media',
                    value: entriesWithAttachments.toString(),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.location_on,
                    title: 'With Location',
                    value: entriesWithLocation.toString(),
                  ),
                ),
              ],
            ),
            if (averageRating != null) ...[
              const Divider(),
              _buildStatItem(
                icon: Icons.star,
                title: 'Average Rating',
                value: averageRating.toStringAsFixed(1),
                subtitle: '$entriesWithRating rated entries',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[500],
              fontSize: 10,
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      child: Column(
        children: [
          UserListTile(
            userId: widget.journal.ownerId,
            subtitle: 'Owner',
            trailing: Icon(Icons.star, color: Colors.amber),
            enabled: false,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Created'),
            subtitle: Text(
              DateFormat(
                'EEEE, MMMM d, yyyy \'at\' h:mm a',
              ).format(widget.journal.createdAt),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text('Last Modified'),
            subtitle: Text(
              DateFormat(
                'EEEE, MMMM d, yyyy \'at\' h:mm a',
              ).format(widget.journal.updatedAt),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Journal ID'),
            subtitle: Text(widget.journal.id),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.journal.id));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID copied to clipboard')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharingTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sharing Settings',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Sharing'),
                  subtitle: const Text('Allow others to access this journal'),
                  value: widget.journal.isShared,
                  onChanged: (value) {
                    _toggleSharing(value);
                  },
                ),
                if (widget.journal.isShared) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Shared Users'),
                    subtitle: Row(
                      children: [
                        if (widget.journal.sharedWithUserIds.isNotEmpty)
                          UserAvatarStack(
                            userIds: widget.journal.sharedWithUserIds,
                            radius: 12,
                            maxVisible: 3,
                          ),
                        if (widget.journal.sharedWithUserIds.isNotEmpty)
                          const SizedBox(width: 8),
                        Text(
                          '${widget.journal.sharedWithUserIds.length} user${widget.journal.sharedWithUserIds.length == 1 ? '' : 's'}',
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showSharedUsers();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: const Text('Share Link'),
                    subtitle: const Text(
                      'Generate a link to share this journal',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _generateShareLink();
                    },
                  ),
                ],
              ],
            ),
          ),

          if (!widget.journal.isShared) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'When you enable sharing, you can invite others to read and contribute to this journal.',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncTab() {
    return Consumer(
      builder: (context, ref, child) {
        final syncConfigsAsync = ref.watch(syncConfigProvider);
        final isAnySyncActive = ref.watch(isAnySyncActiveProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sync Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openSyncManagement,
                    icon: const Icon(Icons.settings),
                    label: const Text('Manage'),
                    style: ElevatedButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              syncConfigsAsync.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, stack) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('Error loading sync configurations'),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => ref.invalidate(syncConfigProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (configs) => Column(
                  children: [
                    _buildSyncConfigurationsList(configs, isAnySyncActive),
                    const SizedBox(height: 16),
                    _buildJournalSyncPreferences(configs),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSyncConfigurationsList(
    List<SyncConfig> configs,
    bool isAnySyncActive,
  ) {
    if (configs.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.cloud_sync, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Sync Configurations',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set up WebDAV sync to keep your journals backed up and synchronized.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _addWebDAVConfiguration,
                icon: const Icon(Icons.add),
                label: const Text('Add WebDAV Configuration'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.cloud_sync),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WebDAV Configurations',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${configs.length} configuration${configs.length == 1 ? '' : 's'} • ${configs.where((c) => c.enabled).length} active',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isAnySyncActive)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),

          ...configs.take(3).map((config) {
            final syncStatus = ref.watch(syncStatusProvider(config.id));
            return Column(
              children: [
                const Divider(height: 1),
                ListTile(
                  leading: _buildSyncStatusIcon(config, syncStatus),
                  title: Text(config.displayName),
                  subtitle: Text(
                    'Last sync: ${_formatLastSync(config.lastSyncAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: config.enabled && syncStatus?.isActive != true
                      ? IconButton(
                          icon: const Icon(Icons.sync, size: 20),
                          onPressed: () => _startManualSync(config.id),
                          tooltip: 'Sync now',
                        )
                      : null,
                ),
              ],
            );
          }).toList(),

          if (configs.length > 3) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton.icon(
                onPressed: _openSyncManagement,
                icon: const Icon(Icons.more_horiz),
                label: Text('View all ${configs.length} configurations'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncStatusIcon(SyncConfig config, SyncStatus? status) {
    if (!config.enabled) {
      return const Icon(Icons.pause_circle, color: Colors.grey, size: 20);
    }

    if (status?.isActive == true) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (status?.state) {
      case SyncState.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case SyncState.failed:
        return const Icon(Icons.error, color: Colors.red, size: 20);
      case SyncState.cancelled:
        return const Icon(Icons.cancel, color: Colors.orange, size: 20);
      default:
        return const Icon(Icons.cloud, color: Colors.grey, size: 20);
    }
  }

  Widget _buildJournalSyncPreferences(List<SyncConfig> configs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journal Sync Preferences',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Show which sync configs include this journal
            if (configs.isNotEmpty) ...[
              const Text(
                'This journal is included in:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...configs
                  .where(
                    (config) =>
                        config.syncedJournalIds.contains(widget.journal.id),
                  )
                  .map(
                    (config) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            config.enabled
                                ? Icons.check_circle
                                : Icons.pause_circle,
                            size: 16,
                            color: config.enabled ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(config.displayName)),
                          if (config.enabled)
                            Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.green[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

              if (configs
                  .where(
                    (config) =>
                        config.syncedJournalIds.contains(widget.journal.id),
                  )
                  .isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'This journal is not included in any sync configurations.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ] else ...[
              const Text(
                'No sync configurations found. Create a WebDAV configuration to sync this journal.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleSharing(bool enabled) async {
    try {
      final updatedJournal = enabled
          ? widget
                .journal // Keep current shared users when enabling
          : widget.journal.copyWith(
              sharedWithUserIds: [],
            ); // Clear shared users when disabling

      // Update the journal in the database
      await ref.read(journalProvider.notifier).updateJournal(updatedJournal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Sharing enabled - you can now add users'
                  : 'Sharing disabled - all users removed',
            ),
            backgroundColor: enabled ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSharedUsers() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shared Users'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.journal.sharedWithUserIds.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No users are currently sharing this journal.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...widget.journal.sharedWithUserIds.map(
                (userId) => UserListTile(
                  userId: userId,
                  subtitle: 'Shared user',
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      _removeUserFromSharing(userId);
                    },
                    tooltip: 'Remove from sharing',
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showAddUserDialog();
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Add User'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddUserDialog() async {
    // Exclude current users (owner + already shared users)
    final excludeUserIds = [
      widget.journal.ownerId,
      ...widget.journal.sharedWithUserIds,
    ];

    final selectedUsers = await UserSearchDialogHelper.showMultiple(
      context,
      title: 'Add Users to Journal',
      hintText: 'Search by name or email...',
      excludeUserIds: excludeUserIds,
    );

    if (selectedUsers != null && selectedUsers.isNotEmpty) {
      for (final user in selectedUsers) {
        _addUserToSharing(user.id);
      }
    }
  }

  void _generateShareLink() {
    // Generate a more secure share link with timestamp and encoded data
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final encodedData = _encodeJournalShareData(widget.journal.id, timestamp);
    final shareLink = 'https://journal.app/join/$encodedData';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share "${widget.journal.name}" with others:'),
            const SizedBox(height: 8),
            const Text(
              'Anyone with this link can request access to your journal.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(shareLink),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: shareLink));
              navigator.pop();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              }
            },
            child: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  void _openSyncManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SyncManagementScreen()),
    );
  }

  void _addWebDAVConfiguration() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const WebDAVSetupScreen()),
    );

    if (result == true) {
      ref.invalidate(syncConfigProvider);
    }
  }

  void _startManualSync(String configId) async {
    try {
      await ref.read(syncProvider.notifier).startSync(configId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manual sync started'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start sync: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatLastSync(DateTime lastSync) {
    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(lastSync);
    }
  }

  void _addUserToSharing(String userId) async {
    try {
      // Check if user is already shared
      if (widget.journal.sharedWithUserIds.contains(userId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User is already added to this journal'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Add user to shared list
      final updatedSharedUsers = [...widget.journal.sharedWithUserIds, userId];
      final updatedJournal = widget.journal.copyWith(
        sharedWithUserIds: updatedSharedUsers,
      );

      // Update the journal in the database
      await ref.read(journalProvider.notifier).updateJournal(updatedJournal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $userId to journal sharing'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeUserFromSharing(String userId) async {
    try {
      // Show confirmation dialog
      final shouldRemove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove User'),
          content: Text('Remove $userId from journal sharing?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      );

      if (shouldRemove == true) {
        // Remove user from shared list
        final updatedSharedUsers = widget.journal.sharedWithUserIds
            .where((id) => id != userId)
            .toList();
        final updatedJournal = widget.journal.copyWith(
          sharedWithUserIds: updatedSharedUsers,
        );

        // Update the journal in the database
        await ref.read(journalProvider.notifier).updateJournal(updatedJournal);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed $userId from journal sharing'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Encodes journal share data for secure link generation
  String _encodeJournalShareData(String journalId, int timestamp) {
    // Simple encoding - in a real app, this would use proper encryption
    // For now, we'll use a base64 encoding of the journal data
    final dataString = '$journalId:$timestamp:${widget.journal.name}';
    final bytes = dataString.codeUnits;
    final base64String = base64Encode(bytes);

    // Make the link shorter and more user-friendly
    return base64String
        .replaceAll('/', '_')
        .replaceAll('+', '-')
        .substring(0, 16);
  }
}
