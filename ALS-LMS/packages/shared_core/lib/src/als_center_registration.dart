import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'enums.dart';

part 'als_center_registration.g.dart';

@JsonSerializable()
class AlsCenterRegistration extends Equatable {
  final String id;
  @JsonKey(name: 'center_name')
  final String centerName;
  final String address;
  final String region;
  @JsonKey(name: 'contact_number')
  final String contactNumber;
  @JsonKey(name: 'admin_full_name')
  final String adminFullName;
  @JsonKey(name: 'admin_email')
  final String adminEmail;
  @JsonKey(fromJson: CenterRegistrationStatus.fromJson)
  final CenterRegistrationStatus status;
  @JsonKey(name: 'rejection_reason')
  final String? rejectionReason;
  @JsonKey(name: 'reviewed_by')
  final String? reviewedBy;
  @JsonKey(name: 'reviewed_at')
  final DateTime? reviewedAt;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const AlsCenterRegistration({
    required this.id,
    required this.centerName,
    required this.address,
    required this.region,
    required this.contactNumber,
    required this.adminFullName,
    required this.adminEmail,
    this.status = CenterRegistrationStatus.pending,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    this.createdAt,
  });

  factory AlsCenterRegistration.fromJson(Map<String, dynamic> json) => _$AlsCenterRegistrationFromJson(json);
  Map<String, dynamic> toJson() => _$AlsCenterRegistrationToJson(this);

  @override
  List<Object?> get props => [id, centerName, adminEmail, status];
}
