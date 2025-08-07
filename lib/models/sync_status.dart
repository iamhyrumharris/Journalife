
/// Represents the current sync status and progress
class SyncStatus {
  final String configId;
  final SyncState state;
  final DateTime lastAttemptAt;
  final DateTime? lastSuccessAt;
  final int totalItems;
  final int completedItems;
  final int failedItems;
  final String? currentItem;
  final String? errorMessage;
  final List<SyncError> errors;
  final Duration? estimatedTimeRemaining;
  final int bytesTransferred;
  final int totalBytes;

  const SyncStatus({
    required this.configId,
    this.state = SyncState.idle,
    required this.lastAttemptAt,
    this.lastSuccessAt,
    this.totalItems = 0,
    this.completedItems = 0,
    this.failedItems = 0,
    this.currentItem,
    this.errorMessage,
    this.errors = const [],
    this.estimatedTimeRemaining,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
  });

  /// Progress as a percentage (0.0 to 1.0)
  double get progress {
    if (totalItems == 0) return 0.0;
    return completedItems / totalItems;
  }

  /// Progress as a percentage for file transfers (0.0 to 1.0)
  double get bytesProgress {
    if (totalBytes == 0) return 0.0;
    return bytesTransferred / totalBytes;
  }

  /// Whether sync is currently active
  bool get isActive {
    return state == SyncState.syncing || 
           state == SyncState.uploading || 
           state == SyncState.downloading;
  }

  /// Whether the last sync was successful
  bool get hasErrors => errors.isNotEmpty || errorMessage != null;

  /// Human-readable status message
  String get statusMessage {
    switch (state) {
      case SyncState.idle:
        return lastSuccessAt != null 
            ? 'Last synced ${_formatTime(lastSuccessAt!)}'
            : 'Ready to sync';
      case SyncState.syncing:
        return currentItem != null 
            ? 'Syncing $currentItem...'
            : 'Syncing...';
      case SyncState.uploading:
        return currentItem != null
            ? 'Uploading $currentItem...'
            : 'Uploading...';
      case SyncState.downloading:
        return currentItem != null
            ? 'Downloading $currentItem...'
            : 'Downloading...';
      case SyncState.checking:
        return 'Checking for changes...';
      case SyncState.resolving:
        return 'Resolving conflicts...';
      case SyncState.completed:
        return 'Sync completed successfully';
      case SyncState.failed:
        return errorMessage ?? 'Sync failed';
      case SyncState.cancelled:
        return 'Sync cancelled';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'configId': configId,
      'state': state.name,
      'lastAttemptAt': lastAttemptAt.millisecondsSinceEpoch,
      'lastSuccessAt': lastSuccessAt?.millisecondsSinceEpoch,
      'totalItems': totalItems,
      'completedItems': completedItems,
      'failedItems': failedItems,
      'currentItem': currentItem,
      'errorMessage': errorMessage,
      'errors': errors.map((e) => e.toJson()).toList(),
      'estimatedTimeRemaining': estimatedTimeRemaining?.inMilliseconds,
      'bytesTransferred': bytesTransferred,
      'totalBytes': totalBytes,
    };
  }

  factory SyncStatus.fromJson(Map<String, dynamic> json) {
    return SyncStatus(
      configId: json['configId'] as String,
      state: SyncState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => SyncState.idle,
      ),
      lastAttemptAt: DateTime.fromMillisecondsSinceEpoch(json['lastAttemptAt'] as int),
      lastSuccessAt: json['lastSuccessAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastSuccessAt'] as int)
          : null,
      totalItems: json['totalItems'] as int? ?? 0,
      completedItems: json['completedItems'] as int? ?? 0,
      failedItems: json['failedItems'] as int? ?? 0,
      currentItem: json['currentItem'] as String?,
      errorMessage: json['errorMessage'] as String?,
      errors: (json['errors'] as List<dynamic>?)
          ?.map((e) => SyncError.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      estimatedTimeRemaining: json['estimatedTimeRemaining'] != null
          ? Duration(milliseconds: json['estimatedTimeRemaining'] as int)
          : null,
      bytesTransferred: json['bytesTransferred'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
    );
  }

  SyncStatus copyWith({
    String? configId,
    SyncState? state,
    DateTime? lastAttemptAt,
    DateTime? lastSuccessAt,
    int? totalItems,
    int? completedItems,
    int? failedItems,
    String? currentItem,
    String? errorMessage,
    List<SyncError>? errors,
    Duration? estimatedTimeRemaining,
    int? bytesTransferred,
    int? totalBytes,
  }) {
    return SyncStatus(
      configId: configId ?? this.configId,
      state: state ?? this.state,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      totalItems: totalItems ?? this.totalItems,
      completedItems: completedItems ?? this.completedItems,
      failedItems: failedItems ?? this.failedItems,
      currentItem: currentItem,
      errorMessage: errorMessage,
      errors: errors ?? this.errors,
      estimatedTimeRemaining: estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }

  @override
  String toString() {
    return 'SyncStatus(configId: $configId, state: $state, progress: ${(progress * 100).toStringAsFixed(1)}%)';
  }
}

/// Specific sync error information
class SyncError {
  final DateTime timestamp;
  final SyncErrorType type;
  final String message;
  final String? itemId;
  final String? itemType;
  final Map<String, dynamic>? metadata;

  const SyncError({
    required this.timestamp,
    required this.type,
    required this.message,
    this.itemId,
    this.itemType,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'type': type.name,
      'message': message,
      'itemId': itemId,
      'itemType': itemType,
      'metadata': metadata,
    };
  }

  factory SyncError.fromJson(Map<String, dynamic> json) {
    return SyncError(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      type: SyncErrorType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SyncErrorType.unknown,
      ),
      message: json['message'] as String,
      itemId: json['itemId'] as String?,
      itemType: json['itemType'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'SyncError(type: $type, message: $message, item: $itemId)';
  }
}

/// Current state of sync operation
enum SyncState {
  idle,
  checking,
  syncing,
  uploading,
  downloading,
  resolving,
  completed,
  failed,
  cancelled,
}

/// Types of sync errors
enum SyncErrorType {
  networkError,
  authenticationError,
  serverError,
  conflictError,
  fileError,
  validationError,
  quotaExceeded,
  unknown,
}

extension SyncErrorTypeExtension on SyncErrorType {
  String get displayName {
    switch (this) {
      case SyncErrorType.networkError:
        return 'Network Error';
      case SyncErrorType.authenticationError:
        return 'Authentication Error';
      case SyncErrorType.serverError:
        return 'Server Error';
      case SyncErrorType.conflictError:
        return 'Conflict Error';
      case SyncErrorType.fileError:
        return 'File Error';
      case SyncErrorType.validationError:
        return 'Validation Error';
      case SyncErrorType.quotaExceeded:
        return 'Storage Quota Exceeded';
      case SyncErrorType.unknown:
        return 'Unknown Error';
    }
  }

  bool get isRetryable {
    switch (this) {
      case SyncErrorType.networkError:
      case SyncErrorType.serverError:
      case SyncErrorType.fileError:
        return true;
      case SyncErrorType.authenticationError:
      case SyncErrorType.conflictError:
      case SyncErrorType.validationError:
      case SyncErrorType.quotaExceeded:
      case SyncErrorType.unknown:
        return false;
    }
  }
}