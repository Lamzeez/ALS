import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'activity_log.g.dart';

@JsonSerializable()
class ActivityLog extends Equatable {
  final String id;
  @JsonKey(name: 'user_id')
  final String? userId;
  @JsonKey(name: 'user_role')
  final String? userRole;
  final String action;
  @JsonKey(name: 'resource_type')
  final String resourceType;
  @JsonKey(name: 'resource_id')
  final String? resourceId;
  final Map<String, dynamic>? details;
  @JsonKey(name: 'ip_address')
  final String? ipAddress;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  // Joined fields
  @JsonKey(name: 'user_name', includeIfNull: false)
  final String? userName;

  const ActivityLog({
    required this.id,
    this.userId,
    this.userRole,
    required this.action,
    required this.resourceType,
    this.resourceId,
    this.details,
    this.ipAddress,
    this.createdAt,
    this.userName,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) =>
      _$ActivityLogFromJson(json);
  Map<String, dynamic> toJson() => _$ActivityLogToJson(this);

  @override
  List<Object?> get props => [id, userId, action, resourceType, createdAt];
}
