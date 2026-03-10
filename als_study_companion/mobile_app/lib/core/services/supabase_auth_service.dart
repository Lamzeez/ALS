import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_core/shared_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service for Supabase Authentication operations.
/// Provides auth methods compatible with the existing Firebase interface.
class SupabaseAuthService {
  final SupabaseClient _client;

  /// Web OAuth client ID for Google Sign-In (from GOOGLE_WEB_CLIENT_ID in .env).
  /// Required to obtain an ID token on Android/iOS.
  final String? _googleWebClientId;

  SupabaseAuthService({SupabaseClient? client, String? googleWebClientId})
    : _client = client ?? Supabase.instance.client,
      _googleWebClientId = googleWebClientId;

  /// Current Supabase user.
  User? get currentUser => _client.auth.currentUser;

  /// Auth state stream - emits when auth state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign in with email and password.
  /// Returns the [UserModel] from Postgres 'users' table after authentication.
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) return null;
      return _getUserFromDatabase(res.user!.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Register a new student account.
  ///
  /// Passes all profile fields as [data] (user_metadata) so the
  /// `handle_new_auth_user` database trigger can create the full profile
  /// server-side — even when email confirmation is enabled and the client
  /// has no active session after sign-up.
  /// If a session IS available immediately (email confirmation disabled),
  /// the client also upserts the row to populate any additional fields.
  Future<UserModel> registerStudent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String studentIdNumber,
    required DateTime dateOfBirth,
    required int age,
    required String phoneNumber,
    String? occupation,
    String? lastSchoolAttended,
    String? lastYearAttended,
    String? alsCenterId,
  }) async {
    final now = DateTime.now();
    final fullName = '$firstName $lastName';

    final userMap = {
      'id': '', // filled in after signUp
      'email': email,
      'full_name': fullName,
      'role': UserRole.student.name,
      'als_center_id': alsCenterId,
      'is_active': true,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'first_name': firstName,
      'last_name': lastName,
      'student_id_number': studentIdNumber,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'age': age,
      'phone_number': phoneNumber,
      'occupation': occupation,
      'last_school_attended': lastSchoolAttended,
      'last_year_attended': lastYearAttended,
      'email_verified': false,
      'teacher_verified': false,
    };

    // 1. Create auth account and pass all fields as metadata so the
    //    handle_new_auth_user trigger can create the profile immediately.
    AuthResponse res;
    try {
      res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': UserRole.student.name,
          'first_name': firstName,
          'last_name': lastName,
          'student_id_number': studentIdNumber,
          'phone_number': phoneNumber,
          'occupation': ?occupation,
          'last_school_attended': ?lastSchoolAttended,
          'last_year_attended': ?lastYearAttended,
          'als_center_id': ?alsCenterId,
        },
      );
    } catch (e) {
      rethrow;
    }

    if (res.user == null) throw Exception('Supabase account creation failed.');
    userMap['id'] = res.user!.id;

    // 2. If we have a live session (email confirmation disabled), also upsert
    //    from the client so age and date_of_birth (not in meta trigger) are set.
    if (res.session != null) {
      try {
        await _client.from('users').upsert(userMap);
      } catch (e) {
        // Profile may have been created by the trigger; sign out so the user
        // doesn't get stuck in a broken authenticated state.
        await _client.auth.signOut();
        rethrow;
      }
    }

    return UserModel.fromMap(Map<String, dynamic>.from(userMap));
  }

  /// Register a new teacher account.
  ///
  /// Passes profile fields as [data] (user_metadata) so the
  /// `handle_new_auth_user` trigger creates the profile server-side.
  Future<UserModel> registerTeacher({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String? alsCenterId,
  }) async {
    final now = DateTime.now();
    final fullName = '$firstName $lastName';

    final userMap = {
      'id': '',
      'email': email,
      'full_name': fullName,
      'role': UserRole.teacher.name,
      'als_center_id': alsCenterId,
      'is_active': true,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'email_verified': false,
      'teacher_verified': false,
    };

    AuthResponse res;
    try {
      res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': UserRole.teacher.name,
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
          'als_center_id': ?alsCenterId,
        },
      );
    } catch (e) {
      rethrow;
    }

    if (res.user == null) throw Exception('Supabase account creation failed.');
    userMap['id'] = res.user!.id;

    if (res.session != null) {
      try {
        await _client.from('users').upsert(userMap);
      } catch (e) {
        await _client.auth.signOut();
        rethrow;
      }
    }

    return UserModel.fromMap(Map<String, dynamic>.from(userMap));
  }

  /// Register a new user with email and password.
  /// Creates both a Supabase Auth account and a user record in 'users' table.
  Future<UserModel?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? alsCenterId,
  }) async {
    try {
      final res = await _client.auth.signUp(email: email, password: password);

      if (res.user == null) return null;

      final now = DateTime.now();
      final userMap = {
        'id': res.user!.id,
        'email': email,
        'full_name': fullName,
        'role': role.name,
        'als_center_id': alsCenterId,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Insert into 'users' table
      await _client.from('users').insert(userMap);

      return UserModel.fromMap(Map<String, dynamic>.from(userMap));
    } catch (e) {
      rethrow;
    }
  }

  /// Check if the current user's email is verified via Supabase.
  Future<bool> checkEmailVerified() async {
    // Refresh the session to get the latest email confirmation state.
    try {
      await _client.auth.refreshSession();
    } catch (_) {}
    return _client.auth.currentUser?.emailConfirmedAt != null;
  }

  /// Mark user email as verified in the Supabase users table.
  Future<void> markEmailVerified(String userId) async {
    await _client
        .from('users')
        .update({
          'email_verified': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  /// Approve a teacher account (admin action).
  Future<void> approveTeacher(String userId) async {
    await _client
        .from('users')
        .update({
          'teacher_verified': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  /// Reject / revoke teacher approval.
  Future<void> revokeTeacherApproval(String userId) async {
    await _client
        .from('users')
        .update({
          'teacher_verified': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  /// Send Supabase email verification to current user.
  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user != null && user.email != null) {
      await _client.auth.resend(type: OtpType.signup, email: user.email!);
    }
  }

  /// Sign out from Supabase.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Fetch user document from 'users' table by UID.
  Future<UserModel?> _getUserFromDatabase(String uid) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromMap(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      return null;
    }
  }

  /// Get user model for the currently authenticated user.
  Future<UserModel?> getCurrentUserModel() async {
    final user = currentUser;
    if (user == null) return null;
    return _getUserFromDatabase(user.id);
  }

  /// Update user profile in 'users' table.
  Future<void> updateUserProfile(UserModel user) async {
    await _client.from('users').update(user.toMap()).eq('id', user.id);
  }

  /// Delete user record from 'users' table.
  /// Note: Deleting the Supabase Auth account requires admin privileges.
  Future<void> deleteUserRecord(String uid) async {
    await _client.from('users').delete().eq('id', uid);
  }

  /// Check if email is verified.
  bool get isEmailVerified => currentUser?.emailConfirmedAt != null;

  /// Resend verification email.
  Future<void> resendVerificationEmail() async {
    final user = currentUser;
    if (user != null && user.email != null) {
      await _client.auth.resend(type: OtpType.signup, email: user.email!);
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In (pure Supabase — no Firebase)
  // ---------------------------------------------------------------------------

  /// Sign in with Google using Supabase Auth.
  ///
  /// On mobile (Android/iOS) the native Google Sign-In flow fetches an ID
  /// token which is exchanged with Supabase via [signInWithIdToken].
  /// On web, Supabase handles the full OAuth redirect internally.
  ///
  /// Requires GOOGLE_WEB_CLIENT_ID in .env (Web Application client ID from
  /// Google Cloud Console — NOT the Android client ID).
  ///
  /// [role] is required only for NEW users (first sign-in).
  /// Returns [UserModel] on success, throws on failure.
  Future<UserModel?> signInWithGoogle({required UserRole role}) async {
    // ---- WEB ----------------------------------------------------------------
    if (kIsWeb) {
      await _client.auth.signInWithOAuth(OAuthProvider.google);
      // signInWithOAuth performs a browser redirect; the result comes back
      // through the auth state stream. Return null here — the caller should
      // listen to authStateChanges for the updated session.
      return null;
    }

    // ---- MOBILE (Android / iOS) --------------------------------------------
    if (_googleWebClientId == null || _googleWebClientId.isEmpty) {
      throw Exception(
        'Google Sign-In is not configured. '
        'Set GOOGLE_WEB_CLIENT_ID in your .env file.',
      );
    }

    // serverClientId tells the native SDK which web OAuth client to use so
    // that an ID token (not just an access token) is returned.
    final googleSignIn = GoogleSignIn(serverClientId: _googleWebClientId);
    final googleAccount = await googleSignIn.signIn();
    if (googleAccount == null) return null; // user cancelled

    final googleAuth = await googleAccount.authentication;
    if (googleAuth.idToken == null) {
      throw Exception('Google Sign-In failed: no ID token returned.');
    }

    // Exchange Google ID token for a Supabase session
    final signInRes = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleAuth.idToken!,
      accessToken: googleAuth.accessToken,
    );

    if (signInRes.user == null && _client.auth.currentUser == null) {
      try {
        await googleSignIn.disconnect();
      } catch (_) {}
      throw Exception('Supabase sign-in failed: no user in response.');
    }

    final supabaseUserId = signInRes.user?.id ?? _client.auth.currentUser?.id;

    // Ensure a user record exists in the `users` table
    UserModel? existing;
    if (supabaseUserId != null) {
      existing = await _getUserFromDatabase(supabaseUserId);
    }
    existing ??= await _getUserByEmail(googleAccount.email);
    if (existing != null) return existing;

    // First sign-in — create user row
    final now = DateTime.now();
    final userMap = {
      'id': supabaseUserId,
      'email': googleAccount.email,
      'full_name': googleAccount.displayName ?? '',
      'role': role.name,
      'profile_picture_url': googleAccount.photoUrl,
      'is_active': true,
      'email_verified': true,
      'teacher_verified': role == UserRole.teacher ? false : true,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };
    await _client.from('users').upsert(userMap);
    return UserModel.fromMap(Map<String, dynamic>.from(userMap));
  }

  /// Lookup user by email in the `users` table.
  Future<UserModel?> _getUserByEmail(String email) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromMap(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      return null;
    }
  }
}
