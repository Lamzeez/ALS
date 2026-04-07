import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'district.g.dart';

@JsonSerializable()
class District extends Equatable {
  final String id;
  final String name;
  final String region;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const District({
    required this.id,
    required this.name,
    required this.region,
    this.createdAt,
    this.updatedAt,
  });

  factory District.fromJson(Map<String, dynamic> json) =>
      _$DistrictFromJson(json);
  Map<String, dynamic> toJson() => _$DistrictToJson(this);

  /// SQLite CREATE TABLE statement
  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS districts (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      region TEXT NOT NULL,
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  /// Convert to SQLite-compatible map
  Map<String, dynamic> toSqlite() => {
        'id': id,
        'name': name,
        'region': region,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory District.fromSqlite(Map<String, dynamic> map) => District(
        id: map['id'] as String,
        name: map['name'] as String,
        region: map['region'] as String,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, name, region];
}
