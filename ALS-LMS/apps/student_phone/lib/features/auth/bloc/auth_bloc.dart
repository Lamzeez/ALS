import 'dart:async';
import 'dart:developer' as developer;
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
  final BiometricService _biometricService;
  StreamSubscription<supa.AuthState>? _authSubscription;

  AuthBloc({
    required AuthService authService,
    required BiometricService biometricService,
  })  : _authService = authService,
        _biometricService = biometricService,
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
      if (data.event == supa.AuthChangeEvent.signedIn ||
          data.event == supa.AuthChangeEvent.tokenRefreshed) {
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
  AuthState _resolveProfileState(Profile? profile, {UserRole? preferredRole}) {
    if (profile == null) {
      final user = _authService.currentUser;
      if (user != null) {
        // Fresh sign-in, no profile yet. Auto-create skeleton for onboarding screen.
        final metadata = user.userMetadata ?? {};
        return AuthNeedsOnboarding(
          profile: Profile(
            id: user.id,
            fullName: metadata['full_name'] ?? metadata['name'] ?? 'User',
            email: user.email,
            role: preferredRole ?? UserRole.student,
            onboardingCompleted: false,
            approvalStatus: ApprovalStatus.approved,
          ),
        );
      }
      return AuthUnauthenticated();
    }

    // New user hasn't finished onboarding details.
    if (!profile.onboardingCompleted) {
      if (preferredRole != null && profile.role != preferredRole) {
        // Update profile with the preferred role they just picked on RegisterScreen
        return AuthNeedsOnboarding(
          profile: Profile(
            id: profile.id,
            role: preferredRole,
            fullName: profile.fullName,
            email: profile.email,
            onboardingCompleted: false,
            approvalStatus: profile.approvalStatus,
          ),
        );
      }
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
      final profile = await _authService.getCurrentProfile();
      emit(_resolveProfileState(profile, preferredRole: event.preferredRole));
    } catch (e) {
      if (e is supa.AuthException || e is SupabaseApiException) {
        emit(AuthError(message: _formatError(e)));
      } else {
        // This might happen if user cancelled or profile fetch failed
        // but session exists. AuthCheckRequested will handle it.
        emit(const AuthAuthenticated());
      }
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
        districtId: event.districtId,
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
      // 🔒 SECURITY: Clear biometric data before logout for shared device security
      await _biometricService.clearBiometricDataOnLogout();

      await _authService.signOut();

      developer.log('User logged out successfully', name: 'AuthBloc');
      emit(AuthUnauthenticated());
    } catch (e, stackTrace) {
      developer.log('Logout failed',
          error: e, stackTrace: stackTrace, name: 'AuthBloc', level: 900);
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
    final msg = error.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    } else if (msg.contains('user already registered') ||
        msg.contains('email_exists')) {
      return 'This email is already registered. Try logging in instead.';
    } else if (msg.contains('cancelled')) {
      return 'Sign-in was cancelled.';
    } else if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Please try again when online.';
    } else if (msg.contains('jwt') ||
        msg.contains('token') ||
        msg.contains('not_authorized') ||
        msg.contains('refresh_token_not_found')) {
      return 'Your session has expired. Please sign in again.';
    } else if (msg.contains('email_not_verified') ||
        msg.contains('email not verified')) {
      return 'Please verify your email before signing in.';
    }
    return 'An unexpected error occurred: ${error.toString().split("\n").first}. Please try again.';
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
