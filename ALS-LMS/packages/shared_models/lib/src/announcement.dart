import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'course.dart';

part 'announcement.g.dart';

@JsonSerializable()
class Announcement extends Equatable {
  final String id;
  @JsonKey(name: 'course_id')
  final String courseId;
  @JsonKey(name: 'teacher_id')
  final String teacherId;
  final String title;
  final String content;
  @JsonKey(name: 'allow_comments')
  final bool allowComments;
  @JsonKey(name: 'is_pinned')
  final bool isPinned;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  // Joined fields (optional, from queries)
  @JsonKey(name: 'teacher_name', includeIfNull: false)
  final String? teacherName;
  @JsonKey(name: 'comment_count', includeIfNull: false)
  final int? commentCount;
  @JsonKey(includeFromJson: true, includeToJson: false)
  final Course? course;

  const Announcement({
    required this.id,
    required this.courseId,
    required this.teacherId,
    required this.title,
    required this.content,
    this.allowComments = true,
    this.isPinned = false,
    this.createdAt,
    this.updatedAt,
    this.teacherName,
    this.commentCount,
    this.course,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      teacherId: json['teacher_id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      allowComments: json['allow_comments'] as bool? ?? true,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      teacherName: json['teacher_name'] as String?,
      commentCount: json['comment_count'] as int?,
      course: json['courses'] != null ? Course.fromJson(json['courses'] as Map<String, dynamic>) : null,
    );
  }
  Map<String, dynamic> toJson() => _$AnnouncementToJson(this);

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS announcements (
      id TEXT PRIMARY KEY,
      course_id TEXT NOT NULL,
      teacher_id TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      allow_comments INTEGER NOT NULL DEFAULT 1,
      is_pinned INTEGER NOT NULL DEFAULT 0,
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'course_id': courseId,
        'teacher_id': teacherId,
        'title': title,
        'content': content,
        'allow_comments': allowComments ? 1 : 0,
        'is_pinned': isPinned ? 1 : 0,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Announcement.fromSqlite(Map<String, dynamic> map) => Announcement(
        id: map['id'] as String,
        courseId: map['course_id'] as String,
        teacherId: map['teacher_id'] as String,
        title: map['title'] as String,
        content: map['content'] as String,
        allowComments: (map['allow_comments'] as int?) == 1,
        isPinned: (map['is_pinned'] as int?) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, courseId, teacherId, title];
}
