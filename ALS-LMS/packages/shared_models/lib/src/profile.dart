import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'profile.g.dart';

@JsonSerializable()
class Profile extends Equatable {
  final String id;
  @JsonKey(fromJson: UserRole.fromJson, toJson: _roleToJson)
  final UserRole role;
  
  @JsonKey(name: 'student_id_number')
  final String? studentIdNumber;
  
  @JsonKey(name: 'full_name')
  final String fullName;
  
  @JsonKey(name: 'first_name')
  final String? firstName;
  
  @JsonKey(name: 'last_name')
  final String? lastName;

  final String? email;
  
  @JsonKey(name: 'als_center_id')
  final String? alsCenterId;
  
  @JsonKey(name: 'profile_picture_url')
  final String? profilePictureUrl;
  
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
    this.studentIdNumber,
    required this.fullName,
    this.firstName,
    this.lastName,
    this.email,
    this.alsCenterId,
    this.profilePictureUrl,
    this.deviceId,
    this.phoneNumber,
    this.isActive = true,
    this.approvalStatus = ApprovalStatus.approved,
    this.onboardingCompleted = false,
    this.employeeId,
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileToJson(this);

  static String _roleToJson(UserRole role) => role.toJson();

  static const String createTableSQL = '''
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      role TEXT NOT NULL DEFAULT 'student',
      student_id_number TEXT UNIQUE,
      full_name TEXT NOT NULL,
      first_name TEXT,
      last_name TEXT,
      email TEXT,
      als_center_id TEXT,
      profile_picture_url TEXT,
      device_id TEXT,
      phone_number TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      approval_status TEXT NOT NULL DEFAULT 'approved',
      onboarding_completed INTEGER NOT NULL DEFAULT 0,
      employee_id TEXT,
      created_at TEXT,
      updated_at TEXT
    )
  ''';

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'role': role.toJson(),
        'student_id_number': studentIdNumber,
        'full_name': fullName,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'als_center_id': alsCenterId,
        'profile_picture_url': profilePictureUrl,
        'device_id': deviceId,
        'phone_number': phoneNumber,
        'is_active': isActive ? 1 : 0,
        'approval_status': approvalStatus.toJson(),
        'onboarding_completed': onboardingCompleted ? 1 : 0,
        'employee_id': employeeId,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  factory Profile.fromSqlite(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        role: UserRole.fromJson(map['role'] as String),
        studentIdNumber: map['student_id_number'] as String?,
        fullName: map['full_name'] as String,
        firstName: map['first_name'] as String?,
        lastName: map['last_name'] as String?,
        email: map['email'] as String?,
        alsCenterId: map['als_center_id'] as String?,
        profilePictureUrl: map['profile_picture_url'] as String?,
        deviceId: map['device_id'] as String?,
        phoneNumber: map['phone_number'] as String?,
        isActive: (map['is_active'] as int?) == 1,
        approvalStatus: ApprovalStatus.fromJson(
            map['approval_status'] as String? ?? 'approved'),
        onboardingCompleted: (map['onboarding_completed'] as int?) == 1,
        employeeId: map['employee_id'] as String?,
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
