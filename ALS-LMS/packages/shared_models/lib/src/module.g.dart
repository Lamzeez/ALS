// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'module.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Module _$ModuleFromJson(Map<String, dynamic> json) => Module(
  id: json['id'] as String,
  courseId: json['course_id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  moduleType: json['module_type'] == null
      ? ModuleType.core
      : ModuleType.fromJson(json['module_type'] as String),
  orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
  prerequisiteId: json['prerequisite_id'] as String?,
  passingThreshold: (json['passing_threshold'] as num?)?.toDouble() ?? 75.0,
  estimatedHours: (json['estimated_hours'] as num?)?.toDouble(),
  isPublished: json['is_published'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$ModuleToJson(Module instance) => <String, dynamic>{
  'id': instance.id,
  'course_id': instance.courseId,
  'title': instance.title,
  'description': instance.description,
  'module_type': Module._typeToJson(instance.moduleType),
  'order_index': instance.orderIndex,
  'prerequisite_id': instance.prerequisiteId,
  'passing_threshold': instance.passingThreshold,
  'estimated_hours': instance.estimatedHours,
  'is_published': instance.isPublished,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
