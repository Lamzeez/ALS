import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'session.g.dart';

@JsonSerializable()
class Session extends Equatable {
  final String id;
  @JsonKey(name: 'teacher_id')
  final String teacherId;
  final String title;
  final String? description;
  @JsonKey(name: 'scheduled_at')
  final DateTime scheduledAt;
  @JsonKey(name: 'duration_minutes')
  final int durationMinutes;
  final String? location;
  @JsonKey(fromJson: SessionStatus.fromJson, toJson: _statusToJson)
  final SessionStatus status;
  @JsonKey(name: 'sync_status')
  final String syncStatus;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Session({
    required this.id,
    required this.teacherId,
    required this.title,
    this.description,
    required this.scheduledAt,
    this.durationMinutes = 60,
    this.location,
    this.status = SessionStatus.scheduled,
    this.syncStatus = 'synced',
    this.createdAt,
    this.updatedAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
  Map<String, dynamic> toJson() => _$SessionToJson(this);

  static String _statusToJson(SessionStatus s) => s.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      teacher_id TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      scheduled_at TEXT NOT NULL,
      duration_minutes INTEGER DEFAULT 60,
      location TEXT,
      status TEXT DEFAULT 'scheduled',
      sync_status TEXT DEFAULT 'synced',
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  @override
  List<Object?> get props => [id, teacherId, title, scheduledAt];
}
