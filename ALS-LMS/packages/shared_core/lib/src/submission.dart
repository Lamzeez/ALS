import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'submission.g.dart';

@JsonSerializable()
class Submission extends Equatable {
  final String id;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'lesson_id')
  final String? lessonId;
  @JsonKey(name: 'quiz_id')
  final String? quizId;
  @JsonKey(fromJson: SubmissionStatus.fromJson, toJson: _statusToJson)
  final SubmissionStatus status;
  @JsonKey(name: 'content_json')
  final Map<String, dynamic>? contentJson;
  @JsonKey(name: 'storage_urls')
  final List<String>? storageUrls;
  final double? grade;
  @JsonKey(name: 'graded_by')
  final String? gradedBy;
  @JsonKey(name: 'graded_at')
  final DateTime? gradedAt;
  @JsonKey(name: 'synced_at')
  final DateTime? syncedAt;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const Submission({
    required this.id,
    required this.studentId,
    this.lessonId,
    this.quizId,
    this.status = SubmissionStatus.draft,
    this.contentJson,
    this.storageUrls,
    this.grade,
    this.gradedBy,
    this.gradedAt,
    this.syncedAt,
    this.createdAt,
  });

  factory Submission.fromJson(Map<String, dynamic> json) =>
      _$SubmissionFromJson(json);
  Map<String, dynamic> toJson() => _$SubmissionToJson(this);

  static String _statusToJson(SubmissionStatus s) => s.toJson();

  @override
  List<Object?> get props => [id, studentId, status];
}
