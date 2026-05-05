import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'course_timeline.g.dart';

@JsonSerializable()
class CourseTimeline extends Equatable {
  final String id;
  @JsonKey(name: 'course_id')
  final String courseId;
  final String title;
  final String? description;
  @JsonKey(name: 'lesson_id')
  final String? lessonId;
  @JsonKey(name: 'start_date')
  final DateTime? startDate;
  @JsonKey(name: 'end_date')
  final DateTime? endDate;
  @JsonKey(name: 'order_index')
  final int orderIndex;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const CourseTimeline({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.lessonId,
    this.startDate,
    this.endDate,
    this.orderIndex = 0,
    this.createdAt,
  });

  factory CourseTimeline.fromJson(Map<String, dynamic> json) => _$CourseTimelineFromJson(json);
  Map<String, dynamic> toJson() => _$CourseTimelineToJson(this);

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS course_timeline (
      id TEXT PRIMARY KEY,
      course_id TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      lesson_id TEXT,
      start_date TEXT,
      end_date TEXT,
      order_index INTEGER NOT NULL DEFAULT 0,
      created_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'course_id': courseId,
        'title': title,
        'description': description,
        'lesson_id': lessonId,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'order_index': orderIndex,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, courseId, title, orderIndex];
}
