// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_center.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LearningCenter _$LearningCenterFromJson(Map<String, dynamic> json) =>
    LearningCenter(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      region: json['region'] as String,
      contactNumber: json['contact_number'] as String?,
      headTeacherId: json['head_teacher_id'] as String?,
      registrationId: json['registration_id'] as String?,
      centerAdminId: json['center_admin_id'] as String?,
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
      'address': instance.address,
      'region': instance.region,
      'contact_number': instance.contactNumber,
      'head_teacher_id': instance.headTeacherId,
      'registration_id': instance.registrationId,
      'center_admin_id': instance.centerAdminId,
      'is_active': instance.isActive,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
