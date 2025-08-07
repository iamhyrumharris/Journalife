import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/sync_config.dart';
import '../services/database_service.dart';
import '../services/webdav_sync_service.dart';
import 'database_provider.dart';

/// Provider for WebDAV sync configuration management
final syncConfigProvider =
    StateNotifierProvider<SyncConfigNotifier, AsyncValue<List<SyncConfig>>>((
      ref,
    ) {
      final databaseService = ref.watch(databaseServiceProvider);
      return SyncConfigNotifier(databaseService);
    });

/// Provider for the currently active sync configuration
final activeSyncConfigProvider = StateProvider<SyncConfig?>((ref) => null);

/// Notifier for managing sync configurations
class SyncConfigNotifier extends StateNotifier<AsyncValue<List<SyncConfig>>> {
  final DatabaseService _databaseService;
  final _uuid = const Uuid();

  SyncConfigNotifier(this._databaseService)
    : super(const AsyncValue.loading()) {
    loadConfigurations();
  }

  /// Loads all sync configurations
  Future<void> loadConfigurations() async {
    try {
      state = const AsyncValue.loading();
      final configs = await _databaseService.getSyncConfigurations();
      state = AsyncValue.data(configs);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Creates a new sync configuration
  Future<SyncConfig> createConfiguration({
    required String serverUrl,
    required String username,
    required String displayName,
    String? password,
    SyncFrequency syncFrequency = SyncFrequency.manual,
    bool syncOnWifiOnly = true,
    bool syncAttachments = true,
    bool encryptData = false,
    List<String> syncedJournalIds = const [],
  }) async {
    try {
      // Ensure URL is properly formatted
      final formattedUrl = _normalizeServerUrl(serverUrl);

      final config = SyncConfig(
        id: _uuid.v4(),
        serverUrl: formattedUrl,
        username: username,
        displayName: displayName,
        enabled: true,
        lastSyncAt: DateTime.now(),
        syncFrequency: syncFrequency,
        syncOnWifiOnly: syncOnWifiOnly,
        syncAttachments: syncAttachments,
        encryptData: encryptData,
        syncedJournalIds: syncedJournalIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _databaseService.createSyncConfiguration(config);

      // Store password securely if provided
      if (password != null) {
        await _databaseService.storeSyncPassword(config.id, password);
      }

      await loadConfigurations();
      return config;
    } catch (error) {
      rethrow;
    }
  }

  /// Updates an existing sync configuration
  Future<void> updateConfiguration(SyncConfig updatedConfig) async {
    try {
      final configWithUpdatedTime = updatedConfig.copyWith(
        updatedAt: DateTime.now(),
      );

      await _databaseService.updateSyncConfiguration(configWithUpdatedTime);
      await loadConfigurations();
    } catch (error) {
      rethrow;
    }
  }

  /// Deletes a sync configuration
  Future<void> deleteConfiguration(String configId) async {
    try {
      await _databaseService.deleteSyncConfiguration(configId);
      await _databaseService.deleteSyncPassword(configId);
      await loadConfigurations();
    } catch (error) {
      rethrow;
    }
  }

  /// Updates the last sync time for a configuration
  Future<void> updateLastSyncTime(String configId) async {
    try {
      final configs = state.value ?? [];
      final configIndex = configs.indexWhere((c) => c.id == configId);

      if (configIndex != -1) {
        final updatedConfig = configs[configIndex].copyWith(
          lastSyncAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _databaseService.updateSyncConfiguration(updatedConfig);
        await loadConfigurations();
      }
    } catch (error) {
      rethrow;
    }
  }

  /// Enables or disables a sync configuration
  Future<void> toggleConfiguration(String configId, bool enabled) async {
    try {
      final configs = state.value ?? [];
      final configIndex = configs.indexWhere((c) => c.id == configId);

      if (configIndex != -1) {
        final updatedConfig = configs[configIndex].copyWith(
          enabled: enabled,
          updatedAt: DateTime.now(),
        );

        await _databaseService.updateSyncConfiguration(updatedConfig);
        await loadConfigurations();
      }
    } catch (error) {
      rethrow;
    }
  }

  /// Updates which journals are synced for a configuration
  Future<void> updateSyncedJournals(
    String configId,
    List<String> journalIds,
  ) async {
    try {
      final configs = state.value ?? [];
      final configIndex = configs.indexWhere((c) => c.id == configId);

      if (configIndex != -1) {
        final updatedConfig = configs[configIndex].copyWith(
          syncedJournalIds: journalIds,
          updatedAt: DateTime.now(),
        );

        await _databaseService.updateSyncConfiguration(updatedConfig);

        // Clear the local manifest to force regeneration with new journal config
        final syncService = WebDAVSyncService();
        await syncService.clearLocalManifest();

        await loadConfigurations();
      }
    } catch (error) {
      rethrow;
    }
  }

  /// Gets a sync configuration by ID
  SyncConfig? getConfiguration(String configId) {
    final configs = state.value ?? [];
    try {
      return configs.firstWhere((c) => c.id == configId);
    } catch (e) {
      return null;
    }
  }

  /// Gets all enabled sync configurations
  List<SyncConfig> getEnabledConfigurations() {
    final configs = state.value ?? [];
    return configs.where((c) => c.enabled).toList();
  }

  /// Validates sync configuration settings
  String? validateConfiguration({
    required String serverUrl,
    required String username,
    required String displayName,
  }) {
    if (displayName.trim().isEmpty) {
      return 'Display name cannot be empty';
    }

    if (username.trim().isEmpty) {
      return 'Username cannot be empty';
    }

    if (serverUrl.trim().isEmpty) {
      return 'Server URL cannot be empty';
    }

    // Basic URL validation
    try {
      final uri = Uri.parse(_normalizeServerUrl(serverUrl));
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return 'Invalid URL format. Must start with http:// or https://';
      }
    } catch (e) {
      return 'Invalid URL format';
    }

    // Check for duplicate display names
    final configs = state.value ?? [];
    if (configs.any(
      (c) => c.displayName.toLowerCase() == displayName.toLowerCase(),
    )) {
      return 'A configuration with this display name already exists';
    }

    return null;
  }

  /// Normalizes server URL format
  String _normalizeServerUrl(String url) {
    var normalized = url.trim();

    // Add https:// if no scheme provided
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    // Remove trailing slash
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }
}

/// Provider for getting the stored password for a sync configuration
final syncPasswordProvider = FutureProvider.family<String?, String>((
  ref,
  configId,
) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getSyncPassword(configId);
});

/// Provider for checking if a sync configuration has a stored password
final hasSyncPasswordProvider = FutureProvider.family<bool, String>((
  ref,
  configId,
) async {
  final password = await ref.watch(syncPasswordProvider(configId).future);
  return password != null && password.isNotEmpty;
});
