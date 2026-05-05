// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Score _$ScoreFromJson(Map<String, dynamic> json) => Score(
  id: json['id'] as String,
  studentId: json['student_id'] as String,
  quizId: json['quiz_id'] as String,
  score: (json['score'] as num).toDouble(),
  maxScore: (json['max_score'] as num).toDouble(),
  percentage: (json['percentage'] as num?)?.toDouble(),
  attemptNum: (json['attempt_num'] as num?)?.toInt() ?? 1,
  answersJson: json['answers_json'] as Map<String, dynamic>?,
  timeTakenSecs: (json['time_taken_secs'] as num?)?.toInt(),
  isPassing: json['is_passing'] as bool?,
  syncedAt: json['synced_at'] == null
      ? null
      : DateTime.parse(json['synced_at'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ScoreToJson(Score instance) => <String, dynamic>{
  'id': instance.id,
  'student_id': instance.studentId,
  'quiz_id': instance.quizId,
  'score': instance.score,
  'max_score': instance.maxScore,
  'percentage': instance.percentage,
  'attempt_num': instance.attemptNum,
  'answers_json': instance.answersJson,
  'time_taken_secs': instance.timeTakenSecs,
  'is_passing': instance.isPassing,
  'synced_at': instance.syncedAt?.toIso8601String(),
  'created_at': instance.createdAt?.toIso8601String(),
};
