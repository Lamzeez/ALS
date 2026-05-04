import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_models/shared_models.dart';
import 'supabase_client.dart';

class AuthService {
  supa.SupabaseClient? get _client => SupabaseConfig.safeClient;

  supa.Session? get currentSession => _client?.auth.currentSession;
  supa.User? get currentUser => _client?.auth.currentUser;

  bool get isLoggedIn => currentSession != null;

  Stream<supa.AuthState>? get onAuthStateChange =>
      _client?.auth.onAuthStateChange;

  /// 🔍 Get current user profile with retry and proper error handling
  Future<Profile?> getCurrentProfile() async {
    final client = _client;
    if (client == null) return null;

    return SupabaseConfig.withRetry(
      () async {
        final uid = client.auth.currentUser?.id;
        if (uid == null) {
          throw SupabaseApiException(
            'User session not found',
            operationName: 'getCurrentProfile',
            isAuthError: true,
          );
        }

        // Table is 'profiles' in Supabase
        final data =
            await client.from('profiles').select('*').eq('id', uid).maybeSingle();

        if (data == null) return null;

        return Profile.fromJson(data);
      },
      operationName: 'getCurrentProfile',
    );
  }

  /// 🔑 Sign in with email and password with enhanced validation
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw SupabaseApiException('Supabase is not initialized. Cannot sign in.');
    }

    await SupabaseConfig.withRetry(
      () async {
        if (email.trim().isEmpty || password.trim().isEmpty) {
          throw SupabaseApiException('Email and password are required');
        }

        final response = await client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );

        // Check for email verification if required
        final user = response.user;
        if (user != null && user.emailConfirmedAt == null) {
          // User exists but email not verified
          throw SupabaseApiException(
            'EMAIL_NOT_VERIFIED: Please verify your email before signing in.',
            isAuthError: true,
          );
        }

        developer.log('User signed in successfully: ${user?.email}',
            name: 'AuthService');
      },
      operationName: 'signInWithEmail',
    );
  }

  /// 🌎 Native Google Sign-In for mobile (ID Token flow) with deep diagnostics
  Future<void> signInWithGoogle() async {
    final client = _client;
    if (client == null) {
      throw SupabaseApiException('Supabase is not initialized. Cannot sign in.');
    }

    try {
      print('[ALS-AUTH] Initiating Native Google Sign-In...');
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '533484169526-nno4lgasipup831poncgjlqkh5l3hgu4.apps.googleusercontent.com',
        serverClientId: kIsWeb ? null : '533484169526-nno4lgasipup831poncgjlqkh5l3hgu4.apps.googleusercontent.com',
      );
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        print('[ALS-AUTH] Google Sign-In cancelled by user');
        throw SupabaseApiException('Google sign-in was cancelled by user');
      }

      print('[ALS-AUTH] Google user found: ${googleUser.email}. Fetching tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null) {
        print('[ALS-AUTH] CRITICAL: ID Token is null from Google');
        throw SupabaseApiException('No ID Token found from Google authentication');
      }

      print('[ALS-AUTH] Tokens received. Sending to Supabase...');
      await client.auth.signInWithIdToken(
        provider: supa.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      print('[ALS-AUTH] Supabase session established for: ${googleUser.email}');
    } on supa.AuthException catch (e) {
      print('[ALS-AUTH] Supabase Auth Error: ${e.message}');
      throw SupabaseApiException.fromError(e, operationName: 'signInWithGoogle');
    } catch (e) {
      print('[ALS-AUTH] Unexpected Google Sign-In Error: $e');
      if (e.toString().contains('7')) {
         throw SupabaseApiException('Google Sign-In Error (7): Network error or invalid package name/SHA-1.');
      } else if (e.toString().contains('10')) {
         throw SupabaseApiException('Google Sign-In Error (10): Developer error. Check client IDs and SHA-1 in Cloud Console.');
      } else if (e.toString().contains('12500')) {
         throw SupabaseApiException('Google Sign-In Error (12500): Sign-in failed. Check Play Services.');
      }
      throw SupabaseApiException.fromError(e, operationName: 'signInWithGoogle');
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    Object? role,
    String? studentId,
    String? empId,
    String? gender,
    String? birthDate,
    String? lastSchool,
    String? lastYearAttended,
    String? centerLocation,
  }) async {
    final client = _client;
    if (client == null) {
      throw SupabaseApiException('Supabase is not initialized. Cannot sign up.');
    }

    final roleStr = role is UserRole
        ? role.toJson()
        : (role?.toString() ?? UserRole.student.toJson());

    // CRITICAL: Pass all data in metadata so the DB trigger can populate public.profiles
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'full_name': '$firstName $lastName',
        'role': roleStr,
        'student_id_number': studentId,
        'employee_id': empId,
        'gender': gender,
        'date_of_birth': birthDate,
        'last_school_attended': lastSchool,
        'last_year_attended': lastYearAttended,
        'als_center_id': centerLocation,
        'onboarding_completed': true,
      },
    );
    
    final user = response.user;
    if (user != null) {
      // Manually insert into students or teachers table just in case the trigger has a delay
      // Profiles table is handled by trigger (no insert policy for app), 
      // but students/teachers have own_insert policies.
      try {
        if (roleStr == 'student') {
          await client.from('students').upsert({
            'user_id': user.id,
            'student_id_number': studentId,
            'als_center_id': centerLocation,
            'date_of_birth': birthDate,
          });
        } else if (roleStr == 'teacher') {
          await client.from('teachers').upsert({
            'user_id': user.id,
            'employee_id': empId,
            'als_center_id': centerLocation,
          });
        }
      } catch (e) {
        // Log error but don't fail signUp if manual insert fails (trigger might still work)
        developer.log('Manual role-table insert failed (might be handled by trigger): $e', name: 'AuthService');
      }
    }
  }

  /// Called after Google Sign-In to finish onboarding.
  /// Sets role, approval_status, optional IDs, and marks onboarding done.
  Future<void> setUserRole({
    required UserRole role,
    String? studentIdNumber,
    String? empId,
    String? alsCenterId,
  }) async {
    final client = _client;
    if (client == null) return;
    
    final user = client.auth.currentUser;
    if (user == null) return;

    final uid = user.id;
    final metadata = user.userMetadata ?? {};
    final approvalStatus = role == UserRole.teacher ? 'pending' : 'approved';

    // Table is 'profiles', columns are snake_case to match migrations
    await client.from('profiles').upsert({
      'id': uid,
      'full_name': metadata['full_name'] ?? metadata['name'] ?? 'User',
      'email': user.email,
      'role': role.toJson(),
      'approval_status': approvalStatus,
      'onboarding_completed': true,
      if (studentIdNumber != null && studentIdNumber.isNotEmpty) 'student_id_number': studentIdNumber,
      if (empId != null && empId.isNotEmpty) 'employee_id': empId,
      if (alsCenterId != null && alsCenterId.isNotEmpty)
        'als_center_id': alsCenterId,
    }, onConflict: 'id');
  }

  /// Upload a new avatar to Supabase Storage and update the profile record.
  Future<String> uploadAvatar({
    required String uid,
    required List<int> fileBytes,
    required String mimeType,
  }) async {
    final client = _client;
    if (client == null) throw SupabaseApiException('Supabase not initialized');

    final path = '$uid/avatar.jpg';
    // Bucket is 'profile-pictures' as per migrations
    await client.storage.from('profile-pictures').uploadBinary(
          path,
          fileBytes as Uint8List,
          fileOptions: supa.FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
    final url = client.storage.from('profile-pictures').getPublicUrl(path);
    await client.from('profiles').update({'profile_picture_url': url}).eq('id', uid);
    return url;
  }

  /// 📝 Sign out user with proper cleanup and error handling
  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;

    await SupabaseConfig.withRetry(
      () async {
        final userId = client.auth.currentUser?.id;

        await client.auth.signOut();

        developer.log('User signed out successfully: $userId',
            name: 'AuthService');
      },
      operationName: 'signOut',
      maxRetries: 1, // Don't retry signOut multiple times
    );
  }

  /// 📝 Update user profile with validation
  Future<void> updateProfile({required String fullName, String? studentIdNumber}) async {
    final client = _client;
    if (client == null) return;

    await SupabaseConfig.withRetry(
      () async {
        final uid = client.auth.currentUser?.id;
        if (uid == null) {
          throw SupabaseApiException(
            'User not authenticated',
            operationName: 'updateProfile',
            isAuthError: true,
          );
        }

        if (fullName.trim().isEmpty) {
          throw SupabaseApiException('Full name cannot be empty');
        }

        final updateData = {
          'full_name': fullName.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (studentIdNumber != null && studentIdNumber.trim().isNotEmpty) {
          updateData['student_id_number'] = studentIdNumber.trim();
        }

        await client.from('profiles').update(updateData).eq('id', uid);

        developer.log('Profile updated successfully', name: 'AuthService');
      },
      operationName: 'updateProfile',
    );
  }

  /// 🔐 Update user password with proper validation
  Future<void> updatePassword(String newPassword) async {
    final client = _client;
    if (client == null) return;

    await SupabaseConfig.withRetry(
      () async {
        if (newPassword.length < 6) {
          throw SupabaseApiException(
              'Password must be at least 6 characters long');
        }

        await client.auth
            .updateUser(supa.UserAttributes(password: newPassword));

        developer.log('Password updated successfully', name: 'AuthService');
      },
      operationName: 'updatePassword',
    );
  }
}
