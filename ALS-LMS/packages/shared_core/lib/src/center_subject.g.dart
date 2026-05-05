// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'center_subject.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CenterSubject _$CenterSubjectFromJson(Map<String, dynamic> json) =>
    CenterSubject(
      id: json['id'] as String,
      alsCenterId: json['als_center_id'] as String,
      subjectName: json['subject_name'] as String,
      subjectCode: json['subject_code'] as String,
      gradeLevel: json['grade_level'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$CenterSubjectToJson(CenterSubject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'als_center_id': instance.alsCenterId,
      'subject_name': instance.subjectName,
      'subject_code': instance.subjectCode,
      'grade_level': instance.gradeLevel,
      'is_active': instance.isActive,
      'created_at': instance.createdAt?.toIso8601String(),
    };
