// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Quiz _$QuizFromJson(Map<String, dynamic> json) => Quiz(
  id: json['id'] as String,
  lessonId: json['lesson_id'] as String?,
  moduleId: json['module_id'] as String?,
  title: json['title'] as String,
  description: json['description'] as String?,
  passingScore: (json['passing_score'] as num?)?.toDouble() ?? 75.0,
  timeLimitMins: (json['time_limit_mins'] as num?)?.toInt(),
  maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 3,
  shuffleQuestions: json['shuffle_questions'] as bool? ?? false,
  isPublished: json['is_published'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$QuizToJson(Quiz instance) => <String, dynamic>{
  'id': instance.id,
  'lesson_id': instance.lessonId,
  'module_id': instance.moduleId,
  'title': instance.title,
  'description': instance.description,
  'passing_score': instance.passingScore,
  'time_limit_mins': instance.timeLimitMins,
  'max_attempts': instance.maxAttempts,
  'shuffle_questions': instance.shuffleQuestions,
  'is_published': instance.isPublished,
  'created_at': instance.createdAt?.toIso8601String(),
};
