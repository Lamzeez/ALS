// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_timeline.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseTimeline _$CourseTimelineFromJson(Map<String, dynamic> json) =>
    CourseTimeline(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      lessonId: json['lesson_id'] as String?,
      startDate: json['start_date'] == null
          ? null
          : DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$CourseTimelineToJson(CourseTimeline instance) =>
    <String, dynamic>{
      'id': instance.id,
      'course_id': instance.courseId,
      'title': instance.title,
      'description': instance.description,
      'lesson_id': instance.lessonId,
      'start_date': instance.startDate?.toIso8601String(),
      'end_date': instance.endDate?.toIso8601String(),
      'order_index': instance.orderIndex,
      'created_at': instance.createdAt?.toIso8601String(),
    };
