import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'course.g.dart';

@JsonSerializable()
class Course extends Equatable {
  final String id;
  final String title;
  final String? description;
  @JsonKey(name: 'subject_id')
  final String? subjectId;
  @JsonKey(name: 'teacher_id')
  final String? teacherId;
  @JsonKey(name: 'als_center_id')
  final String? alsCenterId;
  @JsonKey(
    name: 'strand',
    fromJson: AlsStrand.fromJson,
    toJson: _strandToJson,
  )
  final AlsStrand strand;
  @JsonKey(name: 'course_pin')
  final String? coursePin;
  @JsonKey(name: 'qr_code_url')
  final String? qrCodeUrl;
  @JsonKey(name: 'start_date')
  final DateTime? startDate;
  @JsonKey(name: 'end_date')
  final DateTime? endDate;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'is_published')
  final bool isPublished;
  @JsonKey(name: 'sync_status')
  final String syncStatus;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Course({
    required this.id,
    required this.title,
    this.description,
    this.subjectId,
    this.teacherId,
    this.alsCenterId,
    this.strand = AlsStrand.communicationSkills,
    this.coursePin,
    this.qrCodeUrl,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.isPublished = false,
    this.syncStatus = 'synced',
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
      subject_id TEXT,
      teacher_id TEXT,
      als_center_id TEXT,
      strand TEXT,
      course_pin TEXT UNIQUE,
      qr_code_url TEXT,
      start_date TEXT,
      end_date TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_published INTEGER NOT NULL DEFAULT 0,
      sync_status TEXT DEFAULT 'synced',
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'title': title,
        'description': description,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'als_center_id': alsCenterId,
        'strand': strand.toJson(),
        'course_pin': coursePin,
        'qr_code_url': qrCodeUrl,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'is_active': isActive ? 1 : 0,
        'is_published': isPublished ? 1 : 0,
        'sync_status': syncStatus,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Course.fromSqlite(Map<String, dynamic> map) => Course(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        subjectId: map['subject_id'] as String?,
        teacherId: map['teacher_id'] as String?,
        alsCenterId: map['als_center_id'] as String?,
        strand: AlsStrand.fromJson(map['strand'] as String? ?? ''),
        coursePin: map['course_pin'] as String?,
        qrCodeUrl: map['qr_code_url'] as String?,
        startDate: map['start_date'] != null ? DateTime.parse(map['start_date'] as String) : null,
        endDate: map['end_date'] != null ? DateTime.parse(map['end_date'] as String) : null,
        isActive: (map['is_active'] as int?) == 1,
        isPublished: (map['is_published'] as int?) == 1,
        syncStatus: (map['sync_status'] as String?) ?? 'synced',
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
        updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : null,
      );

  @override
  List<Object?> get props => [id, title, teacherId, alsCenterId, strand, coursePin];
}
