import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/admin_auth_viewmodel.dart';
import '../viewmodels/analytics_viewmodel.dart';
import '../viewmodels/center_management_viewmodel.dart';

/// Admin dashboard overview page — shows live stats from Supabase.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsViewModel>().loadAnalytics();
      context.read<CenterManagementViewModel>().loadCenters();
    });
  }

  void _refresh() {
    context.read<AnalyticsViewModel>().loadAnalytics();
    context.read<CenterManagementViewModel>().loadCenters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => context.read<AdminAuthViewModel>().signOut(),
          ),
        ],
      ),
      body: Consumer2<AnalyticsViewModel, CenterManagementViewModel>(
        builder: (context, analyticsVm, centersVm, _) {
          if (analyticsVm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Overview',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),

                // Stats Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 2.0,
                      children: [
                        _DashboardCard(
                          title: 'Total Students',
                          value: '${analyticsVm.totalStudents}',
                          icon: Icons.school,
                          color: Colors.blue,
                        ),
                        _DashboardCard(
                          title: 'Total Teachers',
                          value: '${analyticsVm.totalTeachers}',
                          icon: Icons.person,
                          color: Colors.green,
                        ),
                        _DashboardCard(
                          title: 'Total Lessons',
                          value: '${analyticsVm.totalLessons}',
                          icon: Icons.book,
                          color: Colors.orange,
                        ),
                        _DashboardCard(
                          title: 'ALS Centers',
                          value: '${centersVm.totalCenters}',
                          icon: Icons.location_city,
                          color: Colors.purple,
                        ),
                        _DashboardCard(
                          title: 'Active Users',
                          value: '${analyticsVm.activeUsers}',
                          icon: Icons.people,
                          color: Colors.teal,
                        ),
                        _DashboardCard(
                          title: 'Avg Progress',
                          value:
                              '${analyticsVm.averageProgress.toStringAsFixed(1)}%',
                          icon: Icons.trending_up,
                          color: Colors.indigo,
                        ),
                        _DashboardCard(
                          title: 'Total Quizzes',
                          value: '${analyticsVm.totalQuizzes}',
                          icon: Icons.quiz,
                          color: Colors.red,
                        ),
                        _DashboardCard(
                          title: 'Published Lessons',
                          value: '${analyticsVm.publishedLessons}',
                          icon: Icons.publish,
                          color: Colors.amber,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Recent Activity Section
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (analyticsVm.recentActivity.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No recent admin activity recorded.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ),
                    ),
                  )
                else
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: analyticsVm.recentActivity.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final log = analyticsVm.recentActivity[i];
                        return ListTile(
                          dense: true,
                          leading:
                              const Icon(Icons.history, size: 20),
                          title: Text(
                            log['action'] as String? ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            log['details'] as String? ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            _formatDate(log['created_at'] as String?),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.month}/${dt.day} '
          '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(title, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
