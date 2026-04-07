// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'announcement_comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnnouncementComment _$AnnouncementCommentFromJson(Map<String, dynamic> json) =>
    AnnouncementComment(
      id: json['id'] as String,
      announcementId: json['announcement_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
    );

Map<String, dynamic> _$AnnouncementCommentToJson(
    AnnouncementComment instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'announcement_id': instance.announcementId,
    'user_id': instance.userId,
    'content': instance.content,
    'created_at': instance.createdAt?.toIso8601String(),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('user_name', instance.userName);
  writeNotNull('user_avatar', instance.userAvatar);
  return val;
}
