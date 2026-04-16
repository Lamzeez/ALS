import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_ui/shared_ui.dart';

import '../bloc/auth_bloc.dart';

/// Shown to brand-new users who signed in with Google and haven't selected a role.
/// Asks: "Are you a Student or a Teacher?"
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  UserRole _selectedRole = UserRole.student;
  final _lrnController = TextEditingController();
  final _empIdController = TextEditingController();
  final _centerController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthNeedsOnboarding) {
      _selectedRole = authState.profile.role;
    }
  }

  @override
  void dispose() {
    _lrnController.dispose();
    _empIdController.dispose();
    _centerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AlsColors.error,
              ),
            );
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AlsColors.primaryDark,
                AlsColors.primary,
                Color(0xFF1976D2)
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.waving_hand_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to ALS Study!',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Let\'s set up your profile',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'I am a:',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AlsColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),

                            // Role toggle
                            Row(
                              children: [
                                _RoleCard(
                                  label: 'Student',
                                  icon: Icons.school_rounded,
                                  selected: _selectedRole == UserRole.student,
                                  onTap: () => setState(
                                      () => _selectedRole = UserRole.student),
                                ),
                                const SizedBox(width: 12),
                                _RoleCard(
                                  label: 'Teacher',
                                  icon: Icons.person_rounded,
                                  selected: _selectedRole == UserRole.teacher,
                                  onTap: () => setState(
                                      () => _selectedRole = UserRole.teacher),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Student → LRN (optional)
                            if (_selectedRole == UserRole.student) ...[
                              TextFormField(
                                controller: _lrnController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Student ID / LRN (optional)',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                  hintText: 'e.g. 401234567890',
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Teacher → Employee ID + notice
                            if (_selectedRole == UserRole.teacher) ...[
                                TextFormField(
                                  controller: _empIdController,
                                  decoration: const InputDecoration(
                                    labelText: 'Employee ID *',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _centerController,
                                  decoration: const InputDecoration(
                                    labelText: 'Center / Location *',
                                    prefixIcon: Icon(Icons.location_on_outlined),
                                    hintText: 'e.g. San Jose District',
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.amber.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: Colors.amber, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Teacher accounts require approval by the School Admin before access is granted.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color: Colors.amber[800]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Submit
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                final isLoading = state is AuthLoading;
                                return ElevatedButton(
                                  onPressed: isLoading ? null : _submit,
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Continue'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign out link
                    TextButton(
                      onPressed: () =>
                          context.read<AuthBloc>().add(AuthLogoutRequested()),
                      child: const Text(
                        'Sign out',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthSetRoleRequested(
            role: _selectedRole,
            studentIdNumber: _lrnController.text.trim().isNotEmpty
                ? _lrnController.text.trim()
                : null,
            empId: _empIdController.text.trim().isNotEmpty
                ? _empIdController.text.trim()
                : null,
            alsCenterId: _centerController.text.trim().isNotEmpty
                ? _centerController.text.trim()
                : null,
          ),
        );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? AlsColors.primary : AlsColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AlsColors.primary : AlsColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : AlsColors.textSecondary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AlsColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
