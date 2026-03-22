import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'email_verification_view.dart';

/// Student Registration screen — collects all required student info,
/// creates a Firebase account, sends email verification, saves to Supabase.
class StudentRegistrationView extends StatefulWidget {
  const StudentRegistrationView({super.key});

  @override
  State<StudentRegistrationView> createState() =>
      _StudentRegistrationViewState();
}

class _StudentRegistrationViewState extends State<StudentRegistrationView> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _lastSchoolCtrl = TextEditingController();
  final _lastYearCtrl = TextEditingController();

  DateTime? _dateOfBirth;
  int? _age;
  String? _selectedCenterId;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _studentIdCtrl.dispose();
    _phoneCtrl.dispose();
    _occupationCtrl.dispose();
    _lastSchoolCtrl.dispose();
    _lastYearCtrl.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
        _age = _calculateAge(picked);
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      _showError('Please select your date of birth');
      return;
    }

    final authVm = context.read<AuthViewModel>();
    final success = await authVm.registerStudent(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      studentIdNumber: _studentIdCtrl.text.trim(),
      dateOfBirth: _dateOfBirth!,
      age: _age!,
      phoneNumber: _phoneCtrl.text.trim(),
      occupation: _occupationCtrl.text.trim().isEmpty
          ? null
          : _occupationCtrl.text.trim(),
      lastSchoolAttended: _lastSchoolCtrl.text.trim().isEmpty
          ? null
          : _lastSchoolCtrl.text.trim(),
      lastYearAttended: _lastYearCtrl.text.trim().isEmpty
          ? null
          : _lastYearCtrl.text.trim(),
      alsCenterId: _selectedCenterId,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EmailVerificationView()),
      );
    } else {
      _showError(authVm.errorMessage ?? 'Registration failed');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthViewModel>().isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Student Registration')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create your Student account',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // First Name
                TextFormField(
                  controller: _firstNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'First Name *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      Validators.validateRequired(v, 'First Name'),
                ),
                const SizedBox(height: 16),

                // Last Name
                TextFormField(
                  controller: _lastNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Last Name *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => Validators.validateRequired(v, 'Last Name'),
                ),
                const SizedBox(height: 16),

                // Student ID Number
                TextFormField(
                  controller: _studentIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Student ID Number *',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      Validators.validateRequired(v, 'Student ID Number'),
                ),
                const SizedBox(height: 16),

                // Date of Birth
                InkWell(
                  onTap: _pickDateOfBirth,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth *',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _dateOfBirth != null
                          ? '${_dateOfBirth!.month}/${_dateOfBirth!.day}/${_dateOfBirth!.year}'
                          : 'Tap to select',
                      style: TextStyle(
                        color: _dateOfBirth != null ? null : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Age (auto-calculated)
                if (_age != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      initialValue: _age.toString(),
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Age (auto-calculated)',
                        prefixIcon: Icon(Icons.cake_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                // Phone Number
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                    hintText: '+639xxxxxxxxx',
                  ),
                  validator: Validators.validatePhoneRequired,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) =>
                      Validators.validateConfirmPassword(v, _passwordCtrl.text),
                ),
                const SizedBox(height: 16),

                // ALS Center Dropdown
                Consumer<AuthViewModel>(
                  builder: (context, authVm, child) {
                    if (authVm.centers.isEmpty) {
                      return OutlinedButton.icon(
                        onPressed: () => authVm.fetchCenters(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Loading Centers... Tap to retry'),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedCenterId,
                      decoration: const InputDecoration(
                        labelText: 'ALS Center *',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: authVm.centers.map((center) {
                        return DropdownMenuItem(
                          value: center.id,
                          child: Text(center.name),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCenterId = val),
                      validator: (v) => Validators.validateRequired(v, 'ALS Center'),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Optional section divider
                Text(
                  'Optional Information',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),

                // Occupation
                TextFormField(
                  controller: _occupationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Occupation',
                    prefixIcon: Icon(Icons.work_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Last School Attended
                TextFormField(
                  controller: _lastSchoolCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Last School Attended',
                    prefixIcon: Icon(Icons.school_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Last Year Attended
                TextFormField(
                  controller: _lastYearCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Last Year Attended',
                    prefixIcon: Icon(Icons.date_range_outlined),
                    border: OutlineInputBorder(),
                    hintText: 'e.g. 2020',
                  ),
                ),
                const SizedBox(height: 32),

                // Register button
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: isLoading ? null : _handleRegister,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 16),

                // Back to Login
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Already have an account? Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
