part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginWithEmailRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginWithEmailRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthLoginWithGoogleRequested extends AuthEvent {
  final UserRole? preferredRole;

  const AuthLoginWithGoogleRequested({this.preferredRole});

  @override
  List<Object?> get props => [preferredRole];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  @override
  List<Object?> get props => [email, password, firstName, lastName];
}

class AuthSignUpWithRoleRequested extends AuthEvent {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final UserRole role;
  final String? studentId;
  final String? empId;
  final String? gender;
  final String? birthDate;
  final String? lastSchool;
  final String? lastYearAttended;
  final String? centerLocation;

  const AuthSignUpWithRoleRequested({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.studentId,
    this.empId,
    this.gender,
    this.birthDate,
    this.lastSchool,
    this.lastYearAttended,
    this.centerLocation,
  });

  @override
  List<Object?> get props =>
      [email, password, firstName, lastName, role, studentId, empId, gender];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthStateChanged extends AuthEvent {
  final bool isAuthenticated;

  const AuthStateChanged({required this.isAuthenticated});

  @override
  List<Object?> get props => [isAuthenticated];
}

/// Fired from OnboardingScreen after the user picks their role post Google sign-in.
class AuthSetRoleRequested extends AuthEvent {
  final UserRole role;
  final String? studentIdNumber;
  final String? empId;
  final String? alsCenterId;

  const AuthSetRoleRequested({
    required this.role,
    this.studentIdNumber,
    this.empId,
    this.alsCenterId,
  });

  @override
  List<Object?> get props => [role, studentIdNumber, empId, alsCenterId];
}
