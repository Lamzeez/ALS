import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'lesson.g.dart';

@JsonSerializable()
class Lesson extends Equatable {
  final String id;
  @JsonKey(name: 'module_id')
  final String moduleId;
  final String title;
  @JsonKey(name: 'content_json')
  final Map<String, dynamic>? contentJson;
  @JsonKey(name: 'content_type', fromJson: LessonContentType.fromJson, toJson: _typeToJson)
  final LessonContentType contentType;
  @JsonKey(name: 'order_index')
  final int orderIndex;
  @JsonKey(name: 'duration_minutes')
  final int? durationMinutes;
  @JsonKey(name: 'is_published')
  final bool isPublished;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const Lesson({
    required this.id,
    required this.moduleId,
    required this.title,
    this.contentJson,
    this.contentType = LessonContentType.text,
    this.orderIndex = 0,
    this.durationMinutes,
    this.isPublished = false,
    this.createdAt,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) => _$LessonFromJson(json);
  Map<String, dynamic> toJson() => _$LessonToJson(this);

  static String _typeToJson(LessonContentType t) => t.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS lessons (
      id TEXT PRIMARY KEY,
      module_id TEXT NOT NULL,
      title TEXT NOT NULL,
      content_json TEXT,
      content_type TEXT NOT NULL DEFAULT 'text',
      order_index INTEGER NOT NULL DEFAULT 0,
      duration_minutes INTEGER,
      is_published INTEGER NOT NULL DEFAULT 0,
      created_at TEXT,
      FOREIGN KEY (module_id) REFERENCES modules(id)
    )
  ''';

  @override
  List<Object?> get props => [id, moduleId, title, orderIndex];
}
