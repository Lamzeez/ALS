import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'lesson.g.dart';

@JsonSerializable()
class Lesson extends Equatable {
  final String id;
  @JsonKey(name: 'course_id')
  final String? courseId;
  @JsonKey(name: 'module_id')
  final String? moduleId;
  final String title;
  @JsonKey(name: 'content_json')
  final Map<String, dynamic>? contentJson;
  @JsonKey(name: 'content_type')
  final String contentType;
  @JsonKey(name: 'order_index')
  final int orderIndex;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const Lesson({
    required this.id,
    this.courseId,
    this.moduleId,
    required this.title,
    this.contentJson,
    this.contentType = 'text',
    this.orderIndex = 0,
    this.createdAt,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => _$LessonFromJson(json);
  Map<String, dynamic> toJson() => _$LessonToJson(this);

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS lessons (
      id TEXT PRIMARY KEY,
      course_id TEXT,
      module_id TEXT,
      title TEXT NOT NULL,
      content_json TEXT,
      content_type TEXT NOT NULL DEFAULT 'text',
      order_index INTEGER NOT NULL DEFAULT 0,
      created_at TEXT
    )
  ''';

  @override
  List<Object?> get props => [id, courseId, moduleId, title, orderIndex];
}
