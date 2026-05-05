// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_enrollment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseEnrollment _$CourseEnrollmentFromJson(Map<String, dynamic> json) =>
    CourseEnrollment(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      studentId: json['student_id'] as String,
      enrolledAt: json['enrolled_at'] == null
          ? null
          : DateTime.parse(json['enrolled_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );

Map<String, dynamic> _$CourseEnrollmentToJson(CourseEnrollment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'course_id': instance.courseId,
      'student_id': instance.studentId,
      'enrolled_at': instance.enrolledAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'is_active': instance.isActive,
    };
