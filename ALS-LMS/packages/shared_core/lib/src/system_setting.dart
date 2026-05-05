import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'system_setting.g.dart';

@JsonSerializable()
class SystemSetting extends Equatable {
  final String id;
  final String key;
  final Map<String, dynamic> value;
  @JsonKey(name: 'updated_by')
  final String? updatedBy;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const SystemSetting({
    required this.id,
    required this.key,
    required this.value,
    this.updatedBy,
    this.updatedAt,
  });

  factory SystemSetting.fromJson(Map<String, dynamic> json) =>
      _$SystemSettingFromJson(json);
  Map<String, dynamic> toJson() => _$SystemSettingToJson(this);

  /// Check if maintenance mode is enabled
  bool get isMaintenanceEnabled =>
      key == 'maintenance_mode' && (value['enabled'] == true);

  /// Check if kill switch is active
  bool get isKillSwitchActive =>
      key == 'kill_switch' && (value['active'] == true);

  /// Get the maintenance/lock message
  String get statusMessage =>
      value['message'] as String? ?? 'System Under Maintenance';

  @override
  List<Object?> get props => [id, key, value];
}
