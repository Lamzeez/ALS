import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'quiz_question.g.dart';

@JsonSerializable()
class QuizQuestion extends Equatable {
  final String id;
  @JsonKey(name: 'quiz_id')
  final String quizId;
  @JsonKey(name: 'question_type', fromJson: QuestionType.fromJson, toJson: _typeToJson)
  final QuestionType questionType;
  @JsonKey(name: 'question_json')
  final Map<String, dynamic> questionJson;
  @JsonKey(name: 'order_index')
  final int orderIndex;
  final double points;

  const QuizQuestion({
    required this.id,
    required this.quizId,
    this.questionType = QuestionType.multipleChoice,
    required this.questionJson,
    this.orderIndex = 0,
    this.points = 1.0,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) =>
      _$QuizQuestionFromJson(json);
  Map<String, dynamic> toJson() => _$QuizQuestionToJson(this);

  static String _typeToJson(QuestionType t) => t.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS quiz_questions (
      id TEXT PRIMARY KEY,
      quiz_id TEXT NOT NULL,
      question_type TEXT NOT NULL DEFAULT 'multiple_choice',
      question_json TEXT NOT NULL,
      order_index INTEGER NOT NULL DEFAULT 0,
      points REAL NOT NULL DEFAULT 1.0,
      FOREIGN KEY (quiz_id) REFERENCES quizzes(id)
    )
  ''';

  @override
  List<Object?> get props => [id, quizId, questionType, orderIndex];
}
