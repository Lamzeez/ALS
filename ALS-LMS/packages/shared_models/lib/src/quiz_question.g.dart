// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quiz_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuizQuestion _$QuizQuestionFromJson(Map<String, dynamic> json) => QuizQuestion(
      id: json['id'] as String,
      quizId: json['quiz_id'] as String,
      questionType: json['question_type'] == null
          ? QuestionType.multipleChoice
          : QuestionType.fromJson(json['question_type'] as String),
      questionJson: json['question_json'] as Map<String, dynamic>,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toDouble() ?? 1.0,
    );

Map<String, dynamic> _$QuizQuestionToJson(QuizQuestion instance) =>
    <String, dynamic>{
      'id': instance.id,
      'quiz_id': instance.quizId,
      'question_type': QuizQuestion._typeToJson(instance.questionType),
      'question_json': instance.questionJson,
      'order_index': instance.orderIndex,
      'points': instance.points,
    };
