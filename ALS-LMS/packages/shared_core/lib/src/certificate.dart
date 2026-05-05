import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'certificate.g.dart';

@JsonSerializable()
class Certificate extends Equatable {
  final String id;
  @JsonKey(name: 'enrollment_id')
  final String enrollmentId;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'course_id')
  final String courseId;
  @JsonKey(name: 'issued_at')
  final DateTime? issuedAt;
  @JsonKey(name: 'certificate_url')
  final String? certificateUrl;

  const Certificate({
    required this.id,
    required this.enrollmentId,
    required this.studentId,
    required this.courseId,
    this.issuedAt,
    this.certificateUrl,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) => _$CertificateFromJson(json);
  Map<String, dynamic> toJson() => _$CertificateToJson(this);

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS certificates (
      id TEXT PRIMARY KEY,
      enrollment_id TEXT NOT NULL UNIQUE,
      student_id TEXT NOT NULL,
      course_id TEXT NOT NULL,
      issued_at TEXT,
      certificate_url TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'enrollment_id': enrollmentId,
        'student_id': studentId,
        'course_id': courseId,
        'issued_at': issuedAt?.toIso8601String(),
        'certificate_url': certificateUrl,
      };

  @override
  List<Object?> get props => [id, enrollmentId, studentId, courseId];
}
