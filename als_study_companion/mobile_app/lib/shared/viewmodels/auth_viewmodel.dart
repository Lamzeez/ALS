import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import '../../core/services/supabase_auth_service.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/secure_credential_storage.dart';
import '../../core/local/local_database.dart';
import 'package:drift/drift.dart' as drift;

/// Base ViewModel class for authentication state management.
///
/// Follows MVVM pattern — View → ViewModel → Service → DataSource.
class AuthViewModel extends ChangeNotifier {
  final SupabaseAuthService _authService;
  final LocalDatabase _localDb;
  final BiometricService _biometricService;
  final SecureCredentialStorage _credStorage;

  AuthViewModel({
    required SupabaseAuthService authService,
    required LocalDatabase localDb,
    BiometricService? biometricService,
    SecureCredentialStorage? credentialStorage,
  }) : _authService = authService,
       _localDb = localDb,
       _biometricService = biometricService ?? BiometricService(),
       _credStorage = credentialStorage ?? SecureCredentialStorage() {
    _initAuthListener();
    _initBiometricState();
  }

  UserModel? _currentUser;
  UserRole? _currentRole;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;
  bool _emailVerified = false;

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
  // Biometric helpers
  // ---------------------------------------------------------------------------

  /// Loads device biometric availability and current enabled state.
  /// Called once on construction so the login UI can show/hide the
  /// auto-fill button immediately.
  Future<void> _initBiometricState() async {
    _isBiometricAvailable = await _biometricService.isAvailable();
    _isBiometricEnabled =
        _isBiometricAvailable && await _credStorage.isEnabled();
    if (_isBiometricAvailable) {
      _biometricLabel = await _biometricService.getBiometricLabel();
    }
    notifyListeners();
  }

  /// Prompts a biometric scan, then — on success — securely stores [email]
  /// and [password] so they can be auto-filled later.
  ///
  /// Call this from the post-registration [BiometricSetupView] after the user
  /// confirms they want to enable biometric login.
  ///
  /// Returns [true] when the scan succeeded and credentials were saved.
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

  /// Disables biometric auto-fill and removes the stored credentials.
  Future<void> disableBiometric() async {
    await _credStorage.clearCredentials();
    _isBiometricEnabled = false;
    notifyListeners();
  }

  /// Prompts the user for biometric authentication.
  ///
  /// On success, returns the saved credentials so the login form can be
  /// auto-filled. Returns [null] if the scan fails, the user cancels, or
  /// no credentials are stored.
  Future<({String email, String password})?> biometricAutoFill() async {
    if (!_isBiometricEnabled) return null;

    final authenticated = await _biometricService.authenticate(
      reason: 'Authenticate to auto-fill your credentials',
    );
    if (!authenticated) return null;

    return await _credStorage.getCredentials();
  }

  /// Refreshes [isBiometricEnabled] — useful after the setup view completes.
  Future<void> refreshBiometricState() async {
    _isBiometricEnabled =
        _isBiometricAvailable && await _credStorage.isEnabled();
    notifyListeners();
  }

  /// Initialize auth state listener
  void _initAuthListener() {
    _authService.authStateChanges.listen((authState) async {
      if (authState.session != null) {
        await _loadCurrentUser();
      } else {
        _currentUser = null;
        _currentRole = null;
        _isAuthenticated = false;
        notifyListeners();
      }
    });

    // Load initial user if already signed in
    _loadCurrentUser();
  }

  /// Load current user from service
  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUserModel();
      if (user != null) {
        _currentUser = user;
        _currentRole = user.role;
        _isAuthenticated = true;

        // Cache user in local database
        await _cacheUserLocally(user);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  /// Sign in with email and password.
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

        // Cache user in local database for offline access
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

  /// Sign out the current user.
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();

      // Clear local user cache
      if (_currentUser != null) {
        await _localDb.deleteUserById(_currentUser!.id);
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

  /// Register a new user.
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );

      if (user != null) {
        _currentUser = user;
        _currentRole = user.role;
        _isAuthenticated = true;

        // Cache user in local database
        await _cacheUserLocally(user);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Registration failed';
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

  /// Register a new student.
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
      _isAuthenticated = true;
      _emailVerified = false;
      await _cacheUserLocally(user);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _formatErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register a new teacher.
  Future<bool> registerTeacher({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
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
        alsCenterId: alsCenterId,
      );

      _currentUser = user;
      _currentRole = UserRole.teacher;
      _isAuthenticated = true;
      _emailVerified = false;
      await _cacheUserLocally(user);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _formatErrorMessage(e.toString());
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Check if the current user's email is verified (Supabase).
  /// If verified, also marks the flag in the Supabase users table.
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

  /// Resend email verification link (Supabase).
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

  /// Cache user in local database for offline access
  Future<void> _cacheUserLocally(UserModel user) async {
    try {
      await _localDb.upsertUser(
        UsersCompanion(
          id: drift.Value(user.id),
          email: drift.Value(user.email),
          fullName: drift.Value(user.fullName),
          role: drift.Value(user.role.name),
          profilePictureUrl: drift.Value(user.profilePictureUrl),
          alsCenterId: drift.Value(user.alsCenterId),
          isActive: drift.Value(user.isActive),
          createdAt: drift.Value(user.createdAt),
          updatedAt: drift.Value(user.updatedAt),
          firstName: drift.Value(user.firstName),
          lastName: drift.Value(user.lastName),
          studentIdNumber: drift.Value(user.studentIdNumber),
          dateOfBirth: drift.Value(user.dateOfBirth),
          age: drift.Value(user.age),
          phoneNumber: drift.Value(user.phoneNumber),
          occupation: drift.Value(user.occupation),
          lastSchoolAttended: drift.Value(user.lastSchoolAttended),
          lastYearAttended: drift.Value(user.lastYearAttended),
          emailVerified: drift.Value(user.emailVerified),
          teacherVerified: drift.Value(user.teacherVerified),
        ),
      );
    } catch (e) {
      debugPrint('Error caching user locally: $e');
    }
  }

  /// Format error messages to be user-friendly
  String _formatErrorMessage(String error) {
    if (error.contains('Invalid login credentials') ||
        error.contains('invalid_credentials')) {
      return 'Invalid email or password';
    } else if (error.contains('Email not confirmed') ||
        error.contains('email_not_confirmed')) {
      return 'Please verify your email address before signing in';
    } else if (error.contains('User already registered') ||
        error.contains('already registered') ||
        error.contains('already been registered')) {
      return 'An account with this email already exists';
    } else if (error.contains('Password should be at least') ||
        error.contains('password') && error.contains('characters')) {
      return 'Password must be at least 8 characters';
    } else if (error.contains('network_error') ||
        error.contains('ApiException: 7')) {
      return 'Network error during Google Sign-In. '
          'Ensure the app is registered in Google Cloud Console '
          'with the correct SHA-1 fingerprint.';
    } else if (error.contains('Google Sign-In is not configured')) {
      return 'Google Sign-In is not set up. Contact the app administrator.';
    } else if (error.contains('no ID token')) {
      return 'Google Sign-In failed: could not obtain authentication token.';
    } else if (error.contains('Full name must be at least')) {
      return 'Please enter your full name (at least 2 characters).';
    } else if (error.contains('Invalid email format')) {
      return 'The email address format is invalid.';
    } else if (error.contains('row-level security') ||
        error.contains('violates row-level')) {
      return 'Account creation failed due to a permissions error. '
          'Please try again or contact support.';
    }
    // Surface the raw message in debug builds so developers see the real error.
    assert(() {
      debugPrint('[AuthViewModel] Unhandled error: $error');
      return true;
    }());
    return 'An error occurred. Please try again.';
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sign in with Google. [role] is used only for brand-new accounts.
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
        // User cancelled the Google picker
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
