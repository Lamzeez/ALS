// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'certificate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Certificate _$CertificateFromJson(Map<String, dynamic> json) => Certificate(
  id: json['id'] as String,
  enrollmentId: json['enrollment_id'] as String,
  studentId: json['student_id'] as String,
  courseId: json['course_id'] as String,
  issuedAt: json['issued_at'] == null
      ? null
      : DateTime.parse(json['issued_at'] as String),
  certificateUrl: json['certificate_url'] as String?,
);

Map<String, dynamic> _$CertificateToJson(Certificate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'enrollment_id': instance.enrollmentId,
      'student_id': instance.studentId,
      'course_id': instance.courseId,
      'issued_at': instance.issuedAt?.toIso8601String(),
      'certificate_url': instance.certificateUrl,
    };
