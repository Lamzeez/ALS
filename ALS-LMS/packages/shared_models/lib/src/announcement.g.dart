// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Announcement _$AnnouncementFromJson(Map<String, dynamic> json) => Announcement(
  id: json['id'] as String,
  courseId: json['course_id'] as String,
  teacherId: json['teacher_id'] as String,
  title: json['title'] as String,
  content: json['content'] as String,
  allowComments: json['allow_comments'] as bool? ?? true,
  isPinned: json['is_pinned'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  teacherName: json['teacher_name'] as String?,
  commentCount: (json['comment_count'] as num?)?.toInt(),
  course: json['course'] == null
      ? null
      : Course.fromJson(json['course'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AnnouncementToJson(Announcement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'course_id': instance.courseId,
      'teacher_id': instance.teacherId,
      'title': instance.title,
      'content': instance.content,
      'allow_comments': instance.allowComments,
      'is_pinned': instance.isPinned,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
      'teacher_name': ?instance.teacherName,
      'comment_count': ?instance.commentCount,
    };
