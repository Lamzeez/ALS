import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'attendance.g.dart';

@JsonSerializable()
class Attendance extends Equatable {
  final String id;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'teacher_id')
  final String teacherId;
  @JsonKey(name: 'cohort_id')
  final String cohortId;
  final String date; // ISO date string (YYYY-MM-DD)
  @JsonKey(fromJson: AttendanceStatus.fromJson, toJson: _statusToJson)
  final AttendanceStatus status;
  final String? notes;
  @JsonKey(name: 'synced_at')
  final DateTime? syncedAt;

  const Attendance({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.cohortId,
    required this.date,
    this.status = AttendanceStatus.present,
    this.notes,
    this.syncedAt,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) =>
      _$AttendanceFromJson(json);
  Map<String, dynamic> toJson() => _$AttendanceToJson(this);

  static String _statusToJson(AttendanceStatus s) => s.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS attendance (
      id TEXT PRIMARY KEY,
      student_id TEXT NOT NULL,
      teacher_id TEXT NOT NULL,
      cohort_id TEXT NOT NULL,
      date TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'present',
      notes TEXT,
      synced_at TEXT,
      UNIQUE(student_id, date)
    )
  ''';

  @override
  List<Object?> get props => [id, studentId, date, status];
}
