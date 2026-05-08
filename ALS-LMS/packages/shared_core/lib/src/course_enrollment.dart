import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';
import 'course.dart';

part 'course_enrollment.g.dart';

@JsonSerializable()
class CourseEnrollment extends Equatable {
  final String id;
  @JsonKey(name: 'course_id')
  final String courseId;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'enrolled_at')
  final DateTime? enrolledAt;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(
    name: 'status',
    fromJson: EnrollmentStatus.fromJson,
    toJson: _statusToJson,
  )
  final EnrollmentStatus _status;

  EnrollmentStatus get status => _status;

  // Joined field for convenience in UI
  @JsonKey(includeFromJson: true, includeToJson: false)
  final Course? _course;

  Course get course => _course ?? Course(id: courseId, title: 'Loading...', strand: AlsStrand.communicationSkills);

  const CourseEnrollment({
    required this.id,
    required this.courseId,
    required this.studentId,
    this.enrolledAt,
    this.completedAt,
    this.isActive = true,
    EnrollmentStatus status = EnrollmentStatus.active,
    Course? course,
  }) : _status = status, _course = course;

  factory CourseEnrollment.fromJson(Map<String, dynamic> json) => _$CourseEnrollmentFromJson(json);
  Map<String, dynamic> toJson() => _$CourseEnrollmentToJson(this);

  static String _statusToJson(EnrollmentStatus s) => s.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS course_enrollments (
      id TEXT PRIMARY KEY,
      course_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      enrolled_at TEXT,
      completed_at TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      status TEXT,
      UNIQUE(course_id, student_id)
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'course_id': courseId,
        'student_id': studentId,
        'enrolled_at': enrolledAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'is_active': isActive ? 1 : 0,
        'status': status.toJson(),
      };

  factory CourseEnrollment.fromSqlite(Map<String, dynamic> map) => CourseEnrollment(
        id: map['id'] as String,
        courseId: map['course_id'] as String,
        studentId: map['student_id'] as String,
        enrolledAt: map['enrolled_at'] != null ? DateTime.parse(map['enrolled_at'] as String) : null,
        completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
        isActive: (map['is_active'] as int?) == 1,
        status: EnrollmentStatus.fromJson(map['status'] as String? ?? 'active'),
      );

  @override
  List<Object?> get props => [id, courseId, studentId, status];
}
