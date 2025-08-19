/// Configuration for WebDAV server connection and sync preferences
class SyncConfig {
  final String id;
  final String serverUrl;
  final String username;
  final String displayName; // Human-readable name for this config
  final bool enabled;
  final DateTime lastSyncAt;
  final SyncFrequency syncFrequency;
  final bool syncOnWifiOnly;
  final bool syncAttachments;
  final bool encryptData;
  final List<String> syncedJournalIds; // Which journals to sync
  final DateTime createdAt;
  final DateTime updatedAt;

  const SyncConfig({
    required this.id,
    required this.serverUrl,
    required this.username,
    required this.displayName,
    this.enabled = true,
    required this.lastSyncAt,
    this.syncFrequency = SyncFrequency.manual,
    this.syncOnWifiOnly = true,
    this.syncAttachments = true,
    this.encryptData = false,
    this.syncedJournalIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serverUrl': serverUrl,
      'username': username,
      'displayName': displayName,
      'enabled': enabled,
      'lastSyncAt': lastSyncAt.millisecondsSinceEpoch,
      'syncFrequency': syncFrequency.name,
      'syncOnWifiOnly': syncOnWifiOnly,
      'syncAttachments': syncAttachments,
      'encryptData': encryptData,
      'syncedJournalIds': syncedJournalIds.join(','),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      id: json['id'] as String,
      serverUrl: json['serverUrl'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      enabled: json['enabled'] as bool? ?? true,
      lastSyncAt: DateTime.fromMillisecondsSinceEpoch(
        json['lastSyncAt'] as int,
      ),
      syncFrequency: SyncFrequency.values.firstWhere(
        (e) => e.name == json['syncFrequency'],
        orElse: () => SyncFrequency.manual,
      ),
      syncOnWifiOnly: json['syncOnWifiOnly'] as bool? ?? true,
      syncAttachments: json['syncAttachments'] as bool? ?? true,
      encryptData: json['encryptData'] as bool? ?? false,
      syncedJournalIds:
          (json['syncedJournalIds'] as String?)
              ?.split(',')
              .where((id) => id.isNotEmpty)
              .toList() ??
          [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
    );
  }

  factory SyncConfig.fromMap(Map<String, dynamic> map) {
    return SyncConfig(
      id: map['id'] as String,
      serverUrl: map['server_url'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String,
      enabled: (map['enabled'] as int?) == 1,
      lastSyncAt: DateTime.parse(map['last_sync_at'] as String),
      syncFrequency: SyncFrequency.values.firstWhere(
        (e) => e.name == map['sync_frequency'],
        orElse: () => SyncFrequency.manual,
      ),
      syncOnWifiOnly: (map['sync_on_wifi_only'] as int?) == 1,
      syncAttachments: (map['sync_attachments'] as int?) == 1,
      encryptData: (map['encrypt_data'] as int?) == 1,
      syncedJournalIds:
          (map['synced_journal_ids'] as String?)
              ?.split(',')
              .where((id) => id.isNotEmpty)
              .toList() ??
          [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  SyncConfig copyWith({
    String? id,
    String? serverUrl,
    String? username,
    String? displayName,
    bool? enabled,
    DateTime? lastSyncAt,
    SyncFrequency? syncFrequency,
    bool? syncOnWifiOnly,
    bool? syncAttachments,
    bool? encryptData,
    List<String>? syncedJournalIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SyncConfig(
      id: id ?? this.id,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      syncFrequency: syncFrequency ?? this.syncFrequency,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
      syncAttachments: syncAttachments ?? this.syncAttachments,
      encryptData: encryptData ?? this.encryptData,
      syncedJournalIds: syncedJournalIds ?? this.syncedJournalIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Gets the base WebDAV path for journal data
  String get basePath => '/journal_app';

  /// Gets the WebDAV path for a specific journal with date-based organization
  String getJournalPath(String journalId) => '$basePath/journals/$journalId';

  /// Gets the WebDAV path for journal entries organized by date
  String getJournalEntriesPath(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    return '$basePath/entries/$year/$month/entries.json';
  }

  /// Gets the WebDAV path for journal metadata
  String get journalMetadataPath => '$basePath/journals_metadata.json';

  /// Gets the WebDAV path for attachments with date-based organization
  String getAttachmentPath(String relativePath) =>
      '$basePath/attachments/$relativePath';
      
  /// Gets the organized WebDAV path for entry attachments by date
  String getEntryAttachmentPath(String entryId, DateTime entryDate, String filename) {
    final year = entryDate.year.toString();
    final month = entryDate.month.toString().padLeft(2, '0');
    final day = entryDate.day.toString().padLeft(2, '0');
    return '$basePath/attachments/$year/$month/$day/$entryId/$filename';
  }

  /// Gets the WebDAV directory path for all entry attachments by date
  String getEntryAttachmentDir(String entryId, DateTime entryDate) {
    final year = entryDate.year.toString();
    final month = entryDate.month.toString().padLeft(2, '0');
    final day = entryDate.day.toString().padLeft(2, '0');
    return '$basePath/attachments/$year/$month/$day/$entryId';
  }

  /// Gets the WebDAV path for photos organized by date
  String getPhotoPath(String entryId, DateTime entryDate, String filename) {
    final year = entryDate.year.toString();
    final month = entryDate.month.toString().padLeft(2, '0');
    final day = entryDate.day.toString().padLeft(2, '0');
    return '$basePath/photos/$year/$month/$day/$entryId/$filename';
  }

  /// Gets the WebDAV path for audio attachments organized by date
  String getAudioPath(String entryId, DateTime entryDate, String filename) {
    final year = entryDate.year.toString();
    final month = entryDate.month.toString().padLeft(2, '0');
    final day = entryDate.day.toString().padLeft(2, '0');
    return '$basePath/audio/$year/$month/$day/$entryId/$filename';
  }

  /// Gets all required directory paths for proper WebDAV structure
  List<String> getRequiredDirectories() {
    return [
      basePath,
      '$basePath/journals',
      '$basePath/entries',
      '$basePath/attachments',
      '$basePath/photos',
      '$basePath/audio',
      '$basePath/temp',
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SyncConfig(id: $id, displayName: $displayName, serverUrl: $serverUrl, enabled: $enabled)';
  }
}

/// How frequently to perform automatic sync
enum SyncFrequency { manual, onAppStart, hourly, daily, weekly }

extension SyncFrequencyExtension on SyncFrequency {
  String get displayName {
    switch (this) {
      case SyncFrequency.manual:
        return 'Manual Only';
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

  Duration? get duration {
    switch (this) {
      case SyncFrequency.manual:
      case SyncFrequency.onAppStart:
        return null;
      case SyncFrequency.hourly:
        return const Duration(hours: 1);
      case SyncFrequency.daily:
        return const Duration(days: 1);
      case SyncFrequency.weekly:
        return const Duration(days: 7);
    }
  }
}
