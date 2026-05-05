import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'learning_center.g.dart';

@JsonSerializable()
class LearningCenter extends Equatable {
  final String id;
  final String name;
  final String address;
  final String region;
  final String? province;
  @JsonKey(name: 'contact_number')
  final String? contactNumber;
  @JsonKey(name: 'head_teacher_id')
  final String? headTeacherId;
  @JsonKey(name: 'registration_id')
  final String? registrationId;
  @JsonKey(name: 'center_admin_id')
  final String? centerAdminId;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const LearningCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.region,
    this.province,
    this.contactNumber,
    this.headTeacherId,
    this.registrationId,
    this.centerAdminId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory LearningCenter.fromJson(Map<String, dynamic> json) => _$LearningCenterFromJson(json);
  Map<String, dynamic> toJson() => _$LearningCenterToJson(this);

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS als_centers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      address TEXT NOT NULL,
      region TEXT NOT NULL,
      province TEXT,
      contact_number TEXT,
      head_teacher_id TEXT,
      registration_id TEXT,
      center_admin_id TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'name': name,
        'address': address,
        'region': region,
        'province': province,
        'contact_number': contactNumber,
        'head_teacher_id': headTeacherId,
        'registration_id': registrationId,
        'center_admin_id': centerAdminId,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name, region];
}
