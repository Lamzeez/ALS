// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SystemSetting _$SystemSettingFromJson(Map<String, dynamic> json) =>
    SystemSetting(
      id: json['id'] as String,
      key: json['key'] as String,
      value: json['value'] as Map<String, dynamic>,
      updatedBy: json['updated_by'] as String?,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$SystemSettingToJson(SystemSetting instance) =>
    <String, dynamic>{
      'id': instance.id,
      'key': instance.key,
      'value': instance.value,
      'updated_by': instance.updatedBy,
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
