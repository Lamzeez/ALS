// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LessonMedia _$LessonMediaFromJson(Map<String, dynamic> json) => LessonMedia(
  id: json['id'] as String,
  lessonId: json['lesson_id'] as String,
  storageUrl: json['storage_url'] as String,
  fileName: json['file_name'] as String,
  fileType: MediaFileType.fromJson(json['file_type'] as String),
  fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
  mimeType: json['mime_type'] as String?,
  isDownloadable: json['is_downloadable'] as bool? ?? true,
  orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$LessonMediaToJson(LessonMedia instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lesson_id': instance.lessonId,
      'storage_url': instance.storageUrl,
      'file_name': instance.fileName,
      'file_type': LessonMedia._typeToJson(instance.fileType),
      'file_size_bytes': instance.fileSizeBytes,
      'mime_type': instance.mimeType,
      'is_downloadable': instance.isDownloadable,
      'order_index': instance.orderIndex,
    };
