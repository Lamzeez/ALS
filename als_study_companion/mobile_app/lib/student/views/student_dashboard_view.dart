import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/viewmodels/auth_viewmodel.dart';
import '../../shared/views/profile_view.dart';
import '../viewmodels/lesson_viewmodel.dart';
import '../viewmodels/download_viewmodel.dart';
import '../../shared/viewmodels/sync_viewmodel.dart';
import 'student_lesson_detail_view.dart';
import 'student_lessons_view.dart';
import 'student_progress_view.dart';
import 'student_downloads_view.dart';

/// Main dashboard for student users.
class StudentDashboardView extends StatefulWidget {
  const StudentDashboardView({super.key});

  @override
  State<StudentDashboardView> createState() => _StudentDashboardViewState();
}

class _StudentDashboardViewState extends State<StudentDashboardView> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _StudentHomeTab(),
    StudentLessonsView(),
    StudentProgressView(),
    StudentDownloadsView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Lessons',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download_done),
            label: 'Downloads',
          ),
        ],
      ),
    );
  }
}

class _StudentHomeTab extends StatelessWidget {
  const _StudentHomeTab();

  void _handleLogout(BuildContext context) async {
    final authVm = context.read<AuthViewModel>();
    await authVm.signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncVm = context.watch<SyncViewModel>();
    final lessonVm = context.watch<LessonViewModel>();
    final downloadVm = context.watch<DownloadViewModel>();
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ALS Study Companion'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: syncVm.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                onPressed: syncVm.isSyncing ? null : () => syncVm.syncAll(),
              ),
              if (syncVm.errorMessage != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 8,
                      minHeight: 8,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: authVm.currentUser?.profilePictureUrl != null
                  ? ClipOval(
                      child: Image.network(
                        authVm.currentUser!.profilePictureUrl!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
            ),
            onSelected: (value) {
              if (value == 'profile') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileView()),
                );
              } else if (value == 'logout') {
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
                        onPressed: () {
                          Navigator.pop(context);
                          _handleLogout(context);
                        },
                        child: const Text('Logout',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 8),
                    Text('My Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => syncVm.syncAll(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${authVm.currentUser?.fullName ?? ""}!',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Continue your learning journey',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Stats
              Text(
                'Your Progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.book,
                      label: 'Lessons',
                      value: lessonVm.lessons.length.toString(),
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.quiz,
                      label: 'Quizzes',
                      value: '0', // TODO: Implement overall quiz stats
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.download_done,
                      label: 'Downloads',
                      value: downloadVm.downloads.length.toString(),
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Lessons
              Text(
                'Recent Lessons',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (lessonVm.lessons.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No lessons available yet.\nTap the sync button to fetch content.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lessonVm.lessons.length.clamp(0, 3),
                  itemBuilder: (context, index) {
                    final lesson = lessonVm.lessons[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(lesson.title),
                        subtitle: Text(lesson.subject),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentLessonDetailView(lesson: lesson),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Announcements
              Text(
                'Announcements',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No announcements',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
