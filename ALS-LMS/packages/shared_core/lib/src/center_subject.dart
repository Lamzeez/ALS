import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'center_subject.g.dart';

@JsonSerializable()
class CenterSubject extends Equatable {
  final String id;
  @JsonKey(name: 'als_center_id')
  final String alsCenterId;
  @JsonKey(name: 'subject_name')
  final String subjectName;
  @JsonKey(name: 'subject_code')
  final String subjectCode;
  @JsonKey(name: 'grade_level')
  final String? gradeLevel;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const CenterSubject({
    required this.id,
    required this.alsCenterId,
    required this.subjectName,
    required this.subjectCode,
    this.gradeLevel,
    this.isActive = true,
    this.createdAt,
  });

  factory CenterSubject.fromJson(Map<String, dynamic> json) => _$CenterSubjectFromJson(json);
  Map<String, dynamic> toJson() => _$CenterSubjectToJson(this);

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS center_subjects (
      id TEXT PRIMARY KEY,
      als_center_id TEXT NOT NULL,
      subject_name TEXT NOT NULL,
      subject_code TEXT NOT NULL,
      grade_level TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'als_center_id': alsCenterId,
        'subject_name': subjectName,
        'subject_code': subjectCode,
        'grade_level': gradeLevel,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, alsCenterId, subjectCode, gradeLevel];
}
