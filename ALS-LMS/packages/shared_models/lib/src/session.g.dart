// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Session _$SessionFromJson(Map<String, dynamic> json) => Session(
  id: json['id'] as String,
  teacherId: json['teacher_id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  scheduledAt: DateTime.parse(json['scheduled_at'] as String),
  durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
  location: json['location'] as String?,
  status: json['status'] == null
      ? SessionStatus.scheduled
      : SessionStatus.fromJson(json['status'] as String),
  syncStatus: json['sync_status'] as String? ?? 'synced',
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$SessionToJson(Session instance) => <String, dynamic>{
  'id': instance.id,
  'teacher_id': instance.teacherId,
  'title': instance.title,
  'description': instance.description,
  'scheduled_at': instance.scheduledAt.toIso8601String(),
  'duration_minutes': instance.durationMinutes,
  'location': instance.location,
  'status': Session._statusToJson(instance.status),
  'sync_status': instance.syncStatus,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
