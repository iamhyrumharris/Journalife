import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/journal.dart';
import '../../models/entry.dart';
import '../../providers/entry_provider.dart';
import '../../providers/journal_provider.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
            Tab(icon: Icon(Icons.sync), text: 'Sync'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildInfoTab(), _buildSyncTab()],
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
          }),

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

            // Show sync configuration controls for each config
            if (configs.isNotEmpty) ...[
              const Text(
                'Include this journal in sync configurations:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              ...configs.map((config) {
                final isIncluded = config.syncedJournalIds.contains(widget.journal.id);
                return Card(
                  color: isIncluded 
                    ? (config.enabled ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1))
                    : null,
                  child: SwitchListTile(
                    title: Text(config.displayName),
                    subtitle: Text(
                      config.enabled 
                        ? (isIncluded ? 'Active sync • Included' : 'Active sync • Not included')
                        : 'Sync paused',
                      style: TextStyle(
                        fontSize: 12,
                        color: config.enabled 
                          ? (isIncluded ? Colors.green[700] : Colors.grey[600])
                          : Colors.grey[500],
                      ),
                    ),
                    value: isIncluded,
                    onChanged: (value) => _toggleJournalInSync(config.id, value),
                    secondary: Icon(
                      config.enabled
                        ? (isIncluded ? Icons.cloud_done : Icons.cloud_off)
                        : Icons.cloud_off,
                      color: config.enabled 
                        ? (isIncluded ? Colors.green : Colors.grey)
                        : Colors.grey,
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),
              
              // Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This journal is included in ${configs.where((c) => c.syncedJournalIds.contains(widget.journal.id)).length} of ${configs.length} sync configurations.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Quick actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: configs.any((c) => !c.syncedJournalIds.contains(widget.journal.id))
                        ? () => _addToAllSyncConfigs(configs)
                        : null,
                      icon: const Icon(Icons.add_to_photos, size: 16),
                      label: const Text('Add to All'),
                      style: OutlinedButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: configs.any((c) => c.syncedJournalIds.contains(widget.journal.id))
                        ? () => _removeFromAllSyncConfigs(configs)
                        : null,
                      icon: const Icon(Icons.remove_from_queue, size: 16),
                      label: const Text('Remove from All'),
                      style: OutlinedButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'No sync configurations found. Create a WebDAV configuration to sync this journal.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _addWebDAVConfiguration,
                icon: const Icon(Icons.add),
                label: const Text('Add WebDAV Configuration'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ],
        ),
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

  void _toggleJournalInSync(String configId, bool include) async {
    try {
      final configs = ref.read(syncConfigProvider).value ?? [];
      final config = configs.firstWhere((c) => c.id == configId);
      
      List<String> updatedJournalIds = List.from(config.syncedJournalIds);
      
      if (include) {
        // Add journal to sync if not already included
        if (!updatedJournalIds.contains(widget.journal.id)) {
          updatedJournalIds.add(widget.journal.id);
        }
      } else {
        // Remove journal from sync
        updatedJournalIds.removeWhere((id) => id == widget.journal.id);
      }
      
      // Update the sync configuration
      await ref.read(syncConfigProvider.notifier).updateSyncedJournals(
        configId, 
        updatedJournalIds,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              include 
                ? 'Journal added to ${config.displayName} sync'
                : 'Journal removed from ${config.displayName} sync',
            ),
            backgroundColor: include ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update sync settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addToAllSyncConfigs(List<SyncConfig> configs) async {
    try {
      int addedCount = 0;
      
      for (final config in configs) {
        if (!config.syncedJournalIds.contains(widget.journal.id)) {
          final updatedJournalIds = [...config.syncedJournalIds, widget.journal.id];
          await ref.read(syncConfigProvider.notifier).updateSyncedJournals(
            config.id,
            updatedJournalIds,
          );
          addedCount++;
        }
      }
      
      if (mounted && addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Journal added to $addedCount sync configuration${addedCount == 1 ? '' : 's'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to all sync configurations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFromAllSyncConfigs(List<SyncConfig> configs) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from All Sync Configurations'),
        content: Text(
          'Are you sure you want to remove "${widget.journal.name}" from all sync configurations? This will stop it from being backed up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Remove from All'),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      try {
        int removedCount = 0;
        
        for (final config in configs) {
          if (config.syncedJournalIds.contains(widget.journal.id)) {
            final updatedJournalIds = config.syncedJournalIds
                .where((id) => id != widget.journal.id)
                .toList();
            await ref.read(syncConfigProvider.notifier).updateSyncedJournals(
              config.id,
              updatedJournalIds,
            );
            removedCount++;
          }
        }
        
        if (mounted && removedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Journal removed from $removedCount sync configuration${removedCount == 1 ? '' : 's'}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove from sync configurations: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

}
