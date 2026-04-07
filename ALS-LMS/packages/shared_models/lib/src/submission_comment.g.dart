// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'submission_comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubmissionComment _$SubmissionCommentFromJson(Map<String, dynamic> json) =>
    SubmissionComment(
      id: json['id'] as String,
      submissionId: json['submission_id'] as String,
      teacherId: json['teacher_id'] as String,
      commentText: json['comment_text'] as String?,
      markupJson: json['markup_json'] as Map<String, dynamic>?,
      attachmentUrl: json['attachment_url'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SubmissionCommentToJson(SubmissionComment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'submission_id': instance.submissionId,
      'teacher_id': instance.teacherId,
      'comment_text': instance.commentText,
      'markup_json': instance.markupJson,
      'attachment_url': instance.attachmentUrl,
      'created_at': instance.createdAt?.toIso8601String(),
    };
