// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_center.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LearningCenter _$LearningCenterFromJson(Map<String, dynamic> json) =>
    LearningCenter(
      id: json['id'] as String,
      name: json['name'] as String,
      region: json['region'] as String,
      province: json['province'] as String?,
      physicalAddress: json['physical_address'] as String?,
      districtId: json['district_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$LearningCenterToJson(LearningCenter instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'region': instance.region,
      'province': instance.province,
      'physical_address': instance.physicalAddress,
      'district_id': instance.districtId,
      'is_active': instance.isActive,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
