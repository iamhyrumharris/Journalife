class Journal {
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final List<String> sharedWithUserIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? color;
  final String? icon;

  const Journal({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.sharedWithUserIds,
    required this.createdAt,
    required this.updatedAt,
    this.color,
    this.icon,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerId': ownerId,
      'sharedWithUserIds': sharedWithUserIds.join(','),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'color': color,
      'icon': icon,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'owner_id': ownerId,
      'shared_with_user_ids': sharedWithUserIds.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'color': color,
      'icon': icon,
    };
  }

  factory Journal.fromJson(Map<String, dynamic> json) {
    return Journal(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      ownerId: json['ownerId'] as String,
      sharedWithUserIds:
          (json['sharedWithUserIds'] as String?)
              ?.split(',')
              .where((id) => id.isNotEmpty)
              .toList() ??
          [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      color: json['color'] as String?,
      icon: json['icon'] as String?,
    );
  }

  factory Journal.fromMap(Map<String, dynamic> map) {
    return Journal(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      ownerId: map['owner_id'] as String,
      sharedWithUserIds:
          (map['shared_with_user_ids'] as String?)
              ?.split(',')
              .where((id) => id.isNotEmpty)
              .toList() ??
          [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      color: map['color'] as String?,
      icon: map['icon'] as String?,
    );
  }

  Journal copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    List<String>? sharedWithUserIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? color,
    String? icon,
  }) {
    return Journal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      sharedWithUserIds: sharedWithUserIds ?? this.sharedWithUserIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }

  bool get isShared => sharedWithUserIds.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Journal && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Journal(id: $id, name: $name, ownerId: $ownerId)';
  }
}
