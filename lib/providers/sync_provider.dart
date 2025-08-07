import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sync_config.dart';
import '../models/sync_status.dart';
import '../services/database_service.dart';
import '../services/webdav_sync_service.dart';
import 'sync_config_provider.dart';
import 'database_provider.dart';

/// Provider for WebDAV sync operations and status
final syncProvider = StateNotifierProvider<SyncNotifier, Map<String, SyncStatus>>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return SyncNotifier(ref, databaseService);
});

/// Provider for getting sync status of a specific configuration
final syncStatusProvider = Provider.family<SyncStatus?, String>((ref, configId) {
  final syncStatuses = ref.watch(syncProvider);
  return syncStatuses[configId];
});

/// Provider for checking if any sync is currently active
final isAnySyncActiveProvider = Provider<bool>((ref) {
  final syncStatuses = ref.watch(syncProvider);
  return syncStatuses.values.any((status) => status.isActive);
});

/// Provider for getting all active sync operations
final activeSyncsProvider = Provider<List<SyncStatus>>((ref) {
  final syncStatuses = ref.watch(syncProvider);
  return syncStatuses.values.where((status) => status.isActive).toList();
});

/// Notifier for managing sync operations
class SyncNotifier extends StateNotifier<Map<String, SyncStatus>> {
  final Ref _ref;
  final DatabaseService _databaseService;
  final WebDAVSyncService _syncService = WebDAVSyncService();
  final Map<String, StreamSubscription?> _syncSubscriptions = {};

  SyncNotifier(this._ref, this._databaseService) : super({}) {
    _loadSyncStatuses();
  }

  @override
  void dispose() {
    // Cancel all active subscriptions
    for (final subscription in _syncSubscriptions.values) {
      subscription?.cancel();
    }
    _syncSubscriptions.clear();
    super.dispose();
  }

  /// Loads sync statuses from persistent storage
  Future<void> _loadSyncStatuses() async {
    try {
      // Load saved sync statuses from database
      final statuses = await _databaseService.getSyncStatuses();
      final statusMap = <String, SyncStatus>{};
      
      for (final status in statuses) {
        // Reset any statuses that were left in active states
        if (status.isActive) {
          statusMap[status.configId] = status.copyWith(
            state: SyncState.idle,
          );
        } else {
          statusMap[status.configId] = status;
        }
      }
      
      state = statusMap;
    } catch (e) {
      debugPrint('Failed to load sync statuses: $e');
    }
  }

  /// Starts a manual sync for a configuration
  Future<void> startSync(String configId) async {
    try {
      final syncConfigsAsync = _ref.read(syncConfigProvider);
      final syncConfigs = syncConfigsAsync.value;
      if (syncConfigs == null) {
        throw Exception('Sync configurations not loaded');
      }
      
      final config = syncConfigs.firstWhere(
        (c) => c.id == configId,
        orElse: () => throw Exception('Sync configuration not found: $configId'),
      );
      
      if (!config.enabled) {
        throw Exception('Sync configuration is disabled');
      }

      // Get stored password
      final password = await _databaseService.getSyncPassword(configId);
      if (password == null || password.isEmpty) {
        throw Exception('No password stored for this configuration');
      }

      // Initialize sync service
      await _syncService.initialize(config, password);

      // Create initial status
      var status = SyncStatus(
        configId: configId,
        state: SyncState.checking,
        lastAttemptAt: DateTime.now(),
      );
      
      _updateSyncStatus(status);

      // Cancel any existing sync for this config
      await cancelSync(configId);

      // Start the sync operation
      _syncSubscriptions[configId] = _performSyncOperation(config, password);

    } catch (error) {
      final status = SyncStatus(
        configId: configId,
        state: SyncState.failed,
        lastAttemptAt: DateTime.now(),
        errorMessage: error.toString(),
      );
      
      _updateSyncStatus(status);
      rethrow;
    }
  }

  /// Performs the actual sync operation
  StreamSubscription<void> _performSyncOperation(SyncConfig config, String password) {
    late StreamController<void> controller;
    
    controller = StreamController<void>();
    
    // Run sync in background
    _runSync(config, password).then((_) {
      controller.close();
    }).catchError((error) {
      final status = SyncStatus(
        configId: config.id,
        state: SyncState.failed,
        lastAttemptAt: DateTime.now(),
        errorMessage: error.toString(),
      );
      
      _updateSyncStatus(status);
      controller.addError(error);
      controller.close();
    });
    
    return controller.stream.listen(null);
  }

  /// Runs the sync operation with status updates
  Future<void> _runSync(SyncConfig config, String password) async {
    try {
      await _syncService.initialize(config, password);
      
      await _syncService.performSync(
        onStatusUpdate: (status) {
          _updateSyncStatus(status);
        },
      );

      // Update last sync time in configuration
      await _ref.read(syncConfigProvider.notifier).updateLastSyncTime(config.id);

    } catch (error) {
      rethrow;
    }
  }

  /// Cancels an active sync operation
  Future<void> cancelSync(String configId) async {
    final subscription = _syncSubscriptions[configId];
    if (subscription != null) {
      await subscription.cancel();
      _syncSubscriptions.remove(configId);
      
      // Update status to cancelled
      final currentStatus = state[configId];
      if (currentStatus?.isActive == true) {
        final cancelledStatus = currentStatus!.copyWith(
          state: SyncState.cancelled,
        );
        _updateSyncStatus(cancelledStatus);
      }
    }
  }

  /// Tests connection to a WebDAV server
  Future<bool> testConnection(SyncConfig config, String password) async {
    try {
      return await _syncService.testConnection(config, password);
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  /// Gets the current sync status for a configuration
  SyncStatus? getSyncStatus(String configId) {
    return state[configId];
  }

  /// Gets sync progress for a configuration (0.0 to 1.0)
  double getSyncProgress(String configId) {
    final status = state[configId];
    return status?.progress ?? 0.0;
  }

  /// Checks if a configuration is currently syncing
  bool isSyncing(String configId) {
    final status = state[configId];
    return status?.isActive ?? false;
  }

  /// Updates the sync status and persists it
  void _updateSyncStatus(SyncStatus status) {
    final updatedState = Map<String, SyncStatus>.from(state);
    updatedState[status.configId] = status;
    state = updatedState;
    
    // Persist status to database
    _saveSyncStatus(status);
  }

  /// Saves sync status to persistent storage
  Future<void> _saveSyncStatus(SyncStatus status) async {
    try {
      await _databaseService.saveSyncStatus(status);
    } catch (e) {
      debugPrint('Failed to save sync status: $e');
    }
  }

  /// Clears sync history for a configuration
  Future<void> clearSyncHistory(String configId) async {
    try {
      await _databaseService.clearSyncHistory(configId);
      
      // Reset status to initial state
      final status = SyncStatus(
        configId: configId,
        lastAttemptAt: DateTime.now(),
      );
      
      _updateSyncStatus(status);
    } catch (e) {
      debugPrint('Failed to clear sync history: $e');
    }
  }

  /// Gets sync statistics for a configuration
  Future<SyncStatistics> getSyncStatistics(String configId) async {
    try {
      return await _databaseService.getSyncStatistics(configId);
    } catch (e) {
      return SyncStatistics.empty(configId);
    }
  }

  /// Starts automatic sync based on configuration settings
  Future<void> startAutomaticSync() async {
    try {
      final syncConfigsAsync = _ref.read(syncConfigProvider);
      final configs = syncConfigsAsync.value;
      if (configs == null) {
        throw Exception('Sync configurations not loaded');
      }
      final enabledConfigs = configs.where((c) => 
        c.enabled && c.syncFrequency != SyncFrequency.manual
      );
      
      for (final config in enabledConfigs) {
        if (_shouldAutoSync(config)) {
          await startSync(config.id);
        }
      }
    } catch (e) {
      debugPrint('Failed to start automatic sync: $e');
    }
  }

  /// Determines if a configuration should auto-sync based on its schedule
  bool _shouldAutoSync(SyncConfig config) {
    final now = DateTime.now();
    final timeSinceLastSync = now.difference(config.lastSyncAt);
    
    switch (config.syncFrequency) {
      case SyncFrequency.manual:
        return false;
      case SyncFrequency.onAppStart:
        return true; // Always sync on app start if enabled
      case SyncFrequency.hourly:
        return timeSinceLastSync.inHours >= 1;
      case SyncFrequency.daily:
        return timeSinceLastSync.inDays >= 1;
      case SyncFrequency.weekly:
        return timeSinceLastSync.inDays >= 7;
    }
  }
}

/// Statistics about sync operations for a configuration
class SyncStatistics {
  final String configId;
  final int totalSyncs;
  final int successfulSyncs;
  final int failedSyncs;
  final DateTime? lastSuccessfulSync;
  final DateTime? lastFailedSync;
  final int totalItemsSynced;
  final int totalBytesSynced;

  const SyncStatistics({
    required this.configId,
    this.totalSyncs = 0,
    this.successfulSyncs = 0,
    this.failedSyncs = 0,
    this.lastSuccessfulSync,
    this.lastFailedSync,
    this.totalItemsSynced = 0,
    this.totalBytesSynced = 0,
  });

  factory SyncStatistics.empty(String configId) {
    return SyncStatistics(configId: configId);
  }

  double get successRate {
    if (totalSyncs == 0) return 0.0;
    return successfulSyncs / totalSyncs;
  }

  String get formattedTotalBytes {
    if (totalBytesSynced < 1024) return '$totalBytesSynced B';
    if (totalBytesSynced < 1024 * 1024) return '${(totalBytesSynced / 1024).toStringAsFixed(1)} KB';
    if (totalBytesSynced < 1024 * 1024 * 1024) return '${(totalBytesSynced / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(totalBytesSynced / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}