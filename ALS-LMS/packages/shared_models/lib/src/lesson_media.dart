import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'lesson_media.g.dart';

@JsonSerializable()
class LessonMedia extends Equatable {
  final String id;
  @JsonKey(name: 'lesson_id')
  final String lessonId;
  @JsonKey(name: 'storage_url')
  final String storageUrl;
  @JsonKey(name: 'file_name')
  final String fileName;
  @JsonKey(name: 'file_type', fromJson: MediaFileType.fromJson, toJson: _typeToJson)
  final MediaFileType fileType;
  @JsonKey(name: 'file_size_bytes')
  final int? fileSizeBytes;
  @JsonKey(name: 'mime_type')
  final String? mimeType;
  @JsonKey(name: 'is_downloadable')
  final bool isDownloadable;
  @JsonKey(name: 'order_index')
  final int orderIndex;

  const LessonMedia({
    required this.id,
    required this.lessonId,
    required this.storageUrl,
    required this.fileName,
    required this.fileType,
    this.fileSizeBytes,
    this.mimeType,
    this.isDownloadable = true,
    this.orderIndex = 0,
  });

  factory LessonMedia.fromJson(Map<String, dynamic> json) =>
      _$LessonMediaFromJson(json);
  Map<String, dynamic> toJson() => _$LessonMediaToJson(this);

  static String _typeToJson(MediaFileType t) => t.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS lesson_media (
      id TEXT PRIMARY KEY,
      lesson_id TEXT NOT NULL,
      storage_url TEXT NOT NULL,
      file_name TEXT NOT NULL,
      file_type TEXT NOT NULL,
      file_size_bytes INTEGER,
      mime_type TEXT,
      is_downloadable INTEGER NOT NULL DEFAULT 1,
      local_path TEXT,
      order_index INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (lesson_id) REFERENCES lessons(id)
    )
  ''';

  @override
  List<Object?> get props => [id, lessonId, fileName, fileType];
}
