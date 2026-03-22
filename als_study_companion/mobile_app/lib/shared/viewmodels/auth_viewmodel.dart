import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_core/shared_core.dart';
import 'package:backend_services/backend_services.dart' show SupabaseStorageService;
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/secure_credential_storage.dart';
import '../../core/database/database_helper.dart';

/// Base ViewModel class for authentication state management.
///
/// Follows MVVM pattern — View → ViewModel → Service → DataSource.
class AuthViewModel extends ChangeNotifier {
  final FirebaseAuthService _authService;
  final DatabaseHelper _db;
  final BiometricService _biometricService;
  final SecureCredentialStorage _credStorage;
  final SupabaseStorageService _storageService = SupabaseStorageService();

  AuthViewModel({
    required FirebaseAuthService authService,
    DatabaseHelper? db,
    BiometricService? biometricService,
    SecureCredentialStorage? credentialStorage,
  }) : _authService = authService,
       _db = db ?? DatabaseHelper.instance,
       _biometricService = biometricService ?? BiometricService(),
       _credStorage = credentialStorage ?? SecureCredentialStorage() {
    _initAuthListener();
    _initBiometricState();
    fetchCenters(); // Fetch centers on init
  }

  UserModel? _currentUser;
  UserRole? _currentRole;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;
  bool _emailVerified = false;
  List<AlsCenterModel> _centers = [];

  // Biometric state
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  String _biometricLabel = 'Biometrics';

  UserModel? get currentUser => _currentUser;
  UserRole? get currentRole => _currentRole;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _isAuthenticated;
  bool get emailVerified => _emailVerified;
  List<AlsCenterModel> get centers => _centers;

  /// Whether the device supports biometric authentication.
  bool get isBiometricAvailable => _isBiometricAvailable;

  /// Whether biometric auto-fill is currently set up and enabled.
  bool get isBiometricEnabled => _isBiometricEnabled;

  /// Human-readable label for the available biometric type (e.g. "Face ID").
  String get biometricLabel => _biometricLabel;

  /// True when the user is logged in but their email is not verified.
  bool get needsEmailVerification =>
      _isAuthenticated && _currentUser != null && !_currentUser!.emailVerified;

  /// True when a teacher is logged in but not yet approved by admin.
  bool get needsTeacherApproval =>
      _isAuthenticated &&
      _currentUser != null &&
      _currentUser!.role == UserRole.teacher &&
      !_currentUser!.teacherVerified;

  // ---------------------------------------------------------------------------
  // Data Fetching
  // ---------------------------------------------------------------------------

  Future<void> fetchCenters() async {
    debugPrint('Fetching ALS centers from Supabase...');
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('als_centers').select();
      debugPrint('Supabase response: $response');
      
      final data = List<Map<String, dynamic>>.from(response);
      _centers = data.map((m) => AlsCenterModel.fromMap(m)).toList();
      debugPrint('Loaded ${_centers.length} centers.');
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching centers: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Profile Update
  // ---------------------------------------------------------------------------

  Future<bool> updateProfilePicture(Uint8List imageBytes) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Upload to Supabase Storage
      final photoUrl = await _storageService.uploadProfileImage(
        userId: _currentUser!.id,
        imageBytes: imageBytes,
      );

      // 2. Update Supabase User Table
      final supabase = Supabase.instance.client;
      await supabase.from('users').update({
        'profile_picture_url': photoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _currentUser!.id);

      // 3. Update local state
      _currentUser = _currentUser!.copyWith(profilePictureUrl: photoUrl);
      await _cacheUserLocally(_currentUser!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile picture: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Verification methods
  // ---------------------------------------------------------------------------

  /// Refresh the current user's email verification status.
  Future<bool> checkEmailVerified() async {
    final verified = await _authService.checkEmailVerified();
    _emailVerified = verified;
    if (verified && _currentUser != null && !_currentUser!.emailVerified) {
      await _authService.markEmailVerified(_currentUser!.id);
      _currentUser = _currentUser!.copyWith(emailVerified: true);
    }
    notifyListeners();
    return verified;
  }

  /// Resend verification email via Firebase.
  Future<void> sendEmailVerification() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendEmailVerification();
    } catch (e) {
      _errorMessage = 'Failed to send verification email: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Biometric helpers
  // ---------------------------------------------------------------------------

  Future<void> _initBiometricState() async {
    _isBiometricAvailable = await _biometricService.isAvailable();
    _isBiometricEnabled =
        _isBiometricAvailable && await _credStorage.isEnabled();
    if (_isBiometricAvailable) {
      _biometricLabel = await _biometricService.getBiometricLabel();
    }
    notifyListeners();
  }

  Future<bool> setupBiometric({
    required String email,
    required String password,
  }) async {
    final authenticated = await _biometricService.authenticate(
      reason: 'Scan to enable $_biometricLabel login',
    );
    if (!authenticated) return false;

    await _credStorage.saveCredentials(email: email, password: password);
    _isBiometricEnabled = true;
    notifyListeners();
    return true;
  }

  Future<void> disableBiometric() async {
    await _credStorage.clearCredentials();
    _isBiometricEnabled = false;
    notifyListeners();
  }

  Future<({String email, String password})?> biometricAutoFill() async {
    if (!_isBiometricEnabled) return null;

    final authenticated = await _biometricService.authenticate(
      reason: 'Authenticate to auto-fill your credentials',
    );
    if (!authenticated) return null;

    return await _credStorage.getCredentials();
  }

  Future<void> refreshBiometricState() async {
    _isBiometricEnabled =
        _isBiometricAvailable && await _credStorage.isEnabled();
    notifyListeners();
  }

  void _initAuthListener() {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        await _loadCurrentUser();
      } else {
        _currentUser = null;
        _currentRole = null;
        _isAuthenticated = false;
        notifyListeners();
      }
    });
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUserModel();
      if (user != null) {
        _currentUser = user;
        _currentRole = user.role;
        _isAuthenticated = true;
        _emailVerified = user.emailVerified;
        await _cacheUserLocally(user);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );

      if (user != null) {
        _currentUser = user;
        _currentRole = user.role;
        _isAuthenticated = true;
        _emailVerified = user.emailVerified;
        await _cacheUserLocally(user);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid credentials';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = _formatErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      if (_currentUser != null) {
        await _db.delete(DbConstants.tableUsers, _currentUser!.id);
      }
      _currentUser = null;
      _currentRole = null;
      _isAuthenticated = false;
    } catch (e) {
      _errorMessage = 'Error signing out: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> registerStudent({
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.registerStudent(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        studentIdNumber: studentIdNumber,
        dateOfBirth: dateOfBirth,
        age: age,
        phoneNumber: phoneNumber,
        occupation: occupation,
        lastSchoolAttended: lastSchoolAttended,
        lastYearAttended: lastYearAttended,
        alsCenterId: alsCenterId,
      );

      _currentUser = user;
      _currentRole = UserRole.student;
      _isAuthenticated = _authService.currentUser != null;
      _emailVerified = user.emailVerified;
      await _cacheUserLocally(user);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthViewModel: registerStudent ERROR: $e');
      _errorMessage = _formatErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerTeacher({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String employeeId,
    String? alsCenterId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.registerTeacher(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        employeeId: employeeId,
        alsCenterId: alsCenterId,
      );

      _currentUser = user;
      _currentRole = UserRole.teacher;
      _isAuthenticated = _authService.currentUser != null;
      _emailVerified = user.emailVerified;
      await _cacheUserLocally(user);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthViewModel: registerTeacher ERROR: $e');
      _errorMessage = _formatErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      _errorMessage = 'Failed to send password reset email: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _cacheUserLocally(UserModel user) async {
    try {
      await _db.insert(DbConstants.tableUsers, user.toMap());
    } catch (e) {
      debugPrint('Error caching user locally: $e');
    }
  }

  String _formatErrorMessage(String error) {
    if (error.contains('user-not-found') || error.contains('wrong-password') || error.contains('invalid-credential')) {
      return 'Invalid email or password';
    } else if (error.contains('email-already-in-use')) {
      return 'An account with this email already exists';
    } else if (error.contains('weak-password')) {
      return 'The password is too weak';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your connection';
    }
    return 'Error: $error';
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signInWithGoogle({required UserRole role}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle(role: role);

      if (user != null) {
        _currentUser = user;
        _currentRole = user.role;
        _isAuthenticated = true;
        await _cacheUserLocally(user);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Google Sign-In failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
