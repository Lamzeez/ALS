// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Lesson _$LessonFromJson(Map<String, dynamic> json) => Lesson(
  id: json['id'] as String,
  courseId: json['course_id'] as String?,
  moduleId: json['module_id'] as String?,
  title: json['title'] as String,
  contentJson: json['content_json'] as Map<String, dynamic>?,
  contentType: json['content_type'] as String? ?? 'text',
  orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$LessonToJson(Lesson instance) => <String, dynamic>{
  'id': instance.id,
  'course_id': instance.courseId,
  'module_id': instance.moduleId,
  'title': instance.title,
  'content_json': instance.contentJson,
  'content_type': instance.contentType,
  'order_index': instance.orderIndex,
  'created_at': instance.createdAt?.toIso8601String(),
};
