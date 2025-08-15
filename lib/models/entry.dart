import 'attachment.dart';

class Entry {
  final String id;
  final String journalId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final List<Attachment> attachments;

  const Entry({
    required this.id,
    required this.journalId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    this.latitude,
    this.longitude,
    this.locationName,
    required this.attachments,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journalId': journalId,
      'title': title,
      'content': content,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'tags': tags.join(','),
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'journal_id': journalId,
      'title': title,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'tags': tags.join(','),
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
    };
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    List<Attachment>? attachments,
  }) {
    return Entry(
      id: json['id'] as String,
      journalId: json['journalId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      tags:
          (json['tags'] as String?)
              ?.split(',')
              .where((tag) => tag.isNotEmpty)
              .toList() ??
          [],
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      locationName: json['locationName'] as String?,
      attachments: attachments ?? [],
    );
  }

  factory Entry.fromMap(
    Map<String, dynamic> map, {
    List<Attachment>? attachments,
  }) {
    return Entry(
      id: map['id'] as String,
      journalId: map['journal_id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      tags:
          (map['tags'] as String?)
              ?.split(',')
              .where((tag) => tag.isNotEmpty)
              .toList() ??
          [],
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      locationName: map['location_name'] as String?,
      attachments: attachments ?? [],
    );
  }

  Entry copyWith({
    String? id,
    String? journalId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    double? latitude,
    double? longitude,
    String? locationName,
    List<Attachment>? attachments,
  }) {
    return Entry(
      id: id ?? this.id,
      journalId: journalId ?? this.journalId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      attachments: attachments ?? this.attachments,
    );
  }

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasTags => tags.isNotEmpty;
  bool get hasAttachments => attachments.isNotEmpty;

  List<Attachment> get photoAttachments =>
      attachments.where((a) => a.type == AttachmentType.photo).toList();

  List<Attachment> get audioAttachments =>
      attachments.where((a) => a.type == AttachmentType.audio).toList();

  List<Attachment> get fileAttachments =>
      attachments.where((a) => a.type == AttachmentType.file).toList();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Entry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Entry(id: $id, title: $title, journalId: $journalId)';
  }
}
