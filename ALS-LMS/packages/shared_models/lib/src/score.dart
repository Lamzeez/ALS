import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'score.g.dart';

@JsonSerializable()
class Score extends Equatable {
  final String id;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'quiz_id')
  final String quizId;
  final double score;
  @JsonKey(name: 'max_score')
  final double maxScore;
  final double? percentage;
  @JsonKey(name: 'attempt_num')
  final int attemptNum;
  @JsonKey(name: 'answers_json')
  final Map<String, dynamic>? answersJson;
  @JsonKey(name: 'time_taken_secs')
  final int? timeTakenSecs;
  @JsonKey(name: 'is_passing')
  final bool? isPassing;
  @JsonKey(name: 'synced_at')
  final DateTime? syncedAt;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const Score({
    required this.id,
    required this.studentId,
    required this.quizId,
    required this.score,
    required this.maxScore,
    this.percentage,
    this.attemptNum = 1,
    this.answersJson,
    this.timeTakenSecs,
    this.isPassing,
    this.syncedAt,
    this.createdAt,
  });

  factory Score.fromJson(Map<String, dynamic> json) => _$ScoreFromJson(json);
  Map<String, dynamic> toJson() => _$ScoreToJson(this);

  /// Calculate percentage locally (matches Postgres generated column)
  double get calculatedPercentage =>
      maxScore > 0 ? (score / maxScore) * 100 : 0;

  /// Check if passing locally
  bool get calculatedIsPassing => calculatedPercentage >= 75;

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS scores (
      id TEXT PRIMARY KEY,
      student_id TEXT NOT NULL,
      quiz_id TEXT NOT NULL,
      score REAL NOT NULL,
      max_score REAL NOT NULL,
      percentage REAL,
      attempt_num INTEGER NOT NULL DEFAULT 1,
      answers_json TEXT,
      time_taken_secs INTEGER,
      is_passing INTEGER,
      synced_at TEXT,
      created_at TEXT,
      UNIQUE(student_id, quiz_id, attempt_num),
      FOREIGN KEY (quiz_id) REFERENCES quizzes(id)
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'student_id': studentId,
        'quiz_id': quizId,
        'score': score,
        'max_score': maxScore,
        'percentage': calculatedPercentage,
        'attempt_num': attemptNum,
        'time_taken_secs': timeTakenSecs,
        'is_passing': calculatedIsPassing ? 1 : 0,
        'synced_at': syncedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };

  factory Score.fromSqlite(Map<String, dynamic> map) => Score(
        id: map['id'] as String,
        studentId: map['student_id'] as String,
        quizId: map['quiz_id'] as String,
        score: (map['score'] as num).toDouble(),
        maxScore: (map['max_score'] as num).toDouble(),
        percentage: (map['percentage'] as num?)?.toDouble(),
        attemptNum: (map['attempt_num'] as int?) ?? 1,
        timeTakenSecs: map['time_taken_secs'] as int?,
        isPassing: map['is_passing'] != null ? (map['is_passing'] as int) == 1 : null,
        syncedAt: map['synced_at'] != null
            ? DateTime.parse(map['synced_at'] as String)
            : null,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, studentId, quizId, score, attemptNum];
}
