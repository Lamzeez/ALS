// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Attendance _$AttendanceFromJson(Map<String, dynamic> json) => Attendance(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      teacherId: json['teacher_id'] as String,
      cohortId: json['cohort_id'] as String,
      date: json['date'] as String,
      status: json['status'] == null
          ? AttendanceStatus.present
          : AttendanceStatus.fromJson(json['status'] as String),
      notes: json['notes'] as String?,
      syncedAt: json['synced_at'] == null
          ? null
          : DateTime.parse(json['synced_at'] as String),
    );

Map<String, dynamic> _$AttendanceToJson(Attendance instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'teacher_id': instance.teacherId,
      'cohort_id': instance.cohortId,
      'date': instance.date,
      'status': Attendance._statusToJson(instance.status),
      'notes': instance.notes,
      'synced_at': instance.syncedAt?.toIso8601String(),
    };
