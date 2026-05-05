// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'als_center_registration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AlsCenterRegistration _$AlsCenterRegistrationFromJson(
  Map<String, dynamic> json,
) => AlsCenterRegistration(
  id: json['id'] as String,
  centerName: json['center_name'] as String,
  address: json['address'] as String,
  region: json['region'] as String,
  contactNumber: json['contact_number'] as String,
  adminFullName: json['admin_full_name'] as String,
  adminEmail: json['admin_email'] as String,
  status: json['status'] == null
      ? CenterRegistrationStatus.pending
      : CenterRegistrationStatus.fromJson(json['status'] as String),
  rejectionReason: json['rejection_reason'] as String?,
  reviewedBy: json['reviewed_by'] as String?,
  reviewedAt: json['reviewed_at'] == null
      ? null
      : DateTime.parse(json['reviewed_at'] as String),
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$AlsCenterRegistrationToJson(
  AlsCenterRegistration instance,
) => <String, dynamic>{
  'id': instance.id,
  'center_name': instance.centerName,
  'address': instance.address,
  'region': instance.region,
  'contact_number': instance.contactNumber,
  'admin_full_name': instance.adminFullName,
  'admin_email': instance.adminEmail,
  'status': instance.status,
  'rejection_reason': instance.rejectionReason,
  'reviewed_by': instance.reviewedBy,
  'reviewed_at': instance.reviewedAt?.toIso8601String(),
  'created_at': instance.createdAt?.toIso8601String(),
};
