import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'announcement_comment.g.dart';

@JsonSerializable()
class AnnouncementComment extends Equatable {
  final String id;
  @JsonKey(name: 'announcement_id')
  final String announcementId;
  @JsonKey(name: 'user_id')
  final String userId;
  final String content;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  // Joined fields (optional)
  @JsonKey(name: 'user_name', includeIfNull: false)
  final String? userName;
  @JsonKey(name: 'user_avatar', includeIfNull: false)
  final String? userAvatar;

  const AnnouncementComment({
    required this.id,
    required this.announcementId,
    required this.userId,
    required this.content,
    this.createdAt,
    this.userName,
    this.userAvatar,
  });

  factory AnnouncementComment.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementCommentFromJson(json);
  Map<String, dynamic> toJson() => _$AnnouncementCommentToJson(this);

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS announcement_comments (
      id TEXT PRIMARY KEY,
      announcement_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'announcement_id': announcementId,
        'user_id': userId,
        'content': content,
        'created_at': createdAt?.toIso8601String(),
      };

  factory AnnouncementComment.fromSqlite(Map<String, dynamic> map) =>
      AnnouncementComment(
        id: map['id'] as String,
        announcementId: map['announcement_id'] as String,
        userId: map['user_id'] as String,
        content: map['content'] as String,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, announcementId, userId];
}
