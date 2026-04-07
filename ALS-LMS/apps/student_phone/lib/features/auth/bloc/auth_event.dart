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

class AuthLoginWithGoogleRequested extends AuthEvent {}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.fullName,
  });

  @override
  List<Object?> get props => [email, password, fullName];
}

class AuthSignUpWithRoleRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
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
    required this.fullName,
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
      [email, password, fullName, role, studentId, empId, gender];
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
  final String? lrn;
  final String? empId;

  const AuthSetRoleRequested({
    required this.role,
    this.lrn,
    this.empId,
  });

  @override
  List<Object?> get props => [role, lrn, empId];
}
