part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Profile? profile;

  const AuthAuthenticated({this.profile});

  @override
  List<Object?> get props => [profile];
}

class AuthUnauthenticated extends AuthState {}

class AuthSignUpSuccess extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Teacher registered but not yet approved by center admin.
class AuthPendingApproval extends AuthState {
  final Profile profile;
  const AuthPendingApproval({required this.profile});
  @override
  List<Object?> get props => [profile];
}

/// User signed in (usually via Google) but hasn't picked a role yet.
class AuthNeedsOnboarding extends AuthState {
  final Profile profile;
  const AuthNeedsOnboarding({required this.profile});
  @override
  List<Object?> get props => [profile];
}
