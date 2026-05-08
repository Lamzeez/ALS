// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Course _$CourseFromJson(Map<String, dynamic> json) => Course(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  subjectId: json['subject_id'] as String?,
  teacherId: json['teacher_id'] as String?,
  alsCenterId: json['als_center_id'] as String?,
  strand: json['strand'] == null
      ? AlsStrand.communicationSkills
      : AlsStrand.fromJson(json['strand'] as String),
  coursePin: json['course_pin'] as String?,
  qrCodeUrl: json['qr_code_url'] as String?,
  startDate: json['start_date'] == null
      ? null
      : DateTime.parse(json['start_date'] as String),
  endDate: json['end_date'] == null
      ? null
      : DateTime.parse(json['end_date'] as String),
  isActive: json['is_active'] as bool? ?? true,
  isPublished: json['is_published'] as bool? ?? false,
  syncStatus: json['sync_status'] as String? ?? 'synced',
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
  'subject_id': instance.subjectId,
  'teacher_id': instance.teacherId,
  'als_center_id': instance.alsCenterId,
  'strand': Course._strandToJson(instance.strand),
  'course_pin': instance.coursePin,
  'qr_code_url': instance.qrCodeUrl,
  'start_date': instance.startDate?.toIso8601String(),
  'end_date': instance.endDate?.toIso8601String(),
  'is_active': instance.isActive,
  'is_published': instance.isPublished,
  'sync_status': instance.syncStatus,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
