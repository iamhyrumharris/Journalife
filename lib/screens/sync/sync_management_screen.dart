import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/sync_config.dart';
import '../../models/sync_status.dart';
import '../../providers/sync_config_provider.dart';
import '../../providers/sync_provider.dart';
import 'webdav_setup_screen.dart';

class SyncManagementScreen extends ConsumerStatefulWidget {
  const SyncManagementScreen({super.key});

  @override
  ConsumerState<SyncManagementScreen> createState() => _SyncManagementScreenState();
}

class _SyncManagementScreenState extends ConsumerState<SyncManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final syncConfigsAsync = ref.watch(syncConfigProvider);
    final isAnySyncActive = ref.watch(isAnySyncActiveProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewConfiguration,
            tooltip: 'Add WebDAV Configuration',
          ),
        ],
      ),
      body: syncConfigsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading sync configurations'),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(syncConfigProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (configs) => _buildConfigurationsList(configs, isAnySyncActive),
      ),
    );
  }

  Widget _buildConfigurationsList(List<SyncConfig> configs, bool isAnySyncActive) {
    if (configs.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(syncConfigProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: configs.length,
        itemBuilder: (context, index) {
          final config = configs[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildConfigurationCard(config),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_sync,
              size: 96,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Sync Configurations',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Set up WebDAV sync to keep your journals backed up and synchronized across devices.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addNewConfiguration,
              icon: const Icon(Icons.add),
              label: const Text('Add WebDAV Configuration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationCard(SyncConfig config) {
    final syncStatus = ref.watch(syncStatusProvider(config.id));

    return Card(
      elevation: 2,
      child: Column(
        children: [
          ListTile(
            leading: _buildStatusIndicator(config, syncStatus),
            title: Text(
              config.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.serverUrl),
                const SizedBox(height: 4),
                Text(
                  'User: ${config.username} • ${_getSyncFrequencyLabel(config.syncFrequency)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _handleConfigAction(action, config),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'test',
                  child: Row(
                    children: [
                      Icon(Icons.wifi_protected_setup),
                      SizedBox(width: 8),
                      Text('Test Connection'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: config.enabled ? 'disable' : 'enable',
                  child: Row(
                    children: [
                      Icon(config.enabled ? Icons.pause : Icons.play_arrow),
                      const SizedBox(width: 8),
                      Text(config.enabled ? 'Disable' : 'Enable'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _showConfigDetails(config, syncStatus),
          ),
          
          if (syncStatus?.isActive == true)
            _buildSyncProgress(syncStatus!),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Last sync: ${_formatLastSync(config.lastSyncAt)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
                if (config.enabled && syncStatus?.isActive != true)
                  ElevatedButton.icon(
                    onPressed: () => _startManualSync(config.id),
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Sync Now'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (syncStatus?.isActive == true)
                  ElevatedButton.icon(
                    onPressed: () => _cancelSync(config.id),
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(SyncConfig config, SyncStatus? status) {
    if (!config.enabled) {
      return const Icon(Icons.pause_circle, color: Colors.grey);
    }

    if (status?.isActive == true) {
      return const Icon(Icons.sync, color: Colors.blue);
    }

    switch (status?.state) {
      case SyncState.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case SyncState.failed:
        return const Icon(Icons.error, color: Colors.red);
      case SyncState.cancelled:
        return const Icon(Icons.cancel, color: Colors.orange);
      default:
        return const Icon(Icons.cloud, color: Colors.grey);
    }
  }

  Widget _buildSyncProgress(SyncStatus status) {
    final progress = status.progress;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getSyncStateLabel(status.state),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (status.currentItem != null)
                      Text(
                        'Processing: ${status.currentItem}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${status.completedItems}/${status.totalItems}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  void _addNewConfiguration() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const WebDAVSetupScreen(),
      ),
    );

    if (result == true) {
      // Configuration was saved, refresh the list
      ref.invalidate(syncConfigProvider);
    }
  }

  void _handleConfigAction(String action, SyncConfig config) {
    switch (action) {
      case 'edit':
        _editConfiguration(config);
        break;
      case 'test':
        _testConfiguration(config);
        break;
      case 'enable':
        _toggleConfiguration(config, true);
        break;
      case 'disable':
        _toggleConfiguration(config, false);
        break;
      case 'delete':
        _deleteConfiguration(config);
        break;
    }
  }

  void _editConfiguration(SyncConfig config) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => WebDAVSetupScreen(config: config),
      ),
    );

    if (result == true) {
      ref.invalidate(syncConfigProvider);
    }
  }

  void _testConfiguration(SyncConfig config) async {
    try {
      final password = await ref.read(syncPasswordProvider(config.id).future);
      if (password == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No password stored for this configuration'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final success = await ref.read(syncProvider.notifier).testConnection(config, password);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Connection successful!' : 'Connection failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleConfiguration(SyncConfig config, bool enabled) async {
    try {
      await ref.read(syncConfigProvider.notifier).toggleConfiguration(config.id, enabled);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enabled ? 'Configuration enabled' : 'Configuration disabled'),
            backgroundColor: enabled ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${enabled ? 'enable' : 'disable'} configuration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteConfiguration(SyncConfig config) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Configuration'),
        content: Text('Are you sure you want to delete "${config.displayName}"?\n\nThis will stop all sync operations for this configuration.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await ref.read(syncConfigProvider.notifier).deleteConfiguration(config.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuration deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete configuration: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _startManualSync(String configId) async {
    try {
      await ref.read(syncProvider.notifier).startSync(configId);
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

  void _cancelSync(String configId) async {
    await ref.read(syncProvider.notifier).cancelSync(configId);
  }

  void _showConfigDetails(SyncConfig config, SyncStatus? status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(config.displayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Server URL', config.serverUrl),
              _buildDetailRow('Username', config.username),
              _buildDetailRow('Sync Frequency', _getSyncFrequencyLabel(config.syncFrequency)),
              _buildDetailRow('WiFi Only', config.syncOnWifiOnly ? 'Yes' : 'No'),
              _buildDetailRow('Sync Attachments', config.syncAttachments ? 'Yes' : 'No'),
              _buildDetailRow('Encrypt Data', config.encryptData ? 'Yes' : 'No'),
              _buildDetailRow('Status', config.enabled ? 'Enabled' : 'Disabled'),
              _buildDetailRow('Last Sync', _formatLastSync(config.lastSyncAt)),
              _buildDetailRow('Created', DateFormat('MMM d, yyyy').format(config.createdAt)),
              
              if (status != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Current Sync Status',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow('State', _getSyncStateLabel(status.state)),
                if (status.errorMessage != null)
                  _buildDetailRow('Error', status.errorMessage!),
                if (status.totalItems > 0)
                  _buildDetailRow('Progress', '${status.completedItems}/${status.totalItems}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editConfiguration(config);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getSyncFrequencyLabel(SyncFrequency frequency) {
    switch (frequency) {
      case SyncFrequency.manual:
        return 'Manual';
      case SyncFrequency.onAppStart:
        return 'On App Start';
      case SyncFrequency.hourly:
        return 'Every Hour';
      case SyncFrequency.daily:
        return 'Daily';
      case SyncFrequency.weekly:
        return 'Weekly';
    }
  }

  String _getSyncStateLabel(SyncState state) {
    switch (state) {
      case SyncState.idle:
        return 'Idle';
      case SyncState.checking:
        return 'Checking for changes...';
      case SyncState.uploading:
        return 'Uploading changes...';
      case SyncState.downloading:
        return 'Downloading changes...';
      case SyncState.syncing:
        return 'Synchronizing...';
      case SyncState.resolving:
        return 'Resolving conflicts...';
      case SyncState.completed:
        return 'Completed';
      case SyncState.failed:
        return 'Failed';
      case SyncState.cancelled:
        return 'Cancelled';
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