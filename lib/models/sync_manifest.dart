import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Manifest for tracking synced items and their versions
class SyncManifest {
  final String configId;
  final DateTime lastUpdated;
  final Map<String, SyncItem> items;
  final int version;

  const SyncManifest({
    required this.configId,
    required this.lastUpdated,
    this.items = const {},
    this.version = 1,
  });

  /// Adds or updates an item in the manifest
  SyncManifest addItem(SyncItem item) {
    final updatedItems = Map<String, SyncItem>.from(items);
    updatedItems[item.id] = item;
    
    return copyWith(
      items: updatedItems,
      lastUpdated: DateTime.now(),
    );
  }

  /// Removes an item from the manifest
  SyncManifest removeItem(String itemId) {
    final updatedItems = Map<String, SyncItem>.from(items);
    updatedItems.remove(itemId);
    
    return copyWith(
      items: updatedItems,
      lastUpdated: DateTime.now(),
    );
  }

  /// Gets an item by ID
  SyncItem? getItem(String itemId) => items[itemId];

  /// Gets all items of a specific type
  List<SyncItem> getItemsByType(SyncItemType type) {
    return items.values.where((item) => item.type == type).toList();
  }

  /// Gets items that need to be synced (modified or new)
  List<SyncItem> getItemsToSync() {
    return items.values
        .where((item) => item.syncStatus == SyncItemStatus.needsSync)
        .toList();
  }

  /// Gets items that have conflicts
  List<SyncItem> getConflictedItems() {
    return items.values
        .where((item) => item.syncStatus == SyncItemStatus.conflict)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'configId': configId,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'items': items.map((key, value) => MapEntry(key, value.toJson())),
      'version': version,
    };
  }

  factory SyncManifest.fromJson(Map<String, dynamic> json) {
    return SyncManifest(
      configId: json['configId'] as String,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(json['lastUpdated'] as int),
      items: (json['items'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, SyncItem.fromJson(value as Map<String, dynamic>)),
      ),
      version: json['version'] as int? ?? 1,
    );
  }

  SyncManifest copyWith({
    String? configId,
    DateTime? lastUpdated,
    Map<String, SyncItem>? items,
    int? version,
  }) {
    return SyncManifest(
      configId: configId ?? this.configId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      items: items ?? this.items,
      version: version ?? this.version,
    );
  }

  @override
  String toString() {
    return 'SyncManifest(configId: $configId, items: ${items.length}, version: $version)';
  }
}

/// Individual item tracked in the sync manifest
class SyncItem {
  final String id;
  final SyncItemType type;
  final String path;
  final DateTime localModified;
  final DateTime? remoteModified;
  final String localHash;
  final String? remoteHash;
  final int size;
  final SyncItemStatus syncStatus;
  final DateTime lastSynced;
  final Map<String, dynamic>? metadata;

  const SyncItem({
    required this.id,
    required this.type,
    required this.path,
    required this.localModified,
    this.remoteModified,
    required this.localHash,
    this.remoteHash,
    this.size = 0,
    this.syncStatus = SyncItemStatus.needsSync,
    required this.lastSynced,
    this.metadata,
  });

  /// Checks if this item needs to be synced
  bool get needsSync {
    // No remote version exists
    if (remoteModified == null || remoteHash == null) {
      return syncStatus == SyncItemStatus.needsSync;
    }

    // Local version is newer
    if (localModified.isAfter(remoteModified!)) {
      return true;
    }

    // Content has changed (different hashes)
    if (localHash != remoteHash) {
      return true;
    }

    return syncStatus == SyncItemStatus.needsSync;
  }

  /// Checks if this item has a conflict
  bool get hasConflict => syncStatus == SyncItemStatus.conflict;

  /// Creates a hash for file content
  static Future<String> createFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Creates a hash for string content
  static String createContentHash(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Creates a SyncItem from a local file
  static Future<SyncItem> fromFile({
    required String id,
    required SyncItemType type,
    required File file,
    Map<String, dynamic>? metadata,
  }) async {
    final stat = await file.stat();
    final hash = await createFileHash(file);
    
    return SyncItem(
      id: id,
      type: type,
      path: file.path,
      localModified: stat.modified,
      localHash: hash,
      size: stat.size,
      lastSynced: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Creates a SyncItem from content (for JSON data)
  static SyncItem fromContent({
    required String id,
    required SyncItemType type,
    required String path,
    required String content,
    required DateTime modified,
    Map<String, dynamic>? metadata,
  }) {
    return SyncItem(
      id: id,
      type: type,
      path: path,
      localModified: modified,
      localHash: createContentHash(content),
      size: utf8.encode(content).length,
      lastSynced: DateTime.now(),
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'path': path,
      'localModified': localModified.millisecondsSinceEpoch,
      'remoteModified': remoteModified?.millisecondsSinceEpoch,
      'localHash': localHash,
      'remoteHash': remoteHash,
      'size': size,
      'syncStatus': syncStatus.name,
      'lastSynced': lastSynced.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory SyncItem.fromJson(Map<String, dynamic> json) {
    return SyncItem(
      id: json['id'] as String,
      type: SyncItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SyncItemType.unknown,
      ),
      path: json['path'] as String,
      localModified: DateTime.fromMillisecondsSinceEpoch(json['localModified'] as int),
      remoteModified: json['remoteModified'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['remoteModified'] as int)
          : null,
      localHash: json['localHash'] as String,
      remoteHash: json['remoteHash'] as String?,
      size: json['size'] as int? ?? 0,
      syncStatus: SyncItemStatus.values.firstWhere(
        (e) => e.name == json['syncStatus'],
        orElse: () => SyncItemStatus.needsSync,
      ),
      lastSynced: DateTime.fromMillisecondsSinceEpoch(json['lastSynced'] as int),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  SyncItem copyWith({
    String? id,
    SyncItemType? type,
    String? path,
    DateTime? localModified,
    DateTime? remoteModified,
    String? localHash,
    String? remoteHash,
    int? size,
    SyncItemStatus? syncStatus,
    DateTime? lastSynced,
    Map<String, dynamic>? metadata,
  }) {
    return SyncItem(
      id: id ?? this.id,
      type: type ?? this.type,
      path: path ?? this.path,
      localModified: localModified ?? this.localModified,
      remoteModified: remoteModified ?? this.remoteModified,
      localHash: localHash ?? this.localHash,
      remoteHash: remoteHash ?? this.remoteHash,
      size: size ?? this.size,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSynced: lastSynced ?? this.lastSynced,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'SyncItem(id: $id, type: $type, status: $syncStatus, needsSync: $needsSync)';
  }
}

/// Types of items that can be synced
enum SyncItemType {
  journal,
  entry,
  attachment,
  manifest,
  unknown,
}

/// Status of sync for an individual item
enum SyncItemStatus {
  synced,
  needsSync,
  syncing,
  conflict,
  error,
}

extension SyncItemTypeExtension on SyncItemType {
  String get displayName {
    switch (this) {
      case SyncItemType.journal:
        return 'Journal';
      case SyncItemType.entry:
        return 'Entry';
      case SyncItemType.attachment:
        return 'Attachment';
      case SyncItemType.manifest:
        return 'Manifest';
      case SyncItemType.unknown:
        return 'Unknown';
    }
  }
}

extension SyncItemStatusExtension on SyncItemStatus {
  String get displayName {
    switch (this) {
      case SyncItemStatus.synced:
        return 'Synced';
      case SyncItemStatus.needsSync:
        return 'Needs Sync';
      case SyncItemStatus.syncing:
        return 'Syncing';
      case SyncItemStatus.conflict:
        return 'Conflict';
      case SyncItemStatus.error:
        return 'Error';
    }
  }
}