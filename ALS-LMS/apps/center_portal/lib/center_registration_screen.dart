import 'package:flutter/material.dart';
import 'package:backend_services/backend_services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_core/shared_core.dart';

class CenterRegistrationScreen extends StatefulWidget {
  const CenterRegistrationScreen({super.key});

  @override
  State<CenterRegistrationScreen> createState() => _CenterRegistrationScreenState();
}

class _CenterRegistrationScreenState extends State<CenterRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _centerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _adminFullNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _selectedCity;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _isSuccess = false;

  final List<String> _davaoOrientalCities = [
    'Mati (Capital)',
    'Baganga',
    'Banaybanay',
    'Boston',
    'Caraga',
    'Cateel',
    'Governor Generoso',
    'Lupon',
    'Manay',
    'San Isidro',
    'Tarragona',
  ];

  @override
  void dispose() {
    _centerNameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _adminFullNameController.dispose();
    _adminEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a City/Municipality')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final client = SupabaseConfig.client;
      await client.from(DbConstants.tableAlsCenterRegistrations).insert({
        'center_name': _centerNameController.text.trim(),
        'address': _addressController.text.trim(),
        'region': _selectedCity, // Storing City/Municipality in the region column
        'contact_number': _contactNumberController.text.trim(),
        'admin_full_name': _adminFullNameController.text.trim(),
        'admin_email': _adminEmailController.text.trim(),
        'admin_password': _passwordController.text, // Temporary storage until approved
        'status': CenterRegistrationStatus.pending.toJson(),
      });

      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: AlsColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 80, color: AlsColors.success),
                    const SizedBox(height: 24),
                    const Text(
                      '9Class Request Submitted!',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your center registration request has been submitted. '
                      'Once approved by our system admins, you will be able to log in using the email and password you provided.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 50),
                      ),
                      child: const Text('Back to Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AlsColors.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school_rounded, color: AlsColors.primary, size: 40),
                          const SizedBox(width: 16),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Register Your ALS Center',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Join the 9Class digital platform.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      const Text('Center Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _centerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Center Name',
                          hintText: 'e.g. Mati Central ALS',
                          prefixIcon: Icon(Icons.business_rounded),
                        ),
                        validator: (v) => Validators.validateRequired(v, 'Center Name'),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCity,
                              decoration: const InputDecoration(
                                labelText: 'City/Municipality',
                                prefixIcon: Icon(Icons.location_city_rounded),
                              ),
                              items: _davaoOrientalCities.map((city) {
                                return DropdownMenuItem(value: city, child: Text(city));
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedCity = val),
                              validator: (v) => v == null ? 'Selection required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _contactNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Contact Number',
                                prefixIcon: Icon(Icons.phone_rounded),
                              ),
                              validator: (v) => Validators.validatePhone(v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Physical Address',
                          hintText: 'Building, Street, Barangay...',
                          prefixIcon: Icon(Icons.map_rounded),
                        ),
                        validator: (v) => Validators.validateRequired(v, 'Address'),
                      ),
                      
                      const SizedBox(height: 32),
                      const Text('Administrator Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _adminFullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                        validator: (v) => Validators.validateFullName(v),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _adminEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Admin Email',
                          prefixIcon: Icon(Icons.email_rounded),
                        ),
                        validator: (v) => Validators.validateEmail(v),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AlsColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Submit Registration Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                          child: const Text('Already registered? Log in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

