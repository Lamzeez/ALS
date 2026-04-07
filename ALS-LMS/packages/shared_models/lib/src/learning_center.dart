import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'learning_center.g.dart';

@JsonSerializable()
class LearningCenter extends Equatable {
  final String id;
  final String name;
  final String region;
  final String? province;
  @JsonKey(name: 'physical_address')
  final String? physicalAddress;
  @JsonKey(name: 'district_id')
  final String? districtId;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const LearningCenter({
    required this.id,
    required this.name,
    required this.region,
    this.province,
    this.physicalAddress,
    this.districtId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory LearningCenter.fromJson(Map<String, dynamic> json) =>
      _$LearningCenterFromJson(json);
  Map<String, dynamic> toJson() => _$LearningCenterToJson(this);

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS learning_centers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      region TEXT NOT NULL,
      province TEXT,
      physical_address TEXT,
      district_id TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'name': name,
        'region': region,
        'province': province,
        'physical_address': physicalAddress,
        'district_id': districtId,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory LearningCenter.fromSqlite(Map<String, dynamic> map) =>
      LearningCenter(
        id: map['id'] as String,
        name: map['name'] as String,
        region: map['region'] as String,
        province: map['province'] as String?,
        physicalAddress: map['physical_address'] as String?,
        districtId: map['district_id'] as String?,
        isActive: (map['is_active'] as int?) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, name, region, province];
}
