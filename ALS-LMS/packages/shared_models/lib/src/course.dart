import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'course.g.dart';

@JsonSerializable()
class Course extends Equatable {
  final String id;
  final String title;
  final String? description;
  @JsonKey(fromJson: AlsStrand.fromJson, toJson: _strandToJson)
  final AlsStrand strand;
  @JsonKey(name: 'teacher_id')
  final String? teacherId;
  @JsonKey(name: 'cohort_id')
  final String? cohortId;
  @JsonKey(name: 'blueprint_id')
  final String? blueprintId;
  @JsonKey(name: 'is_blueprint')
  final bool isBlueprint;
  @JsonKey(name: 'is_published')
  final bool isPublished;
  @JsonKey(name: 'schema_version')
  final int schemaVersion;
  // New fields for enrollment access control
  final String? region;
  @JsonKey(name: 'center_id')
  final String? centerId;
  @JsonKey(name: 'qr_code')
  final String? qrCode;
  @JsonKey(name: 'pin_code')
  final String? pinCode;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Course({
    required this.id,
    required this.title,
    this.description,
    required this.strand,
    this.teacherId,
    this.cohortId,
    this.blueprintId,
    this.isBlueprint = false,
    this.isPublished = false,
    this.schemaVersion = 1,
    this.region,
    this.centerId,
    this.qrCode,
    this.pinCode,
    this.createdAt,
    this.updatedAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) => _$CourseFromJson(json);
  Map<String, dynamic> toJson() => _$CourseToJson(this);

  static String _strandToJson(AlsStrand s) => s.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS courses (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      strand TEXT NOT NULL,
      teacher_id TEXT,
      cohort_id TEXT,
      blueprint_id TEXT,
      is_blueprint INTEGER NOT NULL DEFAULT 0,
      is_published INTEGER NOT NULL DEFAULT 0,
      schema_version INTEGER NOT NULL DEFAULT 1,
      region TEXT,
      center_id TEXT,
      qr_code TEXT,
      pin_code TEXT,
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'title': title,
        'description': description,
        'strand': strand.toJson(),
        'teacher_id': teacherId,
        'cohort_id': cohortId,
        'blueprint_id': blueprintId,
        'is_blueprint': isBlueprint ? 1 : 0,
        'is_published': isPublished ? 1 : 0,
        'schema_version': schemaVersion,
        'region': region,
        'center_id': centerId,
        'qr_code': qrCode,
        'pin_code': pinCode,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Course.fromSqlite(Map<String, dynamic> map) => Course(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        strand: AlsStrand.fromJson(map['strand'] as String),
        teacherId: map['teacher_id'] as String?,
        cohortId: map['cohort_id'] as String?,
        blueprintId: map['blueprint_id'] as String?,
        isBlueprint: (map['is_blueprint'] as int?) == 1,
        isPublished: (map['is_published'] as int?) == 1,
        schemaVersion: (map['schema_version'] as int?) ?? 1,
        region: map['region'] as String?,
        centerId: map['center_id'] as String?,
        qrCode: map['qr_code'] as String?,
        pinCode: map['pin_code'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, title, strand, isBlueprint];
}
