import 'package:flutter/material.dart';
import 'package:shared_services/shared_services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_models/shared_models.dart';

class WebLoginScreen extends StatefulWidget {
  final Function(Profile) onLoginSuccess;
  const WebLoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final profile = await _authService.getCurrentProfile();
      if (profile == null) throw Exception('Profile not found');

      if (profile.role != UserRole.devAdmin && profile.role != UserRole.schoolAdmin) {
        await _authService.signOut();
        throw Exception('Access Denied: Only Admins can enter this portal.');
      }

      widget.onLoginSuccess(profile);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AlsColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AlsColors.primaryDark,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, size: 64, color: AlsColors.primary),
              const SizedBox(height: 24),
              const Text('ALS Admin Portal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Admin Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sign In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
