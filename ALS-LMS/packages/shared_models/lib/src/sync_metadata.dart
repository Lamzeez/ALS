import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'sync_metadata.g.dart';

@JsonSerializable()
class SyncMetadata extends Equatable {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'device_info')
  final Map<String, dynamic>? deviceInfo;
  @JsonKey(name: 'current_strand', fromJson: _strandFromJson, toJson: _strandToJson)
  final AlsStrand? currentStrand;
  @JsonKey(name: 'approx_lat')
  final double? approxLat;
  @JsonKey(name: 'approx_lng')
  final double? approxLng;
  @JsonKey(name: 'records_pushed')
  final int recordsPushed;
  @JsonKey(name: 'records_pulled')
  final int recordsPulled;
  @JsonKey(name: 'sync_duration_ms')
  final int? syncDurationMs;
  @JsonKey(name: 'schema_version')
  final int schemaVersion;
  @JsonKey(name: 'last_sync_at')
  final DateTime? lastSyncAt;

  const SyncMetadata({
    required this.id,
    required this.userId,
    this.deviceId,
    this.deviceInfo,
    this.currentStrand,
    this.approxLat,
    this.approxLng,
    this.recordsPushed = 0,
    this.recordsPulled = 0,
    this.syncDurationMs,
    this.schemaVersion = 1,
    this.lastSyncAt,
  });

  factory SyncMetadata.fromJson(Map<String, dynamic> json) =>
      _$SyncMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$SyncMetadataToJson(this);

  static AlsStrand? _strandFromJson(String? value) =>
      value != null ? AlsStrand.fromJson(value) : null;
  static String? _strandToJson(AlsStrand? s) => s?.toJson();

  @override
  List<Object?> get props => [id, userId, schemaVersion, lastSyncAt];
}
