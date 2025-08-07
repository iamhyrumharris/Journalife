enum AttachmentType { photo, audio, file, location }

class Attachment {
  final String id;
  final String entryId;
  final AttachmentType type;
  final String name;
  final String path;
  final int? size;
  final String? mimeType;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  const Attachment({
    required this.id,
    required this.entryId,
    required this.type,
    required this.name,
    required this.path,
    this.size,
    this.mimeType,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entryId': entryId,
      'type': type.name,
      'name': name,
      'path': path,
      'size': size,
      'mimeType': mimeType,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entry_id': entryId,
      'type': type.name,
      'name': name,
      'path': path,
      'size': size,
      'mime_type': mimeType,
      'created_at': createdAt.millisecondsSinceEpoch,
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
    };
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      entryId: json['entryId'] as String,
      type: AttachmentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AttachmentType.file,
      ),
      name: json['name'] as String,
      path: json['path'] as String,
      size: json['size'] as int?,
      mimeType: json['mimeType'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: json['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
          : null,
      metadata: json['metadata'] != null
          ? _decodeMetadata(json['metadata'] as String)
          : null,
    );
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      id: map['id'] as String,
      entryId: map['entry_id'] as String,
      type: AttachmentType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AttachmentType.file,
      ),
      name: map['name'] as String,
      path: map['path'] as String,
      size: map['size'] as int?,
      mimeType: map['mime_type'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt:
          null, // Database doesn't have updated_at column for attachments
      metadata: map['metadata'] != null
          ? _decodeMetadata(map['metadata'] as String)
          : null,
    );
  }

  static String _encodeMetadata(Map<String, dynamic> metadata) {
    // Simple JSON encoding for SQLite storage
    return metadata.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  static Map<String, dynamic> _decodeMetadata(String encoded) {
    final Map<String, dynamic> result = {};
    if (encoded.isEmpty) return result;

    for (final pair in encoded.split('|')) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        result[parts[0]] = parts[1];
      }
    }
    return result;
  }

  Attachment copyWith({
    String? id,
    String? entryId,
    AttachmentType? type,
    String? name,
    String? path,
    int? size,
    String? mimeType,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Attachment(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      type: type ?? this.type,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Attachment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Attachment(id: $id, type: $type, name: $name)';
  }
}
