import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import 'package:file_picker/file_picker.dart';
import '../viewmodels/auth_viewmodel.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  Future<void> _pickAndUploadImage(AuthViewModel authVm) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        final success = await authVm.updateProfilePicture(result.files.first.bytes!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success 
                ? 'Profile picture updated successfully!' 
                : (authVm.errorMessage ?? 'Failed to update profile picture')),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user data available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Header
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: authVm.isLoading 
                            ? const CircularProgressIndicator()
                            : (user.profilePictureUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      user.profilePictureUrl!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => 
                                          const Icon(Icons.person, size: 60),
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Theme.of(context).colorScheme.primary,
                                  )),
                        ),
                      ),
                      if (!authVm.isLoading)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _pickAndUploadImage(authVm),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    user.role.name.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Profile Details
            _buildInfoCard(
              context,
              title: 'Account Information',
              children: [
                _buildInfoRow(Icons.email_outlined, 'Email', user.email),
                if (user.phoneNumber != null)
                  _buildInfoRow(Icons.phone_outlined, 'Phone', user.phoneNumber!),
                if (user.alsCenterId != null)
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    'ALS Center',
                    _getCenterName(authVm, user.alsCenterId!),
                  ),
              ],
            ),

            if (user.role == UserRole.student) ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                title: 'Student Details',
                children: [
                  if (user.studentIdNumber != null)
                    _buildInfoRow(
                        Icons.badge_outlined, 'Student ID', user.studentIdNumber!),
                  if (user.age != null)
                    _buildInfoRow(
                        Icons.cake_outlined, 'Age', user.age.toString()),
                  if (user.occupation != null)
                    _buildInfoRow(
                        Icons.work_outline, 'Occupation', user.occupation!),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                title: 'Educational Background',
                children: [
                  if (user.lastSchoolAttended != null)
                    _buildInfoRow(Icons.school_outlined, 'Last School',
                        user.lastSchoolAttended!),
                  if (user.lastYearAttended != null)
                    _buildInfoRow(Icons.calendar_today_outlined, 'Last Year',
                        user.lastYearAttended!),
                ],
              ),
            ],

            const SizedBox(height: 32),
            // Sign Out Button (extra one for convenience)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLogoutDialog(context, authVm),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getCenterName(AuthViewModel authVm, String centerId) {
    try {
      final center = authVm.centers.firstWhere((c) => c.id == centerId);
      return center.name;
    } catch (e) {
      return 'Unknown Center';
    }
  }

  Widget _buildInfoCard(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthViewModel authVm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await authVm.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
