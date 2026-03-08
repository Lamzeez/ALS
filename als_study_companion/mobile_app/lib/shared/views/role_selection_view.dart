import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'login_view.dart';

/// First screen shown at app launch.
/// The user picks their role (Student or Teacher) before being routed
/// to the login / sign-up flow for that role.
class RoleSelectionView extends StatelessWidget {
  const RoleSelectionView({super.key});

  void _goToLogin(BuildContext context, UserRole role) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LoginView(preselectedRole: role)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(),

              // ── App logo & title ───────────────────────────────────────────
              Icon(
                Icons.school,
                size: 88,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'ALS Study Companion',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your role to get started',
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // ── Student card ───────────────────────────────────────────────
              _RoleCard(
                icon: Icons.school_outlined,
                title: "I'm a Student",
                subtitle: 'Access lessons, quizzes & progress tracking',
                color: const Color(0xFF1565C0),
                onTap: () => _goToLogin(context, UserRole.student),
              ),
              const SizedBox(height: 16),

              // ── Teacher card ───────────────────────────────────────────────
              _RoleCard(
                icon: Icons.person_outlined,
                title: "I'm a Teacher",
                subtitle: 'Manage lessons, monitor & guide students',
                color: const Color(0xFF2E7D32),
                onTap: () => _goToLogin(context, UserRole.teacher),
              ),

              const Spacer(),

              // ── Footer ─────────────────────────────────────────────────────
              Text(
                'Alternative Learning System',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Private helper widget
// ───────────────────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Icon badge
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 32, color: color),
                ),
                const SizedBox(width: 16),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),

                Icon(Icons.arrow_forward_ios, size: 16, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
