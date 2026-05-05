// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityLog _$ActivityLogFromJson(Map<String, dynamic> json) => ActivityLog(
  id: json['id'] as String,
  userId: json['user_id'] as String?,
  userRole: json['user_role'] as String?,
  action: json['action'] as String,
  resourceType: json['resource_type'] as String,
  resourceId: json['resource_id'] as String?,
  details: json['details'] as Map<String, dynamic>?,
  ipAddress: json['ip_address'] as String?,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  userName: json['user_name'] as String?,
);

Map<String, dynamic> _$ActivityLogToJson(ActivityLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'user_role': instance.userRole,
      'action': instance.action,
      'resource_type': instance.resourceType,
      'resource_id': instance.resourceId,
      'details': instance.details,
      'ip_address': instance.ipAddress,
      'created_at': instance.createdAt?.toIso8601String(),
      'user_name': ?instance.userName,
    };
