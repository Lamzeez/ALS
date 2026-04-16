// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Course _$CourseFromJson(Map<String, dynamic> json) => Course(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  strand: AlsStrand.fromJson(json['strand'] as String),
  teacherId: json['teacher_id'] as String?,
  cohortId: json['cohort_id'] as String?,
  blueprintId: json['blueprint_id'] as String?,
  isBlueprint: json['is_blueprint'] as bool? ?? false,
  isPublished: json['is_published'] as bool? ?? false,
  schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
  region: json['region'] as String?,
  centerId: json['center_id'] as String?,
  qrCode: json['qr_code'] as String?,
  pinCode: json['pin_code'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$CourseToJson(Course instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'strand': Course._strandToJson(instance.strand),
  'teacher_id': instance.teacherId,
  'cohort_id': instance.cohortId,
  'blueprint_id': instance.blueprintId,
  'is_blueprint': instance.isBlueprint,
  'is_published': instance.isPublished,
  'schema_version': instance.schemaVersion,
  'region': instance.region,
  'center_id': instance.centerId,
  'qr_code': instance.qrCode,
  'pin_code': instance.pinCode,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
