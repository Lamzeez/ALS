import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_core/shared_core.dart';
import 'package:backend_services/backend_services.dart';
import '../bloc/auth_bloc.dart';

/// Registration screen with role selection and role-specific form fields.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // Common fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Role specific
  final _studentIdController = TextEditingController();
  final _empIdController = TextEditingController();

  // Center Selection
  final _centerService = CenterService();
  List<LearningCenter> _centers = [];
  LearningCenter? _selectedCenter;
  bool _isLoadingCenters = true;

  final _formKey = GlobalKey<FormState>();
  UserRole _selectedRole = UserRole.student;
  String _selectedGender = 'Male';
  DateTime? _birthDate;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
    _loadCenters();
  }

  Future<void> _loadCenters() async {
    try {
      final centers = await _centerService.getCenters();
      if (mounted) {
        setState(() {
          _centers = centers;
          _isLoadingCenters = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCenters = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _studentIdController.dispose();
    _empIdController.dispose();
    _animationController.dispose();
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
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          } else if (state is AuthSignUpSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Account created! Redirecting...'),
                backgroundColor: AlsColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 5),
              ),
            );
            // Navigator.pop(context) removed to allow automatic router redirect
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
                Color(0xFF1976D2),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            _buildLogo(),
                            const SizedBox(height: 24),
                            _buildRegistrationCard(),
                            const SizedBox(height: 24),
                            Text(
                              'Alternative Learning System',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          const Spacer(),
          Text(
            'Create Account',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white30, width: 2),
          ),
          child: const Icon(Icons.person_add_rounded, size: 36, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          'Join ALS Study',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Widget _buildRegistrationCard() {
    return Container(
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
            // ── Role Selection ──
            Text('I am a:', style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AlsColors.textPrimary,
              fontWeight: FontWeight.w600,
            )),
            const SizedBox(height: 12),
            _buildRoleSelection(),
            const SizedBox(height: 24),

            // ── ALS Center Selection (NEW) ──
            if (_isLoadingCenters)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<LearningCenter>(
                value: _selectedCenter,
                decoration: const InputDecoration(
                  labelText: 'Your ALS Center *',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                items: _centers.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                onChanged: (v) => setState(() => _selectedCenter = v),
                validator: (v) => v == null ? 'Please select a center' : null,
              ),
            const SizedBox(height: 16),

            // ── Common Fields ──
            TextFormField(
              controller: _firstNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'First Name *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _lastNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Last Name *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ── Role-Specific Fields ──
            if (_selectedRole == UserRole.student) 
              TextFormField(
                controller: _studentIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Student LRN (12 digits) *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'LRN is required';
                  if (v.trim().length != 12) return 'LRN must be exactly 12 digits';
                  if (!RegExp(r'^\d+$').hasMatch(v.trim())) return 'Numbers only';
                  return null;
                },
              ),
            
            if (_selectedRole == UserRole.teacher)
              TextFormField(
                controller: _empIdController,
                decoration: const InputDecoration(
                  labelText: 'Employee ID *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Employee ID is required' : null,
              ),

            const SizedBox(height: 12),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                  return 'Invalid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Password
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password *',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 8) return 'At least 8 characters';
                return null;
              },
            ),

            const SizedBox(height: 24),

            // ── Register Button ──
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final isLoading = state is AuthLoading;
                return ElevatedButton(
                  onPressed: isLoading ? null : _onRegisterPressed,
                  child: isLoading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Account'),
                );
              },
            ),
            const SizedBox(height: 16),

            // Already have account
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Already have an account? ",
                    style: Theme.of(context).textTheme.bodySmall),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Row(
      children: [
        Expanded(child: _buildRoleCard(
          role: UserRole.student,
          icon: Icons.school_rounded,
          title: 'Student',
          description: 'Learn ALS modules',
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildRoleCard(
          role: UserRole.teacher,
          icon: Icons.person_rounded,
          title: 'Teacher',
          description: 'Teach and mentor',
        )),
      ],
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AlsColors.primary.withValues(alpha: 0.1)
              : AlsColors.surface,
          border: Border.all(
            color: isSelected ? AlsColors.primary : AlsColors.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AlsColors.primary : AlsColors.divider,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                color: isSelected ? Colors.white : AlsColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: isSelected ? AlsColors.primary : AlsColors.textPrimary,
              fontWeight: FontWeight.w600,
            )),
          ],
        ),
      ),
    );
  }

  void _onRegisterPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthSignUpWithRoleRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              role: _selectedRole,
              studentId: _selectedRole == UserRole.student ? _studentIdController.text.trim() : null,
              empId: _selectedRole == UserRole.teacher ? _empIdController.text.trim() : null,
              centerLocation: _selectedCenter?.id, // Passing the UUID
              gender: _selectedGender,
            ),
          );
    }
  }
}

