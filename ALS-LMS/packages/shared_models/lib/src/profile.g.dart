// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
      id: json['id'] as String,
      role: UserRole.fromJson(json['role'] as String),
      lrn: json['lrn'] as String?,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      districtId: json['district_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      deviceId: json['device_id'] as String?,
      phoneNumber: json['phone_number'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      approvalStatus:
          ApprovalStatus.fromJson(json['approval_status'] as String?),
      onboardingCompleted: json['onboarding_completed'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
      'id': instance.id,
      'role': Profile._roleToJson(instance.role),
      'lrn': instance.lrn,
      'full_name': instance.fullName,
      'email': instance.email,
      'district_id': instance.districtId,
      'avatar_url': instance.avatarUrl,
      'device_id': instance.deviceId,
      'phone_number': instance.phoneNumber,
      'is_active': instance.isActive,
      'approval_status': instance.approvalStatus.toJson(),
      'onboarding_completed': instance.onboardingCompleted,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
