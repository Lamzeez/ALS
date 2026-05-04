// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Download _$DownloadFromJson(Map<String, dynamic> json) => Download(
  id: json['id'] as String,
  lessonId: json['lesson_id'] as String,
  studentId: json['student_id'] as String,
  localFilePath: json['local_file_path'] as String?,
  downloadProgress: (json['download_progress'] as num?)?.toDouble() ?? 0.0,
  status: json['status'] == null
      ? DownloadStatus.notDownloaded
      : DownloadStatus.fromJson(json['status'] as String),
  fileSizeByes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$DownloadToJson(Download instance) => <String, dynamic>{
  'id': instance.id,
  'lesson_id': instance.lessonId,
  'student_id': instance.studentId,
  'local_file_path': instance.localFilePath,
  'download_progress': instance.downloadProgress,
  'status': Download._statusToJson(instance.status),
  'file_size_bytes': instance.fileSizeByes,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
