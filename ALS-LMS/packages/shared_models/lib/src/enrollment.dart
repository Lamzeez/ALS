import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'enrollment.g.dart';

@JsonSerializable()
class Enrollment extends Equatable {
  final String id;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'cohort_id')
  final String cohortId;
  @JsonKey(name: 'enrolled_at')
  final DateTime? enrolledAt;
  @JsonKey(fromJson: EnrollmentStatus.fromJson, toJson: _statusToJson)
  final EnrollmentStatus status;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const Enrollment({
    required this.id,
    required this.studentId,
    required this.cohortId,
    this.enrolledAt,
    this.status = EnrollmentStatus.active,
    this.createdAt,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentFromJson(json);
  Map<String, dynamic> toJson() => _$EnrollmentToJson(this);

  static String _statusToJson(EnrollmentStatus s) => s.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS enrollments (
      id TEXT PRIMARY KEY,
      student_id TEXT NOT NULL,
      cohort_id TEXT NOT NULL,
      enrolled_at TEXT,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT,
      UNIQUE(student_id, cohort_id)
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'student_id': studentId,
        'cohort_id': cohortId,
        'enrolled_at': enrolledAt?.toIso8601String(),
        'status': status.toJson(),
        'created_at': createdAt?.toIso8601String(),
      };

  factory Enrollment.fromSqlite(Map<String, dynamic> map) => Enrollment(
        id: map['id'] as String,
        studentId: map['student_id'] as String,
        cohortId: map['cohort_id'] as String,
        enrolledAt: map['enrolled_at'] != null
            ? DateTime.parse(map['enrolled_at'] as String)
            : null,
        status: EnrollmentStatus.fromJson(map['status'] as String),
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, studentId, cohortId, status];
}
