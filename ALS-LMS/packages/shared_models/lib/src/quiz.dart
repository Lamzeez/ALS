import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'quiz.g.dart';

@JsonSerializable()
class Quiz extends Equatable {
  final String id;
  @JsonKey(name: 'lesson_id')
  final String? lessonId;
  @JsonKey(name: 'module_id')
  final String? moduleId;
  final String title;
  final String? description;
  @JsonKey(name: 'passing_score')
  final double passingScore;
  @JsonKey(name: 'time_limit_mins')
  final int? timeLimitMins;
  @JsonKey(name: 'max_attempts')
  final int maxAttempts;
  @JsonKey(name: 'shuffle_questions')
  final bool shuffleQuestions;
  @JsonKey(name: 'is_published')
  final bool isPublished;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const Quiz({
    required this.id,
    this.lessonId,
    this.moduleId,
    required this.title,
    this.description,
    this.passingScore = 75.0,
    this.timeLimitMins,
    this.maxAttempts = 3,
    this.shuffleQuestions = false,
    this.isPublished = false,
    this.createdAt,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) => _$QuizFromJson(json);
  Map<String, dynamic> toJson() => _$QuizToJson(this);

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS quizzes (
      id TEXT PRIMARY KEY,
      lesson_id TEXT,
      module_id TEXT,
      title TEXT NOT NULL,
      description TEXT,
      passing_score REAL NOT NULL DEFAULT 75.0,
      time_limit_mins INTEGER,
      max_attempts INTEGER DEFAULT 3,
      shuffle_questions INTEGER NOT NULL DEFAULT 0,
      is_published INTEGER NOT NULL DEFAULT 0,
      created_at TEXT,
      FOREIGN KEY (lesson_id) REFERENCES lessons(id),
      FOREIGN KEY (module_id) REFERENCES modules(id)
    )
  ''';

  @override
  List<Object?> get props => [id, title, moduleId, lessonId];
}
