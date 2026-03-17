import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/sync_viewmodel.dart';
import '../../student/views/student_dashboard_view.dart';
import '../../teacher/views/teacher_dashboard_view.dart';
import 'student_registration_view.dart';
import 'teacher_registration_view.dart';
import 'email_verification_view.dart';
import 'teacher_pending_approval_view.dart';

/// Login view with Supabase Authentication.
/// Routes to appropriate dashboard based on user role.
///
/// [preselectedRole] is supplied by [RoleSelectionView] so that the
/// sign-in / register flow already knows whether this is a Student or Teacher,
/// removing the need for the role-picker bottom sheets.
class LoginView extends StatefulWidget {
  final UserRole? preselectedRole;

  const LoginView({super.key, this.preselectedRole});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isBiometricAutoFilling = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authViewModel = context.read<AuthViewModel>();
    final success = await authViewModel.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      final role = authViewModel.currentRole;
      if (role == null) {
        _showError('Unable to determine user role');
        return;
      }
      
      // Trigger background sync after login
      context.read<SyncViewModel>().syncAll();
      
      _navigateAfterAuth(authViewModel);
    } else {
      _showError(authViewModel.errorMessage ?? 'Login failed');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // If a role was pre-selected (via RoleSelectionView) use it directly;
    // otherwise ask the user with the bottom sheet.
    final role = widget.preselectedRole ?? await _showRolePicker();
    if (role == null || !mounted) return;

    setState(() => _isLoading = true);

    final authViewModel = context.read<AuthViewModel>();
    final success = await authViewModel.signInWithGoogle(role: role);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      final resolvedRole = authViewModel.currentRole;
      if (resolvedRole == null) {
        _showError('Unable to determine user role');
        return;
      }
      _navigateAfterAuth(authViewModel);
    } else {
      final err = authViewModel.errorMessage;
      // null means user cancelled — no error shown
      if (err != null) _showError(err);
    }
  }

  /// Shows a bottom sheet asking the user to pick their role.
  Future<UserRole?> _showRolePicker() async {
    return showModalBottomSheet<UserRole>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sign in as…',
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _RoleButton(
              icon: Icons.school_outlined,
              label: 'Student',
              onTap: () => Navigator.pop(ctx, UserRole.student),
            ),
            const SizedBox(height: 12),
            _RoleButton(
              icon: Icons.person_outlined,
              label: 'Teacher',
              onTap: () => Navigator.pop(ctx, UserRole.teacher),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Triggers a biometric scan.  On success, populates the email and
  /// password fields — the user can then review and tap Sign In.
  Future<void> _handleBiometricAutoFill() async {
    if (_isBiometricAutoFilling) return;
    setState(() => _isBiometricAutoFilling = true);

    final authViewModel = context.read<AuthViewModel>();
    final creds = await authViewModel.biometricAutoFill();

    setState(() => _isBiometricAutoFilling = false);

    if (!mounted) return;

    if (creds != null) {
      _emailController.text = creds.email;
      _passwordController.text = creds.password;
      // Trigger login automatically after successful biometric scan
      _handleLogin();
    } else {
      // null means the user cancelled or biometric failed — show soft message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Biometric authentication was not completed.'),
          backgroundColor: Colors.orange[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _navigateToDashboard(UserRole role) {
    Widget dashboard;
    switch (role) {
      case UserRole.student:
        dashboard = const StudentDashboardView();
        break;
      case UserRole.teacher:
        dashboard = const TeacherDashboardView();
        break;
      case UserRole.admin:
        // Admin uses web panel — redirect message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin access is via the web panel.')),
        );
        return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => dashboard));
  }

  /// Decides whether to go to dashboard, email verification, or teacher approval.
  void _navigateAfterAuth(AuthViewModel authVm) {
    if (authVm.needsEmailVerification) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EmailVerificationView()),
      );
      return;
    }
    if (authVm.needsTeacherApproval) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TeacherPendingApprovalView()),
      );
      return;
    }
    _navigateToDashboard(authVm.currentRole!);
  }

  /// Navigates to the registration screen.
  /// If [preselectedRole] is set (coming from RoleSelectionView) it goes
  /// directly to the matching screen; otherwise shows the role-picker sheet.
  void _showRegisterRolePicker() {
    final role = widget.preselectedRole;
    if (role == UserRole.student) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StudentRegistrationView()),
      );
      return;
    }
    if (role == UserRole.teacher) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TeacherRegistrationView()),
      );
      return;
    }

    // No pre-selection — ask the user.
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Register as…',
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _RoleButton(
              icon: Icons.school_outlined,
              label: 'Student',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StudentRegistrationView(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _RoleButton(
              icon: Icons.person_outlined,
              label: 'Teacher',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TeacherRegistrationView(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / App Title
                  Icon(
                    Icons.school,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ALS Study Companion',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.preselectedRole == UserRole.student
                        ? 'Sign in as a Student'
                        : widget.preselectedRole == UserRole.teacher
                        ? 'Sign in as a Teacher'
                        : 'Sign in to continue learning',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 48),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: Validators.validatePassword,
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Biometric Auto-fill button ─────────────────────────────
                  // Shown only when the user has previously set up biometric
                  // login on this device.
                  Consumer<AuthViewModel>(
                    builder: (context, authVm, child) {
                      if (!authVm.isBiometricEnabled) {
                        return const SizedBox.shrink();
                      }
                      final label = authVm.biometricLabel;
                      final icon = label == 'Face ID'
                          ? Icons.face_outlined
                          : Icons.fingerprint;
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: (_isLoading || _isBiometricAutoFilling)
                              ? null
                              : _handleBiometricAutoFill,
                          icon: _isBiometricAutoFilling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(icon),
                          label: Text(
                            _isBiometricAutoFilling
                                ? 'Scanning…'
                                : 'Auto-fill with $label',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Sign-In button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: Image.network(
                        'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                        height: 20,
                        width: 20,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.g_mobiledata, size: 22),
                      ),
                      label: const Text('Continue with Google'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Register link
                  TextButton(
                    onPressed: () => _showRegisterRolePicker(),
                    child: const Text('Don\'t have an account? Register'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helper widget
// ---------------------------------------------------------------------------

class _RoleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoleButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
