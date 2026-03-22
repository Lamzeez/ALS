import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/viewmodels/auth_viewmodel.dart';
import '../../shared/viewmodels/sync_viewmodel.dart';
import '../../shared/views/profile_view.dart';
import '../viewmodels/teacher_lesson_viewmodel.dart';
import '../viewmodels/student_monitor_viewmodel.dart';
import '../viewmodels/quiz_creator_viewmodel.dart';
import 'teacher_lessons_view.dart';
import 'teacher_lesson_create_view.dart';
import 'teacher_students_view.dart';
import 'teacher_sessions_view.dart';
import 'teacher_announcements_view.dart';
import 'teacher_session_create_view.dart';
import 'teacher_announcement_create_view.dart';

/// Main dashboard for teacher users.
class TeacherDashboardView extends StatefulWidget {
  const TeacherDashboardView({super.key});

  @override
  State<TeacherDashboardView> createState() => _TeacherDashboardViewState();
}

class _TeacherDashboardViewState extends State<TeacherDashboardView> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _TeacherHomeTab(),
    TeacherLessonsView(),
    TeacherStudentsView(),
    TeacherSessionsView(),
    TeacherAnnouncementsView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Lessons',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Announce',
          ),
        ],
      ),
    );
  }
}

class _TeacherHomeTab extends StatefulWidget {
  const _TeacherHomeTab();

  @override
  State<_TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<_TeacherHomeTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      if (auth.currentUser != null) {
        context.read<TeacherLessonViewModel>().loadLessons(auth.currentUser!.id);
        context.read<StudentMonitorViewModel>().loadStudents(auth.currentUser!.id);
      }
    });
  }

  void _handleLogout() async {
    final authVm = context.read<AuthViewModel>();
    await authVm.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final syncVm = context.watch<SyncViewModel>();
    final lessonVm = context.watch<TeacherLessonViewModel>();
    final studentVm = context.watch<StudentMonitorViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            icon: syncVm.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: () => syncVm.syncAll(),
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
                          _handleLogout();
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
        onRefresh: () async {
          if (authVm.currentUser != null) {
            await lessonVm.loadLessons(authVm.currentUser!.id);
            await studentVm.loadStudents(authVm.currentUser!.id);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${authVm.currentUser?.fullName ?? "Teacher"}!',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your classes and monitor student progress.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Actions Grid
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.5,
                children: [
                  _QuickActionCard(
                    icon: Icons.add_circle_outline,
                    label: 'New Lesson',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TeacherLessonCreateView(),
                        ),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.quiz_outlined,
                    label: 'Create Quiz',
                    color: Colors.green,
                    onTap: () {
                      // TODO: Navigate to Quiz Creation
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.calendar_today,
                    label: 'Schedule',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TeacherSessionCreateView()),
                      );
                    },
                  ),
                  _QuickActionCard(
                    icon: Icons.campaign,
                    label: 'Announce',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TeacherAnnouncementCreateView()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats
              Text('Overview', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Students',
                      value: studentVm.students.length.toString(),
                      icon: Icons.people,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      label: 'Lessons',
                      value: lessonVm.lessons.length.toString(),
                      icon: Icons.book,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                      label: 'Quizzes',
                      value: '0', // TODO: Implement overall quiz count
                      icon: Icons.quiz,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
