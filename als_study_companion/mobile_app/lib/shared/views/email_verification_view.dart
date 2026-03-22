import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../student/views/student_dashboard_view.dart';
import '../../teacher/views/teacher_dashboard_view.dart';
import 'biometric_setup_view.dart';

/// Screen for Firebase email verification.
class EmailVerificationView extends StatefulWidget {
  const EmailVerificationView({super.key});

  @override
  State<EmailVerificationView> createState() => _EmailVerificationViewState();
}

class _EmailVerificationViewState extends State<EmailVerificationView> {
  bool _resendCooldown = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Initial verification check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVerification();
    });
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    final authVm = context.read<AuthViewModel>();
    final isVerified = await authVm.checkEmailVerified();
    setState(() => _isChecking = false);

    if (isVerified && mounted) {
      _navigateToDashboard(authVm.currentRole ?? UserRole.student);
    }
  }

  Future<void> _resendEmail() async {
    if (_resendCooldown) return;

    setState(() => _resendCooldown = true);
    final authVm = context.read<AuthViewModel>();
    await authVm.sendEmailVerification();

    if (!mounted) return;

    if (authVm.errorMessage != null) {
      _showError(authVm.errorMessage!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email resent! Please check your inbox.')),
      );
    }

    Future.delayed(const Duration(seconds: 60), () {
      if (mounted) setState(() => _resendCooldown = false);
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _navigateToDashboard(UserRole role) {
    final authVm = context.read<AuthViewModel>();
    if (authVm.isBiometricAvailable && !authVm.isBiometricEnabled) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BiometricSetupView()),
        (_) => false,
      );
      return;
    }

    Widget dashboard;
    switch (role) {
      case UserRole.student:
        dashboard = const StudentDashboardView();
        break;
      case UserRole.teacher:
        dashboard = const TeacherDashboardView();
        break;
      case UserRole.admin:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin access is via the web panel.')),
        );
        return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => dashboard),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'Verify Your Email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to\n${authVm.currentUser?.email ?? ""}\n\nPlease click the link in the email to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isChecking ? null : _checkVerification,
                  child: _isChecking 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('I\'ve Verified My Email'),
                ),
              ),
              const SizedBox(height: 24),

              TextButton(
                onPressed: _resendCooldown ? null : _resendEmail,
                child: Text(_resendCooldown ? 'Resend email in 60s' : 'Resend Verification Email'),
              ),
              
              TextButton(
                onPressed: () async {
                  await authVm.signOut();
                  if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
