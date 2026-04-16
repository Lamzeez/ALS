// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cohort.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Cohort _$CohortFromJson(Map<String, dynamic> json) => Cohort(
  id: json['id'] as String,
  districtId: json['district_id'] as String,
  name: json['name'] as String,
  barangay: json['barangay'] as String?,
  coordinatorId: json['coordinator_id'] as String?,
  academicYear: json['academic_year'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$CohortToJson(Cohort instance) => <String, dynamic>{
  'id': instance.id,
  'district_id': instance.districtId,
  'name': instance.name,
  'barangay': instance.barangay,
  'coordinator_id': instance.coordinatorId,
  'academic_year': instance.academicYear,
  'is_active': instance.isActive,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
