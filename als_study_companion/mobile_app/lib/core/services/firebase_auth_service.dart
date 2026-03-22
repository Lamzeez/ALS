import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_core/shared_core.dart' as core;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Service for Firebase Authentication operations.
/// Replaces SupabaseAuthService for credential storage and Gmail validation.
class FirebaseAuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  /// Current Firebase user.
  fb.User? get currentUser => _auth.currentUser;

  /// Auth state stream.
  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password.
  Future<core.UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return null;
      return _getUserFromDatabase(credential.user!.uid);
    } catch (e) {
      rethrow;
    }
  }

  /// Register a new student account using Firebase Auth.
  Future<core.UserModel> registerStudent({
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
    final fullName = '$firstName $lastName';
    print('Firebase: Starting student registration for $email');

    try {
      // 1. Create Firebase Auth account
      print('Firebase: Creating Auth account...');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Firebase account creation failed: User is null.');
      }

      final uid = credential.user!.uid;
      print('Firebase: Account created. UID: $uid');

      // 2. Create profile in Supabase database
      print('Supabase: Creating public.users profile...');
      final userMap = {
        'id': uid,
        'email': email,
        'full_name': fullName,
        'role': core.UserRole.student.name,
        'als_center_id': alsCenterId,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
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

      await _supabase.from('users').upsert(userMap);
      print('Supabase: Profile created successfully.');
      
      // 3. Send email verification
      print('Firebase: Sending verification email...');
      await credential.user!.sendEmailVerification();
      print('Firebase: Verification email sent.');

      return core.UserModel.fromMap(Map<String, dynamic>.from(userMap));
    } catch (e) {
      print('Firebase/Supabase Registration ERROR: $e');
      rethrow;
    }
  }

  /// Register a new teacher account using Firebase Auth.
  Future<core.UserModel> registerTeacher({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String employeeId,
    String? alsCenterId,
  }) async {
    final fullName = '$firstName $lastName';
    print('Firebase: Starting teacher registration for $email');

    try {
      print('Firebase: Creating Auth account...');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Firebase account creation failed: User is null.');
      }

      final uid = credential.user!.uid;
      print('Firebase: Account created. UID: $uid');

      print('Supabase: Creating public.users profile...');
      final userMap = {
        'id': uid,
        'email': email,
        'full_name': fullName,
        'role': core.UserRole.teacher.name,
        'als_center_id': alsCenterId,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'student_id_number': employeeId, // Mapping employee ID to student_id_number column for now or we can use a generic field
        'email_verified': false,
        'teacher_verified': false,
      };

      await _supabase.from('users').upsert(userMap);
      print('Supabase: Profile created successfully.');
      
      print('Firebase: Sending verification email...');
      await credential.user!.sendEmailVerification();
      print('Firebase: Verification email sent.');

      return core.UserModel.fromMap(Map<String, dynamic>.from(userMap));
    } catch (e) {
      print('Firebase/Supabase Registration ERROR: $e');
      rethrow;
    }
  }

  /// Sign in with Google using Firebase Auth.
  Future<core.UserModel?> signInWithGoogle({required core.UserRole role}) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fb.UserCredential userCredential = await _auth.signInWithCredential(credential);
      final fb.User? firebaseUser = userCredential.user;

      if (firebaseUser == null) return null;

      // Check if user exists in Supabase
      core.UserModel? existing = await _getUserFromDatabase(firebaseUser.uid);
      if (existing != null) return existing;

      // Create new user record
      final now = DateTime.now();
      final userMap = {
        'id': firebaseUser.uid,
        'email': firebaseUser.email,
        'full_name': firebaseUser.displayName ?? '',
        'role': role.name,
        'profile_picture_url': firebaseUser.photoURL,
        'is_active': true,
        'email_verified': true,
        'teacher_verified': role == core.UserRole.teacher ? false : true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await _supabase.from('users').upsert(userMap);
      return core.UserModel.fromMap(Map<String, dynamic>.from(userMap));
    } catch (e) {
      rethrow;
    }
  }

  /// Check if the current user's email is verified via Firebase.
  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    }
    return false;
  }

  /// Mark user email as verified in the Supabase users table.
  Future<void> markEmailVerified(String userId) async {
    await _supabase
        .from('users')
        .update({
          'email_verified': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }

  /// Send password reset email via Firebase.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Send email verification via Firebase.
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Sign out.
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  /// Fetch user document from Supabase 'users' table by UID.
  Future<core.UserModel?> _getUserFromDatabase(String uid) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (response == null) return null;
      return core.UserModel.fromMap(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      return null;
    }
  }

  /// Get user model for the currently authenticated user.
  Future<core.UserModel?> getCurrentUserModel() async {
    final user = currentUser;
    if (user == null) return null;
    return _getUserFromDatabase(user.uid);
  }
}
