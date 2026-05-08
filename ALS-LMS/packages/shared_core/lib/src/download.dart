import 'dart:io';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'download.g.dart';

enum DownloadStatus {
  notDownloaded,
  downloading,
  completed,
  failed;

  String toJson() => name;
  static DownloadStatus fromJson(String value) =>
      DownloadStatus.values.firstWhere((e) => e.name == value,
          orElse: () => DownloadStatus.notDownloaded);
}

@JsonSerializable()
class Download extends Equatable {
  final String id;
  @JsonKey(name: 'lesson_id')
  final String lessonId;
  @JsonKey(name: 'student_id')
  final String studentId;
  @JsonKey(name: 'local_file_path')
  final String? localFilePath;
  @JsonKey(name: 'download_progress')
  final double downloadProgress;
  @JsonKey(fromJson: DownloadStatus.fromJson, toJson: _statusToJson)
  final DownloadStatus status;
  @JsonKey(name: 'file_size_bytes')
  final int fileSizeByes;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Download({
    required this.id,
    required this.lessonId,
    required this.studentId,
    this.localFilePath,
    this.downloadProgress = 0.0,
    this.status = DownloadStatus.notDownloaded,
    this.fileSizeByes = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Download.fromJson(Map<String, dynamic> json) => _$DownloadFromJson(json);
  Map<String, dynamic> toJson() => _$DownloadToJson(this);

  static String _statusToJson(DownloadStatus s) => s.toJson();

  bool get localFileExists {
    if (localFilePath == null || localFilePath!.isEmpty) return false;
    return File(localFilePath!).existsSync();
  }

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS downloads (
      id TEXT PRIMARY KEY,
      lesson_id TEXT NOT NULL,
      student_id TEXT NOT NULL,
      local_file_path TEXT,
      download_progress REAL DEFAULT 0.0,
      status TEXT DEFAULT 'notDownloaded',
      file_size_bytes INTEGER DEFAULT 0,
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  @override
  List<Object?> get props => [id, lessonId, studentId, status];
}
