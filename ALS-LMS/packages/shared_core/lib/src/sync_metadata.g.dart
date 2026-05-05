// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SyncMetadata _$SyncMetadataFromJson(Map<String, dynamic> json) => SyncMetadata(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  deviceId: json['device_id'] as String?,
  deviceInfo: json['device_info'] as Map<String, dynamic>?,
  currentStrand: SyncMetadata._strandFromJson(
    json['current_strand'] as String?,
  ),
  approxLat: (json['approx_lat'] as num?)?.toDouble(),
  approxLng: (json['approx_lng'] as num?)?.toDouble(),
  recordsPushed: (json['records_pushed'] as num?)?.toInt() ?? 0,
  recordsPulled: (json['records_pulled'] as num?)?.toInt() ?? 0,
  syncDurationMs: (json['sync_duration_ms'] as num?)?.toInt(),
  schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
  lastSyncAt: json['last_sync_at'] == null
      ? null
      : DateTime.parse(json['last_sync_at'] as String),
);

Map<String, dynamic> _$SyncMetadataToJson(SyncMetadata instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'device_id': instance.deviceId,
      'device_info': instance.deviceInfo,
      'current_strand': SyncMetadata._strandToJson(instance.currentStrand),
      'approx_lat': instance.approxLat,
      'approx_lng': instance.approxLng,
      'records_pushed': instance.recordsPushed,
      'records_pulled': instance.recordsPulled,
      'sync_duration_ms': instance.syncDurationMs,
      'schema_version': instance.schemaVersion,
      'last_sync_at': instance.lastSyncAt?.toIso8601String(),
    };
