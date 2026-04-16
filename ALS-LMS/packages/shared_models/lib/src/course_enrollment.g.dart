// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_enrollment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseEnrollment _$CourseEnrollmentFromJson(Map<String, dynamic> json) =>
    CourseEnrollment(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      enrolledVia: json['enrolled_via'] == null
          ? EnrollmentMethod.pin
          : EnrollmentMethod.fromJson(json['enrolled_via'] as String),
      status: json['status'] == null
          ? EnrollmentStatus.active
          : EnrollmentStatus.fromJson(json['status'] as String),
      enrolledAt: json['enrolled_at'] == null
          ? null
          : DateTime.parse(json['enrolled_at'] as String),
      courseTitle: json['course_title'] as String?,
      courseDescription: json['course_description'] as String?,
      course: json['course'] == null
          ? null
          : Course.fromJson(json['course'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CourseEnrollmentToJson(CourseEnrollment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'course_id': instance.courseId,
      'enrolled_via': CourseEnrollment._methodToJson(instance.enrolledVia),
      'status': CourseEnrollment._statusToJson(instance.status),
      'enrolled_at': instance.enrolledAt?.toIso8601String(),
      'course_title': ?instance.courseTitle,
      'course_description': ?instance.courseDescription,
    };
