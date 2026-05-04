// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
  id: json['id'] as String,
  role: UserRole.fromJson(json['role'] as String),
  studentIdNumber: json['student_id_number'] as String?,
  fullName: json['full_name'] as String,
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  email: json['email'] as String?,
  alsCenterId: json['als_center_id'] as String?,
  profilePictureUrl: json['profile_picture_url'] as String?,
  deviceId: json['device_id'] as String?,
  phoneNumber: json['phone_number'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  approvalStatus: json['approval_status'] == null
      ? ApprovalStatus.approved
      : ApprovalStatus.fromJson(json['approval_status'] as String?),
  onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
  employeeId: json['employee_id'] as String?,
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
  'student_id_number': instance.studentIdNumber,
  'full_name': instance.fullName,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'email': instance.email,
  'als_center_id': instance.alsCenterId,
  'profile_picture_url': instance.profilePictureUrl,
  'device_id': instance.deviceId,
  'phone_number': instance.phoneNumber,
  'is_active': instance.isActive,
  'approval_status': instance.approvalStatus,
  'onboarding_completed': instance.onboardingCompleted,
  'employee_id': instance.employeeId,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
