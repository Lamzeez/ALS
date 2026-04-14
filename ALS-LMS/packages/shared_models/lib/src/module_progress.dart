import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'module_progress.g.dart';

@JsonSerializable()
class ModuleProgress extends Equatable {
  final String id;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'module_id')
  final String moduleId;
  @JsonKey(name: 'course_id')
  final String courseId;
  @JsonKey(fromJson: ProgressStatus.fromJson, toJson: _statusToJson)
  final ProgressStatus status;
  @JsonKey(name: 'mastery_score')
  final double masteryScore;
  @JsonKey(name: 'lessons_viewed')
  final int lessonsViewed;
  @JsonKey(name: 'total_lessons')
  final int totalLessons;
  @JsonKey(name: 'time_spent_mins')
  final int timeSpentMins;
  @JsonKey(name: 'started_at')
  final DateTime? startedAt;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'synced_at')
  final DateTime? syncedAt;
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? moduleTitle;

  const ModuleProgress({
    required this.id,
    required this.studentId,
    required this.moduleId,
    required this.courseId,
    this.status = ProgressStatus.locked,
    this.masteryScore = 0.0,
    this.lessonsViewed = 0,
    this.totalLessons = 0,
    this.timeSpentMins = 0,
    this.startedAt,
    this.completedAt,
    this.syncedAt,
    this.moduleTitle,
  });

  factory ModuleProgress.fromJson(Map<String, dynamic> json) {
    return ModuleProgress(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      moduleId: json['module_id'] as String,
      courseId: json['course_id'] as String,
      status: ProgressStatus.fromJson(json['status'] as String),
      masteryScore: (json['mastery_score'] as num?)?.toDouble() ?? 0.0,
      lessonsViewed: (json['lessons_viewed'] as int?) ?? 0,
      totalLessons: (json['total_lessons'] as int?) ?? 0,
      timeSpentMins: (json['time_spent_mins'] as int?) ?? 0,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      syncedAt: json['synced_at'] != null ? DateTime.parse(json['synced_at'] as String) : null,
      moduleTitle: (json['modules'] as Map?)?['title'] as String?,
    );
  }
  Map<String, dynamic> toJson() => _$ModuleProgressToJson(this);

  static String _statusToJson(ProgressStatus s) => s.toJson();

  /// Check if this module is considered mastered
  bool get isMastered => status == ProgressStatus.mastered || status == ProgressStatus.completed;

  /// Progress percentage (lessons viewed / total)
  double get progressPercentage =>
      totalLessons > 0 ? (lessonsViewed / totalLessons) * 100 : 0;

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS module_progress (
      id TEXT PRIMARY KEY,
      student_id TEXT NOT NULL,
      module_id TEXT NOT NULL,
      course_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'locked',
      mastery_score REAL DEFAULT 0.0,
      lessons_viewed INTEGER NOT NULL DEFAULT 0,
      total_lessons INTEGER NOT NULL DEFAULT 0,
      time_spent_mins INTEGER NOT NULL DEFAULT 0,
      started_at TEXT,
      completed_at TEXT,
      synced_at TEXT,
      UNIQUE(student_id, module_id),
      FOREIGN KEY (module_id) REFERENCES modules(id),
      FOREIGN KEY (course_id) REFERENCES courses(id)
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'student_id': studentId,
        'module_id': moduleId,
        'course_id': courseId,
        'status': status.toJson(),
        'mastery_score': masteryScore,
        'lessons_viewed': lessonsViewed,
        'total_lessons': totalLessons,
        'time_spent_mins': timeSpentMins,
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'synced_at': syncedAt?.toIso8601String(),
      };

  factory ModuleProgress.fromSqlite(Map<String, dynamic> map) =>
      ModuleProgress(
        id: map['id'] as String,
        studentId: map['student_id'] as String,
        moduleId: map['module_id'] as String,
        courseId: map['course_id'] as String,
        status: ProgressStatus.fromJson(map['status'] as String),
        masteryScore: (map['mastery_score'] as num?)?.toDouble() ?? 0.0,
        lessonsViewed: (map['lessons_viewed'] as int?) ?? 0,
        totalLessons: (map['total_lessons'] as int?) ?? 0,
        timeSpentMins: (map['time_spent_mins'] as int?) ?? 0,
        startedAt: map['started_at'] != null
            ? DateTime.parse(map['started_at'] as String)
            : null,
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
        syncedAt: map['synced_at'] != null
            ? DateTime.parse(map['synced_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, studentId, moduleId, status, masteryScore];
}
