import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_services/shared_services.dart';
import 'package:shared_models/shared_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

part 'auth_event.dart';
part 'auth_state.dart';

/// BLoC handling authentication state for the student app.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<supa.AuthState>? _authSubscription;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginWithEmailRequested>(_onLoginWithEmail);
    on<AuthLoginWithGoogleRequested>(_onLoginWithGoogle);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthSignUpWithRoleRequested>(_onSignUpWithRole);
    on<AuthSetRoleRequested>(_onSetRole);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthStateChanged>(_onAuthStateChanged);

    // Listen to auth state changes from Supabase
    _authSubscription = _authService.onAuthStateChange.listen((data) {
      if (data.event == supa.AuthChangeEvent.signedIn) {
        add(AuthStateChanged(isAuthenticated: true));
      } else if (data.event == supa.AuthChangeEvent.signedOut) {
        add(AuthStateChanged(isAuthenticated: false));
      }
    });
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      if (_authService.isLoggedIn) {
        final profile = await _authService.getCurrentProfile();
        emit(_resolveProfileState(profile));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      if (_authService.currentSession != null) {
        emit(AuthAuthenticated());
      } else {
        emit(AuthUnauthenticated());
      }
    }
  }

  /// Determines the correct state for a freshly loaded profile.
  AuthState _resolveProfileState(Profile? profile) {
    if (profile == null) return AuthAuthenticated();
    // New user hasn't chosen a role yet (e.g. Google sign-in).
    if (!profile.onboardingCompleted) {
      return AuthNeedsOnboarding(profile: profile);
    }
    // Teacher registered but not yet approved.
    if (profile.role == UserRole.teacher &&
        profile.approvalStatus == ApprovalStatus.pending) {
      return AuthPendingApproval(profile: profile);
    }
    return AuthAuthenticated(profile: profile);
  }

  Future<void> _onLoginWithEmail(
    AuthLoginWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    // Step 1: authenticate — show an error if credentials are wrong.
    try {
      await _authService.signInWithEmail(
        email: event.email,
        password: event.password,
      );
    } catch (e) {
      emit(AuthError(message: _formatError(e)));
      return;
    }
    // Step 2: load profile — don't block login if this fails.
    try {
      final profile = await _authService.getCurrentProfile();
      emit(_resolveProfileState(profile));
    } catch (_) {
      // Profile fetch failed post-sign-in (e.g. transient DB error).
      // Emit authenticated with no profile; the auth-state listener
      // will retry a full check via AuthCheckRequested.
      emit(const AuthAuthenticated());
    }
  }

  Future<void> _onLoginWithGoogle(
    AuthLoginWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      emit(AuthError(message: _formatError(e)));
      return;
    }
    try {
      final profile = await _authService.getCurrentProfile();
      emit(_resolveProfileState(profile));
    } catch (_) {
      emit(const AuthAuthenticated());
    }
  }

  Future<void> _onSignUp(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signUpWithEmail(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
      );
      emit(AuthSignUpSuccess());
    } catch (e) {
      emit(AuthError(message: _formatError(e)));
    }
  }

  Future<void> _onSignUpWithRole(
    AuthSignUpWithRoleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signUpWithEmail(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        role: event.role,
        studentId: event.studentId,
        empId: event.empId,
        gender: event.gender,
        birthDate: event.birthDate,
        lastSchool: event.lastSchool,
        lastYearAttended: event.lastYearAttended,
        centerLocation: event.centerLocation,
      );
      emit(AuthSignUpSuccess());
    } catch (e) {
      emit(AuthError(message: _formatError(e)));
    }
  }

  Future<void> _onSetRole(
    AuthSetRoleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.setUserRole(
        role: event.role,
        lrn: event.lrn,
        empId: event.empId,
      );
      final profile = await _authService.getCurrentProfile();
      emit(_resolveProfileState(profile));
    } catch (e) {
      emit(AuthError(message: _formatError(e)));
    }
  }

  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signOut();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: _formatError(e)));
    }
  }

  void _onAuthStateChanged(
    AuthStateChanged event,
    Emitter<AuthState> emit,
  ) {
    if (event.isAuthenticated) {
      add(AuthCheckRequested());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  String _formatError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'Incorrect email or password. Please try again.';
    } else if (msg.contains('User already registered')) {
      return 'This email is already registered. Try logging in instead.';
    } else if (msg.contains('cancelled')) {
      return 'Sign-in was cancelled.';
    } else if (msg.contains('network')) {
      return 'No internet connection. Please try again when online.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
