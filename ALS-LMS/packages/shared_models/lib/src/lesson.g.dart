// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Lesson _$LessonFromJson(Map<String, dynamic> json) => Lesson(
      id: json['id'] as String,
      moduleId: json['module_id'] as String,
      title: json['title'] as String,
      contentJson: json['content_json'] as Map<String, dynamic>?,
      contentType: json['content_type'] == null
          ? LessonContentType.text
          : LessonContentType.fromJson(json['content_type'] as String),
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      isPublished: json['is_published'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$LessonToJson(Lesson instance) => <String, dynamic>{
      'id': instance.id,
      'module_id': instance.moduleId,
      'title': instance.title,
      'content_json': instance.contentJson,
      'content_type': Lesson._typeToJson(instance.contentType),
      'order_index': instance.orderIndex,
      'duration_minutes': instance.durationMinutes,
      'is_published': instance.isPublished,
      'created_at': instance.createdAt?.toIso8601String(),
    };
