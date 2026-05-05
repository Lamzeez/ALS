// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'module_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModuleProgress _$ModuleProgressFromJson(Map<String, dynamic> json) =>
    ModuleProgress(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      moduleId: json['module_id'] as String,
      courseId: json['course_id'] as String,
      status: json['status'] == null
          ? ProgressStatus.locked
          : ProgressStatus.fromJson(json['status'] as String),
      masteryScore: (json['mastery_score'] as num?)?.toDouble() ?? 0.0,
      lessonsViewed: (json['lessons_viewed'] as num?)?.toInt() ?? 0,
      totalLessons: (json['total_lessons'] as num?)?.toInt() ?? 0,
      timeSpentMins: (json['time_spent_mins'] as num?)?.toInt() ?? 0,
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      syncedAt: json['synced_at'] == null
          ? null
          : DateTime.parse(json['synced_at'] as String),
    );

Map<String, dynamic> _$ModuleProgressToJson(ModuleProgress instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'module_id': instance.moduleId,
      'course_id': instance.courseId,
      'status': ModuleProgress._statusToJson(instance.status),
      'mastery_score': instance.masteryScore,
      'lessons_viewed': instance.lessonsViewed,
      'total_lessons': instance.totalLessons,
      'time_spent_mins': instance.timeSpentMins,
      'started_at': instance.startedAt?.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'synced_at': instance.syncedAt?.toIso8601String(),
    };
