import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'cohort.g.dart';

@JsonSerializable()
class Cohort extends Equatable {
  final String id;
  @JsonKey(name: 'district_id')
  final String districtId;
  final String name;
  final String? barangay;
  @JsonKey(name: 'coordinator_id')
  final String? coordinatorId;
  @JsonKey(name: 'academic_year')
  final String? academicYear;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Cohort({
    required this.id,
    required this.districtId,
    required this.name,
    this.barangay,
    this.coordinatorId,
    this.academicYear,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Cohort.fromJson(Map<String, dynamic> json) => _$CohortFromJson(json);
  Map<String, dynamic> toJson() => _$CohortToJson(this);

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS cohorts (
      id TEXT PRIMARY KEY,
      district_id TEXT NOT NULL,
      name TEXT NOT NULL,
      barangay TEXT,
      coordinator_id TEXT,
      academic_year TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'district_id': districtId,
        'name': name,
        'barangay': barangay,
        'coordinator_id': coordinatorId,
        'academic_year': academicYear,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Cohort.fromSqlite(Map<String, dynamic> map) => Cohort(
        id: map['id'] as String,
        districtId: map['district_id'] as String,
        name: map['name'] as String,
        barangay: map['barangay'] as String?,
        coordinatorId: map['coordinator_id'] as String?,
        academicYear: map['academic_year'] as String?,
        isActive: (map['is_active'] as int?) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, districtId, name, barangay];
}
