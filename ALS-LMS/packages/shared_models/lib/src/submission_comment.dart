import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'submission_comment.g.dart';

@JsonSerializable()
class SubmissionComment extends Equatable {
  final String id;
  @JsonKey(name: 'submission_id')
  final String submissionId;
  @JsonKey(name: 'teacher_id')
  final String teacherId;
  @JsonKey(name: 'comment_text')
  final String? commentText;
  @JsonKey(name: 'markup_json')
  final Map<String, dynamic>? markupJson;
  @JsonKey(name: 'attachment_url')
  final String? attachmentUrl;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const SubmissionComment({
    required this.id,
    required this.submissionId,
    required this.teacherId,
    this.commentText,
    this.markupJson,
    this.attachmentUrl,
    this.createdAt,
  });

  factory SubmissionComment.fromJson(Map<String, dynamic> json) =>
      _$SubmissionCommentFromJson(json);
  Map<String, dynamic> toJson() => _$SubmissionCommentToJson(this);

  @override
  List<Object?> get props => [id, submissionId, teacherId];
}
