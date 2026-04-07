import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'module.g.dart';

@JsonSerializable()
class Module extends Equatable {
  final String id;
  @JsonKey(name: 'course_id')
  final String courseId;
  final String title;
  final String? description;
  @JsonKey(name: 'module_type', fromJson: ModuleType.fromJson, toJson: _typeToJson)
  final ModuleType moduleType;
  @JsonKey(name: 'order_index')
  final int orderIndex;
  @JsonKey(name: 'prerequisite_id')
  final String? prerequisiteId;
  @JsonKey(name: 'passing_threshold')
  final double passingThreshold;
  @JsonKey(name: 'estimated_hours')
  final double? estimatedHours;
  @JsonKey(name: 'is_published')
  final bool isPublished;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Module({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.moduleType = ModuleType.core,
    this.orderIndex = 0,
    this.prerequisiteId,
    this.passingThreshold = 75.0,
    this.estimatedHours,
    this.isPublished = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Module.fromJson(Map<String, dynamic> json) => _$ModuleFromJson(json);
  Map<String, dynamic> toJson() => _$ModuleToJson(this);

  static String _typeToJson(ModuleType t) => t.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS modules (
      id TEXT PRIMARY KEY,
      course_id TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      module_type TEXT NOT NULL DEFAULT 'core',
      order_index INTEGER NOT NULL DEFAULT 0,
      prerequisite_id TEXT,
      passing_threshold REAL DEFAULT 75.0,
      estimated_hours REAL,
      is_published INTEGER NOT NULL DEFAULT 0,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (course_id) REFERENCES courses(id),
      FOREIGN KEY (prerequisite_id) REFERENCES modules(id)
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'course_id': courseId,
        'title': title,
        'description': description,
        'module_type': moduleType.toJson(),
        'order_index': orderIndex,
        'prerequisite_id': prerequisiteId,
        'passing_threshold': passingThreshold,
        'estimated_hours': estimatedHours,
        'is_published': isPublished ? 1 : 0,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Module.fromSqlite(Map<String, dynamic> map) => Module(
        id: map['id'] as String,
        courseId: map['course_id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        moduleType: ModuleType.fromJson(map['module_type'] as String),
        orderIndex: (map['order_index'] as int?) ?? 0,
        prerequisiteId: map['prerequisite_id'] as String?,
        passingThreshold: (map['passing_threshold'] as num?)?.toDouble() ?? 75.0,
        estimatedHours: (map['estimated_hours'] as num?)?.toDouble(),
        isPublished: (map['is_published'] as int?) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, courseId, title, orderIndex];
}
