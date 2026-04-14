import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';
import 'course.dart';

part 'course_enrollment.g.dart';

@JsonSerializable()
class CourseEnrollment extends Equatable {
  final String id;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'course_id')
  final String courseId;
  @JsonKey(name: 'enrolled_via', fromJson: EnrollmentMethod.fromJson, toJson: _methodToJson)
  final EnrollmentMethod enrolledVia;
  @JsonKey(fromJson: EnrollmentStatus.fromJson, toJson: _statusToJson)
  final EnrollmentStatus status;
  @JsonKey(name: 'enrolled_at')
  final DateTime? enrolledAt;

  // Joined fields
  @JsonKey(name: 'course_title', includeIfNull: false)
  final String? courseTitle;
  @JsonKey(name: 'course_description', includeIfNull: false)
  final String? courseDescription;
  @JsonKey(includeFromJson: true, includeToJson: false)
  final Course? course;

  const CourseEnrollment({
    required this.id,
    required this.studentId,
    required this.courseId,
    this.enrolledVia = EnrollmentMethod.pin,
    this.status = EnrollmentStatus.active,
    this.enrolledAt,
    this.courseTitle,
    this.courseDescription,
    this.course,
  });

  factory CourseEnrollment.fromJson(Map<String, dynamic> json) {
    return CourseEnrollment(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String,
      enrolledVia: EnrollmentMethod.fromJson(json['enrolled_via'] as String? ?? 'pin'),
      status: EnrollmentStatus.fromJson(json['status'] as String? ?? 'active'),
      enrolledAt: json['enrolled_at'] != null ? DateTime.parse(json['enrolled_at'] as String) : null,
      courseTitle: json['course_title'] as String?,
      courseDescription: json['course_description'] as String?,
      course: json['courses'] != null ? Course.fromJson(json['courses'] as Map<String, dynamic>) : null,
    );
  }
  Map<String, dynamic> toJson() => _$CourseEnrollmentToJson(this);

  static String _methodToJson(EnrollmentMethod m) => m.toJson();
  static String _statusToJson(EnrollmentStatus s) => s.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS course_enrollments (
      id TEXT PRIMARY KEY,
      student_id TEXT NOT NULL,
      course_id TEXT NOT NULL,
      enrolled_via TEXT DEFAULT 'pin',
      status TEXT DEFAULT 'active',
      enrolled_at TEXT,
      UNIQUE(student_id, course_id)
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'student_id': studentId,
        'course_id': courseId,
        'enrolled_via': enrolledVia.toJson(),
        'status': status.toJson(),
        'enrolled_at': enrolledAt?.toIso8601String(),
      };

  factory CourseEnrollment.fromSqlite(Map<String, dynamic> map) =>
      CourseEnrollment(
        id: map['id'] as String,
        studentId: map['student_id'] as String,
        courseId: map['course_id'] as String,
        enrolledVia:
            EnrollmentMethod.fromJson(map['enrolled_via'] as String? ?? 'pin'),
        status:
            EnrollmentStatus.fromJson(map['status'] as String? ?? 'active'),
        enrolledAt: map['enrolled_at'] != null
            ? DateTime.parse(map['enrolled_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, studentId, courseId, status];
}
