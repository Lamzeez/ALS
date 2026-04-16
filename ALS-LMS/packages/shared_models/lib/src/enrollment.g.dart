// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enrollment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Enrollment _$EnrollmentFromJson(Map<String, dynamic> json) => Enrollment(
  id: json['id'] as String,
  studentId: json['student_id'] as String,
  cohortId: json['cohort_id'] as String,
  enrolledAt: json['enrolled_at'] == null
      ? null
      : DateTime.parse(json['enrolled_at'] as String),
  status: json['status'] == null
      ? EnrollmentStatus.active
      : EnrollmentStatus.fromJson(json['status'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$EnrollmentToJson(Enrollment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'cohort_id': instance.cohortId,
      'enrolled_at': instance.enrolledAt?.toIso8601String(),
      'status': Enrollment._statusToJson(instance.status),
      'created_at': instance.createdAt?.toIso8601String(),
    };
