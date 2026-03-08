import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin authentication ViewModel — backed by Supabase Auth.
class AdminAuthViewModel extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  AdminAuthViewModel() {
    // Restore existing session synchronously if available.
    _isAuthenticated = Supabase.instance.client.auth.currentUser != null;

    // Listen for auth state changes (token refresh, sign-out from another tab).
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final newAuth = data.session != null;
      if (newAuth != _isAuthenticated) {
        _isAuthenticated = newAuth;
        notifyListeners();
      }
    });
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Currently signed-in Supabase user, or null.
  User? get currentUser => Supabase.instance.client.auth.currentUser;

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _isAuthenticated = res.user != null;
      _isLoading = false;
      notifyListeners();
      return _isAuthenticated;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _isAuthenticated = false;
    notifyListeners();
  }
}
