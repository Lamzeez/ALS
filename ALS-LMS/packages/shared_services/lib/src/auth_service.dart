import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:shared_models/shared_models.dart';
import 'supabase_client.dart';

class AuthService {
  supa.SupabaseClient get _client => SupabaseConfig.client;

  supa.Session? get currentSession => _client.auth.currentSession;

  bool get isLoggedIn => currentSession != null;

  Stream<supa.AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  Future<Profile?> getCurrentProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final data = await _client.from('profiles').select().eq('id', uid).single();
    return Profile.fromJson(data);
  }

  Future<void> signInWithEmail(
      {required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      supa.OAuthProvider.google,
      redirectTo: 'com.als.mobile_app://login-callback',
    );
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    Object? role,
    String? studentId,
    String? empId,
    String? gender,
    String? birthDate,
    String? lastSchool,
    String? lastYearAttended,
    String? centerLocation,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    final uid = response.user?.id;
    if (uid != null) {
      final roleStr = role is UserRole
          ? role.toJson()
          : (role?.toString() ?? UserRole.student.toJson());
      // Teachers start as pending; everyone else is approved.
      final approvalStatus =
          roleStr == UserRole.teacher.toJson() ? 'pending' : 'approved';
      await _client.from('profiles').update({
        'role': roleStr,
        'approval_status': approvalStatus,
        'onboarding_completed': true,
        if (studentId != null && studentId.isNotEmpty) 'lrn': studentId,
      }).eq('id', uid);
    }
  }

  /// Called after Google Sign-In to finish onboarding.
  /// Sets role, approval_status, optional LRN, and marks onboarding done.
  Future<void> setUserRole({
    required UserRole role,
    String? lrn,
    String? empId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    final approvalStatus = role == UserRole.teacher ? 'pending' : 'approved';
    await _client.from('profiles').update({
      'role': role.toJson(),
      'approval_status': approvalStatus,
      'onboarding_completed': true,
      if (lrn != null && lrn.isNotEmpty) 'lrn': lrn,
    }).eq('id', uid);
  }

  /// Upload a new avatar to Supabase Storage and update the profile record.
  Future<String> uploadAvatar({
    required String uid,
    required List<int> fileBytes,
    required String mimeType,
  }) async {
    final path = '$uid/avatar.jpg';
    await _client.storage.from('profile-avatars').uploadBinary(
          path,
          fileBytes as Uint8List,
          fileOptions: supa.FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
    final url = _client.storage.from('profile-avatars').getPublicUrl(path);
    await _client.from('profiles').update({'avatar_url': url}).eq('id', uid);
    return url;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> updateProfile({required String fullName, String? lrn}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('profiles').update({
      'full_name': fullName,
      if (lrn != null && lrn.isNotEmpty) 'lrn': lrn,
    }).eq('id', uid);
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(supa.UserAttributes(password: newPassword));
  }
}
