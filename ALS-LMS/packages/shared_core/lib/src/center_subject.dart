import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

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
  @JsonKey(
    name: 'strand',
    fromJson: AlsStrand.fromJson,
    toJson: _strandToJson,
  )
  final AlsStrand strand;
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
    this.strand = AlsStrand.communicationSkills,
    this.isActive = true,
    this.createdAt,
  });

  factory CenterSubject.fromJson(Map<String, dynamic> json) => _$CenterSubjectFromJson(json);
  Map<String, dynamic> toJson() => _$CenterSubjectToJson(this);

  static String _strandToJson(AlsStrand s) => s.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS center_subjects (
      id TEXT PRIMARY KEY,
      als_center_id TEXT NOT NULL,
      subject_name TEXT NOT NULL,
      subject_code TEXT NOT NULL,
      grade_level TEXT,
      strand TEXT,
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
        'strand': strand.toJson(),
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt?.toIso8601String(),
      };

  factory CenterSubject.fromSqlite(Map<String, dynamic> map) => CenterSubject(
        id: map['id'] as String,
        alsCenterId: map['als_center_id'] as String,
        subjectName: map['subject_name'] as String,
        subjectCode: map['subject_code'] as String,
        gradeLevel: map['grade_level'] as String?,
        strand: AlsStrand.fromJson(map['strand'] as String? ?? ''),
        isActive: (map['is_active'] as int?) == 1,
        createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
      );

  @override
  List<Object?> get props => [id, alsCenterId, subjectCode, gradeLevel, strand];
}
