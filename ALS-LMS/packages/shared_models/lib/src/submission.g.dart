// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'submission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Submission _$SubmissionFromJson(Map<String, dynamic> json) => Submission(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      lessonId: json['lesson_id'] as String?,
      quizId: json['quiz_id'] as String?,
      status: json['status'] == null
          ? SubmissionStatus.draft
          : SubmissionStatus.fromJson(json['status'] as String),
      contentJson: json['content_json'] as Map<String, dynamic>?,
      storageUrls: (json['storage_urls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      grade: (json['grade'] as num?)?.toDouble(),
      gradedBy: json['graded_by'] as String?,
      gradedAt: json['graded_at'] == null
          ? null
          : DateTime.parse(json['graded_at'] as String),
      syncedAt: json['synced_at'] == null
          ? null
          : DateTime.parse(json['synced_at'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SubmissionToJson(Submission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'lesson_id': instance.lessonId,
      'quiz_id': instance.quizId,
      'status': Submission._statusToJson(instance.status),
      'content_json': instance.contentJson,
      'storage_urls': instance.storageUrls,
      'grade': instance.grade,
      'graded_by': instance.gradedBy,
      'graded_at': instance.gradedAt?.toIso8601String(),
      'synced_at': instance.syncedAt?.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
    };
