import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'profile.g.dart';

@JsonSerializable()
class Profile extends Equatable {
  final String id;
  @JsonKey(fromJson: UserRole.fromJson, toJson: _roleToJson)
  final UserRole role;
  final String? lrn;
  @JsonKey(name: 'full_name')
  final String fullName;
  final String? email;
  @JsonKey(name: 'district_id')
  final String? districtId;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'phone_number')
  final String? phoneNumber;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'approval_status', fromJson: ApprovalStatus.fromJson)
  final ApprovalStatus approvalStatus;
  @JsonKey(name: 'onboarding_completed')
  final bool onboardingCompleted;
  @JsonKey(name: 'employee_id')
  final String? employeeId;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Profile({
    required this.id,
    required this.role,
    this.lrn,
    required this.fullName,
    this.email,
    this.districtId,
    this.avatarUrl,
    this.deviceId,
    this.phoneNumber,
    this.isActive = true,
    this.approvalStatus = ApprovalStatus.approved,
    this.onboardingCompleted = true,
    this.employeeId,
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileToJson(this);

  static String _roleToJson(UserRole role) => role.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS profiles (
      id TEXT PRIMARY KEY,
      role TEXT NOT NULL DEFAULT 'student',
      lrn TEXT UNIQUE,
      full_name TEXT NOT NULL,
      email TEXT,
      district_id TEXT,
      avatar_url TEXT,
      device_id TEXT,
      phone_number TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'role': role.toJson(),
        'lrn': lrn,
        'full_name': fullName,
        'email': email,
        'district_id': districtId,
        'avatar_url': avatarUrl,
        'device_id': deviceId,
        'phone_number': phoneNumber,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Profile.fromSqlite(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        role: UserRole.fromJson(map['role'] as String),
        lrn: map['lrn'] as String?,
        fullName: map['full_name'] as String,
        email: map['email'] as String?,
        districtId: map['district_id'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        deviceId: map['device_id'] as String?,
        phoneNumber: map['phone_number'] as String?,
        isActive: (map['is_active'] as int?) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, role, fullName, email];
}
