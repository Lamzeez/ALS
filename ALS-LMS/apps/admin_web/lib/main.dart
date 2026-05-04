import 'package:flutter/material.dart';
import 'package:shared_services/shared_services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_models/shared_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('[Admin] Initialization failed: $e');
  }
  runApp(const AlsAdminApp());
}

class AlsAdminApp extends StatelessWidget {
  const AlsAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALS Admin Portal',
      theme: AlsTheme.lightTheme,
      darkTheme: AlsTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const AdminAuthGate(),
    );
  }
}

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({super.key});

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  Profile? _profile;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final profile = await AuthService().getCurrentProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _profile = null;
          _checking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    if (_profile == null) {
      return WebLoginScreen(onLoginSuccess: (p) => setState(() => _profile = p));
    }

    return AdminDashboard(adminProfile: _profile!);
  }
}

class AdminDashboard extends StatefulWidget {
  final Profile adminProfile;
  const AdminDashboard({super.key, required this.adminProfile});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late UserRole currentView;
  int _selectedNavIndex = 0;

  // Services
  final _systemService = SystemService();
  final _centerService = CenterService();
  final _mediaService = MediaService();

  // Live data from Supabase
  int _totalUsers = 0;
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalDistricts = 0;
  int _totalCourses = 0;
  int _totalCenters = 0;
  int _totalEnrollments = 0;
  String _totalStorage = '0.00';
  String _avgMastery = '0.0';
  List<Map<String, dynamic>> _recentUsers = [];
  List<Map<String, dynamic>> _districts = [];
  // Cached media future — prevents redundant queries on every setState (M-2)
  Future<List<Map<String, dynamic>>>? _mediaFuture;
  List<Map<String, dynamic>> _courses = [];
  List<LearningCenter> _centers = [];
  List<ActivityLog> _activityLogs = [];
  List<Map<String, dynamic>> _pendingTeachers = [];
  bool _isLoading = true;
  bool _killSwitchActive = false;
  bool _maintenanceActive = false;

  @override
  void initState() {
    super.initState();
    currentView = widget.adminProfile.role;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseConfig.client;

      // Profiles — separate count queries from the display list (M-6)
      final allProfiles = await client
          .from('profiles')
          .select('id, role')
          .order('created_at', ascending: false);
      _totalUsers = (allProfiles as List).length;
      _totalStudents =
          allProfiles.where((u) => u['role'] == 'student').length;
      _totalTeachers =
          allProfiles.where((u) => u['role'] == 'teacher').length;

      // Display list — limited to 50 most recent for the table
      final profiles = await client
          .from('profiles')
          .select('id, role, full_name, email, is_active, created_at')
          .order('created_at', ascending: false)
          .limit(50);
      _recentUsers = List<Map<String, dynamic>>.from(profiles);

      // Refresh media future (M-2)
      _mediaFuture = SupabaseConfig.client
          .from('lesson_media')
          .select('*, lessons(title)')
          .order('created_at', ascending: false)
          .then((r) => List<Map<String, dynamic>>.from(r));

      // Districts
      final districts = await client.from('districts').select();
      _districts = List<Map<String, dynamic>>.from(districts);
      _totalDistricts = _districts.length;

      // Courses
      final courses = await client.from('courses').select();
      _courses = List<Map<String, dynamic>>.from(courses);
      _totalCourses = _courses.length;

      // Centers
      _centers = await _centerService.getCenters();
      _totalCenters = _centers.length;

      // Enrollments
      try {
        final enrollments =
            await client.from('course_enrollments').select('id');
        _totalEnrollments = (enrollments as List).length;
      } catch (_) {
        _totalEnrollments = 0;
      }

      // System settings
      try {
        final settings = await _systemService.getSettings();
        for (final s in settings) {
          if (s.key == 'kill_switch') {
            _killSwitchActive = s.value['active'] == true;
          } else if (s.key == 'maintenance_mode') {
            _maintenanceActive = s.value['enabled'] == true;
          }
        }
      } catch (_) {}

      // Analytics — use sentinel to detect RPC failure (H-4)
      try {
        final analytics = await _systemService.getGlobalAnalytics();
        if (analytics['_error'] == true) {
          _totalStorage = 'N/A';
          _avgMastery = 'N/A';
        } else {
          _totalStorage =
              analytics['total_storage_gb']?.toString() ?? '0.00';
          _avgMastery =
              analytics['avg_mastery_score']?.toString() ?? '0.0';
        }
      } catch (_) {
        _totalStorage = 'N/A';
        _avgMastery = 'N/A';
      }

      // Pending teachers
      try {
        final pending = await client
            .from('profiles')
            .select('id, full_name, email, employee_id, created_at')
            .eq('role', 'teacher')
            .eq('approval_status', 'pending')
            .order('created_at', ascending: true);
        _pendingTeachers = List<Map<String, dynamic>>.from(pending);
      } catch (_) {
        _pendingTeachers = [];
      }

      // Activity logs (Dev Admin)
      try {
        _activityLogs = await _systemService.getActivityLogs(limit: 25);
      } catch (_) {}
    } catch (e) {
      debugPrint('[Admin] Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Navigation items for each role
  List<_NavItem> get _navItems {
    if (currentView == UserRole.devAdmin) {
      return [
        _NavItem(Icons.dashboard_rounded, 'Overview'),
        _NavItem(Icons.people_rounded, 'User Management'),
        _NavItem(Icons.security_rounded, 'System Controls'),
        _NavItem(Icons.analytics_rounded, 'Activity Logs'),
        _NavItem(Icons.perm_media_rounded, 'Media Library'),
        _NavItem(Icons.storage_rounded, 'Database'),
        _NavItem(Icons.settings_rounded, 'System Settings'),
      ];
    } else if (currentView == UserRole.teacher) {
      return [
        _NavItem(Icons.dashboard_rounded, 'Teacher Overview'),
        _NavItem(Icons.school_rounded, 'My Courses'),
        _NavItem(Icons.event_note_rounded, 'My Sessions'),
        _NavItem(Icons.people_rounded, 'Student Reports'),
        _NavItem(Icons.campaign_rounded, 'My Announcements'),
      ];
    } else {
      return [
        _NavItem(Icons.dashboard_rounded, 'Overview'),
        _NavItem(Icons.location_city_rounded, 'Learning Centers'),
        _NavItem(Icons.people_rounded, 'Users'),
        _NavItem(Icons.school_rounded, 'Courses'),
        _NavItem(Icons.map_rounded, 'Districts'),
        _NavItem(Icons.pending_actions_rounded, 'Teacher Approvals'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: AlsColors.primaryDark,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              children: [
                _buildSidebarHeader(),
                const SizedBox(height: 24),
                ..._navItems.asMap().entries.map((entry) {
                  return _buildSidebarItem(
                    entry.value.icon,
                    entry.value.label,
                    _selectedNavIndex == entry.key,
                    () => setState(() => _selectedNavIndex = entry.key),
                  );
                }),
                const Spacer(),
                // System status indicators
                if (_killSwitchActive || _maintenanceActive)
                  _buildSystemStatusBadge(),
                const SizedBox(height: 12),
                _buildRoleSwitcher(),
                const SizedBox(height: 16),
                _buildRefreshButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Main Content Area ──
          Expanded(
            child: Column(
              children: [
                _buildTopNav(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: _buildCurrentPage(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    final navLabel = _navItems[_selectedNavIndex].label;

    switch (navLabel) {
      case 'Overview':
      case 'Teacher Overview':
        return currentView == UserRole.devAdmin
            ? _buildDevOverview()
            : currentView == UserRole.teacher
                ? _buildTeacherOverview()
                : _buildSchoolOverview();
      case 'User Management':
      case 'Users':
        return _buildUserManagement();
      case 'My Courses':
        return _buildTeacherCourses();
      case 'My Sessions':
        return _buildTeacherSessions();
      case 'Student Reports':
        return _buildStudentReports();
      case 'System Controls':
        return _buildSystemControls();
      case 'Activity Logs':
        return _buildActivityLogs();
      case 'Media Library':
        return _buildMediaLibrary();
      case 'Database':
        return _buildDatabasePage();
      case 'Learning Centers':
        return _buildCentersPage();
      case 'Courses':
        return _buildCoursesPage();
      case 'Districts':
        return _buildDistrictsPage();
      case 'Teacher Approvals':
        return _buildTeacherApprovals();
      case 'System Settings':
        return _buildSettingsPage();
      default:
        return _buildDevOverview();
    }
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: Teacher Overview
  // ────────────────────────────────────────────────────────────
  Widget _buildTeacherOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildMetricCard(
              'My Courses',
              '$_totalCourses',
              Icons.menu_book,
              AlsColors.primary,
            ),
            _buildMetricCard(
              'Assigned Students',
              '$_totalStudents',
              Icons.people,
              AlsColors.strandCommunication,
            ),
            _buildMetricCard(
              'Upcoming Sessions',
              '3', // TODO: Pull real count from SessionService
              Icons.event,
              AlsColors.warning,
            ),
            _buildMetricCard(
              'Avg Class Mastery',
              '$_avgMastery%',
              Icons.trending_up,
              AlsColors.success,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildQuickAction(
              'Create New Lesson',
              Icons.add_circle_outline,
              AlsColors.primary,
              () => _selectedNavIndex = 1, // Go to My Courses
            ),
            const SizedBox(width: 12),
            _buildQuickAction(
              'Schedule a Session',
              Icons.calendar_today,
              AlsColors.secondary,
              () => _selectedNavIndex = 2, // Go to My Sessions
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeacherCourses() {
    // For teachers, we reuse _buildCoursesPage but eventually we'll filter it
    return _buildCoursesPage();
  }

  Widget _buildTeacherSessions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Scheduled Sessions',
                style: Theme.of(context).textTheme.titleMedium),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement Session creation dialog for web
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content:
                          Text('Please use the mobile app to manage sessions.')),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('New Session'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildEmptyState('No sessions found for your account.'),
      ],
    );
  }

  Widget _buildStudentReports() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Student Progress Reports',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        _buildDataTable(
          ['Student Name', 'Course', 'Progress', 'Last Activity'],
          [
            ['Juan Dela Cruz', 'Basic Literacy', '85%', '2 hours ago'],
            ['Maria Santos', 'Digital Literacy', '45%', 'Yesterday'],
          ],
        ),
      ],
    );
  }

  // ── Sidebar Components ──
  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ALS-LMS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Admin Portal',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? Colors.white12 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.white : Colors.white60,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white60,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSystemStatusBadge() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AlsColors.error.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AlsColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            _killSwitchActive ? Icons.dangerous : Icons.construction,
            color: AlsColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _killSwitchActive ? 'KILL SWITCH ACTIVE' : 'MAINTENANCE MODE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Switch View',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _roleButton(UserRole.devAdmin, 'Dev Admin'),
              const SizedBox(width: 8),
              _roleButton(UserRole.schoolAdmin, 'School'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleButton(UserRole role, String label) {
    bool active = currentView == role;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          currentView = role;
          _selectedNavIndex = 0;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AlsColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : Colors.white60,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: _loadData,
        icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
        label: const Text(
          'Refresh Data',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24),
        ),
      ),
    );
  }

  Widget _buildTopNav() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AlsColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            _navItems[_selectedNavIndex].label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          if (_killSwitchActive)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AlsColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AlsColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dangerous, size: 14, color: AlsColors.error),
                  const SizedBox(width: 4),
                  Text(
                    'SYSTEM LOCKED',
                    style: TextStyle(
                      color: AlsColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            currentView == UserRole.devAdmin
                ? 'Dev Admin'
                : currentView == UserRole.teacher
                    ? 'Teacher Portal'
                    : 'School Admin',
            style: TextStyle(color: AlsColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            backgroundColor: AlsColors.primarySurface,
            child: Icon(Icons.person, color: AlsColors.primary),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: Dev Admin Overview (Global Analytics)
  // ────────────────────────────────────────────────────────────
  Widget _buildDevOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: User metrics
        Row(
          children: [
            _buildMetricCard(
              'Total Users',
              '$_totalUsers',
              Icons.people,
              AlsColors.primary,
            ),
            _buildMetricCard(
              'Students',
              '$_totalStudents',
              Icons.school,
              AlsColors.strandCommunication,
            ),
            _buildMetricCard(
              'Teachers',
              '$_totalTeachers',
              Icons.person,
              AlsColors.strandMath,
            ),
            _buildMetricCard(
              'Courses',
              '$_totalCourses',
              Icons.menu_book,
              AlsColors.secondary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: System metrics
        Row(
          children: [
            _buildMetricCard(
              'Centers',
              '$_totalCenters',
              Icons.location_city,
              AlsColors.strandDigital,
            ),
            _buildMetricCard(
              'Enrollments',
              '$_totalEnrollments',
              Icons.how_to_reg,
              AlsColors.strandSociety,
            ),
            _buildMetricCard(
              'Storage',
              '$_totalStorage GB',
              Icons.cloud,
              AlsColors.strandScience,
            ),
            _buildMetricCard(
              'Avg Mastery',
              '$_avgMastery%',
              Icons.trending_up,
              AlsColors.accent,
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Quick actions
        Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildQuickAction(
              _killSwitchActive
                  ? 'Deactivate Kill Switch'
                  : 'Activate Kill Switch',
              _killSwitchActive ? Icons.lock_open : Icons.dangerous,
              _killSwitchActive ? AlsColors.secondary : AlsColors.error,
              () => _toggleKillSwitch(),
            ),
            const SizedBox(width: 12),
            _buildQuickAction(
              _maintenanceActive ? 'End Maintenance' : 'Start Maintenance',
              _maintenanceActive ? Icons.check_circle : Icons.construction,
              _maintenanceActive ? AlsColors.secondary : AlsColors.warning,
              () => _toggleMaintenance(),
            ),
          ],
        ),

        const SizedBox(height: 32),
        Text(
          'Recent Registrations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _buildDataTable(
          ['Name', 'Email', 'Role', 'Status'],
          _recentUsers
              .take(10)
              .map(
                (u) => [
                  u['full_name']?.toString() ?? 'N/A',
                  u['email']?.toString() ?? 'N/A',
                  u['role']?.toString() ?? 'student',
                  (u['is_active'] == true) ? 'Active' : 'Inactive',
                ],
              )
              .toList(),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: School Admin Overview
  // ────────────────────────────────────────────────────────────
  Widget _buildSchoolOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildMetricCard(
              'Districts',
              '$_totalDistricts',
              Icons.map,
              AlsColors.primary,
            ),
            _buildMetricCard(
              'Centers',
              '$_totalCenters',
              Icons.location_city,
              AlsColors.strandDigital,
            ),
            _buildMetricCard(
              'Teachers',
              '$_totalTeachers',
              Icons.person,
              AlsColors.strandMath,
            ),
            _buildMetricCard(
              'Students',
              '$_totalStudents',
              Icons.school,
              AlsColors.strandCommunication,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMetricCard(
              'Courses',
              '$_totalCourses',
              Icons.menu_book,
              AlsColors.secondary,
            ),
            _buildMetricCard(
              'Enrollments',
              '$_totalEnrollments',
              Icons.how_to_reg,
              AlsColors.strandSociety,
            ),
            _buildMetricCard(
              'Avg Mastery',
              '$_avgMastery%',
              Icons.trending_up,
              AlsColors.accent,
            ),
            Expanded(child: Container()),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'Learning Centers',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _centers.isEmpty
            ? _buildEmptyState(
                'No learning centers yet. Add one from the Learning Centers tab.',
              )
            : _buildDataTable(
                ['Name', 'Region', 'Province', 'Status'],
                _centers
                    .map(
                      (c) => [
                        c.name,
                        c.region,
                        c.province ?? 'N/A',
                        c.isActive ? 'Active' : 'Inactive',
                      ],
                    )
                    .toList(),
              ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: User Management (with role editing)
  // ────────────────────────────────────────────────────────────
  Widget _buildUserManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('All Users', style: Theme.of(context).textTheme.titleMedium),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _recentUsers.isEmpty
            ? _buildEmptyState('No users registered yet.')
            : Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AlsColors.divider),
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AlsColors.surface),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Name',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Email',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Role',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Actions',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  rows: _recentUsers.map((u) {
                    final role = u['role']?.toString() ?? 'student';
                    final isActive = u['is_active'] == true;
                    return DataRow(
                      cells: [
                        DataCell(Text(u['full_name']?.toString() ?? 'N/A')),
                        DataCell(Text(u['email']?.toString() ?? 'N/A')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleBadgeColor(
                                role,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              role.replaceAll('_', ' '),
                              style: TextStyle(
                                color: _getRoleBadgeColor(role),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (isActive
                                      ? AlsColors.success
                                      : AlsColors.error)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: isActive
                                    ? AlsColors.success
                                    : AlsColors.error,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          currentView == UserRole.devAdmin
                              ? PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'promote_school',
                                      child: Text('Promote to School Admin'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'set_teacher',
                                      child: Text('Set as Teacher'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'set_student',
                                      child: Text('Set as Student'),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      value:
                                          isActive ? 'deactivate' : 'activate',
                                      child: Text(
                                        isActive ? 'Deactivate' : 'Activate',
                                      ),
                                    ),
                                  ],
                                  onSelected: (action) =>
                                      _handleUserAction(u, action),
                                )
                              : const Text(
                                  '—',
                                  style: TextStyle(color: Colors.grey),
                                ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: System Controls (Kill Switch + Maintenance)
  // ────────────────────────────────────────────────────────────
  Widget _buildSystemControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency Controls',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Use these controls to manage system availability. Students will see a maintenance/locked screen, but offline studying via SQLite remains active.',
          style: TextStyle(color: AlsColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // Kill Switch Card
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _killSwitchActive ? AlsColors.error : AlsColors.divider,
              width: _killSwitchActive ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (_killSwitchActive
                            ? AlsColors.error
                            : AlsColors.textHint)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.dangerous,
                    size: 36,
                    color: _killSwitchActive
                        ? AlsColors.error
                        : AlsColors.textHint,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kill Switch',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _killSwitchActive
                            ? '⚠️ ACTIVE — All cloud operations are halted!'
                            : 'Halt all cloud operations with a single click.',
                        style: TextStyle(
                          color: _killSwitchActive
                              ? AlsColors.error
                              : AlsColors.textSecondary,
                          fontWeight: _killSwitchActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Users will see "Network Locked" screen.',
                        style: TextStyle(
                          color: AlsColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _toggleKillSwitch,
                    icon: Icon(
                      _killSwitchActive ? Icons.lock_open : Icons.dangerous,
                    ),
                    label: Text(_killSwitchActive ? 'DEACTIVATE' : 'ACTIVATE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _killSwitchActive
                          ? AlsColors.secondary
                          : AlsColors.error,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Maintenance Mode Card
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _maintenanceActive ? AlsColors.warning : AlsColors.divider,
              width: _maintenanceActive ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (_maintenanceActive
                            ? AlsColors.warning
                            : AlsColors.textHint)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.construction,
                    size: 36,
                    color: _maintenanceActive
                        ? AlsColors.warning
                        : AlsColors.textHint,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Maintenance Mode',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _maintenanceActive
                            ? '🔧 ACTIVE — System is in maintenance mode.'
                            : 'Enable scheduled maintenance window.',
                        style: TextStyle(
                          color: _maintenanceActive
                              ? AlsColors.warning
                              : AlsColors.textSecondary,
                          fontWeight: _maintenanceActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Users will see "System Under Maintenance" screen.',
                        style: TextStyle(
                          color: AlsColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _toggleMaintenance,
                    icon: Icon(
                      _maintenanceActive
                          ? Icons.check_circle
                          : Icons.construction,
                    ),
                    label: Text(_maintenanceActive ? 'END' : 'START'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _maintenanceActive
                          ? AlsColors.secondary
                          : AlsColors.warning,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: Activity Logs (Dev Admin)
  // ────────────────────────────────────────────────────────────
  Widget _buildActivityLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'System Activity Logs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ElevatedButton.icon(
              onPressed: () async {
                _activityLogs = await _systemService.getActivityLogs(limit: 50);
                setState(() {});
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Monitor actions from all roles to detect anomalies.',
          style: TextStyle(color: AlsColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _activityLogs.isEmpty
            ? _buildEmptyState(
                'No activity logs yet. Actions will be recorded as users interact with the system.',
              )
            : _buildDataTable(
                ['Action', 'Resource', 'Role', 'Time'],
                _activityLogs
                    .map(
                      (log) => [
                        log.action,
                        '${log.resourceType}${log.resourceId != null ? ' (${log.resourceId!.substring(0, 8)}...)' : ''}',
                        log.userRole ?? 'N/A',
                        log.createdAt != null
                            ? '${log.createdAt!.day}/${log.createdAt!.month} ${log.createdAt!.hour}:${log.createdAt!.minute.toString().padLeft(2, '0')}'
                            : 'N/A',
                      ],
                    )
                    .toList(),
              ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: Learning Centers (School Admin)
  // ────────────────────────────────────────────────────────────
  Widget _buildCentersPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Learning Centers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ElevatedButton.icon(
              onPressed: _showAddCenterDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Center'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Manage physical or logical learning centers. Assign teachers to manage each center.',
          style: TextStyle(color: AlsColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _centers.isEmpty
            ? _buildEmptyState(
                'No learning centers added yet. Click "Add Center" to create one.',
              )
            : Column(
                children:
                    _centers.map((center) => _buildCenterCard(center)).toList(),
              ),
      ],
    );
  }

  Widget _buildCenterCard(LearningCenter center) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AlsColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.location_city,
                color: AlsColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    center.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${center.region}${center.province != null ? ' • ${center.province}' : ''}',
                    style: TextStyle(
                      color: AlsColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (center.physicalAddress != null)
                    Text(
                      center.physicalAddress!,
                      style: TextStyle(color: AlsColors.textHint, fontSize: 12),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (center.isActive ? AlsColors.success : AlsColors.error)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                center.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: center.isActive ? AlsColors.success : AlsColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.people_outline, size: 20),
              tooltip: 'Manage Teachers',
              onPressed: () => _showTeacherAssignment(center),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: AlsColors.error,
              ),
              tooltip: 'Delete Center',
              onPressed: () => _deleteCenter(center),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: Courses
  // ────────────────────────────────────────────────────────────
  Widget _buildCoursesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('All Courses', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _showCreateCourseDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Course'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Manage courses, modules, and lessons.',
          style: TextStyle(color: AlsColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _courses.isEmpty
            ? _buildEmptyState(
                'No courses yet. Click "Create Course" to add one.',
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _courses.length,
                itemBuilder: (context, index) {
                  final course = _courses[index];
                  return _buildCourseManagementCard(course);
                },
              ),
      ],
    );
  }

  Widget _buildCourseManagementCard(Map<String, dynamic> course) {
    final title = course['title']?.toString() ?? 'Untitled';
    final strand = (course['strand']?.toString() ?? '').replaceAll('_', ' ');
    final isPublished = course['is_published'] == true;
    final courseId = course['id'] as String;
    final pinCode = course['pin_code']?.toString() ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AlsColors.primarySurface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(strand,
                  style: TextStyle(
                      fontSize: 11,
                      color: AlsColors.primary,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 8),
            Icon(
              isPublished ? Icons.visibility : Icons.visibility_off,
              size: 14,
              color: isPublished ? AlsColors.success : AlsColors.textHint,
            ),
            const SizedBox(width: 4),
            Text(isPublished ? 'Published' : 'Draft',
                style: TextStyle(fontSize: 11, color: AlsColors.textSecondary)),
            const SizedBox(width: 12),
            Text('PIN: $pinCode',
                style: TextStyle(fontSize: 11, color: AlsColors.textSecondary)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showAddModuleDialog(courseId),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Module'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<List<Module>>(
            future: CourseService().getModules(courseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final modules = snapshot.data ?? [];
              if (modules.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No modules yet. Add one above.'),
                );
              }
              return Column(
                children: modules.map((module) {
                  final moduleTitle = module.title;
                  final moduleId = module.id;
                  return ExpansionTile(
                    leading: const Icon(Icons.view_module, size: 20),
                    title:
                        Text(moduleTitle, style: const TextStyle(fontSize: 14)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 4),
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showAddLessonDialog(moduleId),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Lesson'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FutureBuilder<List<Lesson>>(
                        future: CourseService().getLessons(moduleId),
                        builder: (context, lessonSnap) {
                          if (lessonSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: Center(
                                  child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))),
                            );
                          }
                          final lessons = lessonSnap.data ?? [];
                          if (lessons.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text('No lessons yet.',
                                  style: TextStyle(fontSize: 12)),
                            );
                          }
                          return Column(
                            children: lessons.map((lesson) {
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.article, size: 18),
                                title: Text(
                                  lesson.title,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: Text(
                                  lesson.contentType.name.replaceAll('_', ' '),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: Districts
  // ────────────────────────────────────────────────────────────
  Widget _buildDistrictsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Districts', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        _districts.isEmpty
            ? _buildEmptyState('No districts added yet.')
            : _buildDataTable(
                ['Name', 'Region'],
                _districts
                    .map(
                      (d) => [
                        d['name']?.toString() ?? 'N/A',
                        d['region']?.toString() ?? 'N/A',
                      ],
                    )
                    .toList(),
              ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: Database
  // ────────────────────────────────────────────────────────────
  Widget _buildDatabasePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Database Tables', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        _buildDataTable(
          ['Table', 'Description'],
          [
            ['users', 'User profiles (students, teachers, admins)'],
            ['districts', 'Regional districts'],
            ['cohorts', 'Barangay-level learning groups'],
            ['learning_centers', 'Physical/logical learning centers'],
            ['center_teachers', 'Teacher assignments to centers'],
            ['courses', 'Curriculum courses (with QR/PIN codes)'],
            ['course_enrollments', 'Student-course enrollment records'],
            ['modules', 'Learning modules per course'],
            ['lessons', 'Individual lessons with content'],
            ['quizzes', 'Assessments per lesson/module'],
            ['module_progress', 'Student mastery tracking'],
            ['scores', 'Quiz attempt results'],
            ['announcements', 'Teacher announcements to course cohorts'],
            ['announcement_comments', 'Student comments on announcements'],
            ['attendance', 'Field attendance records'],
            ['system_settings', 'Kill switch & maintenance mode settings'],
            ['activity_logs', 'System-wide activity audit trail'],
            ['sync_metadata', 'Device sync telemetry'],
          ],
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: Teacher Approvals
  // ────────────────────────────────────────────────────────────
  Widget _buildTeacherApprovals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pending Teacher Approvals',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 12),
            if (_pendingTeachers.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AlsColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AlsColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  '${_pendingTeachers.length} pending',
                  style: TextStyle(
                    color: AlsColors.warning,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Review and approve teacher registration requests.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AlsColors.textSecondary),
        ),
        const SizedBox(height: 20),
        if (_pendingTeachers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: AlsColors.success,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending approvals',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AlsColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AlsColors.primarySurface,
                ),
                columns: const [
                  DataColumn(label: Text('Full Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Employee ID')),
                  DataColumn(label: Text('Requested')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _pendingTeachers.map((teacher) {
                  final createdAt = teacher['created_at'] != null
                      ? DateTime.tryParse(
                          teacher['created_at'],
                        )?.toLocal().toString().substring(0, 16)
                      : '—';
                  return DataRow(
                    cells: [
                      DataCell(Text(teacher['full_name'] ?? '—')),
                      DataCell(Text(teacher['email'] ?? '—')),
                      DataCell(Text(teacher['employee_id'] ?? '—')),
                      DataCell(Text(createdAt ?? '—')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.icon(
                              onPressed: () =>
                                  _approveTeacher(teacher['id'] as String),
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Approve'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AlsColors.success,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _rejectTeacher(teacher['id'] as String),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AlsColors.error,
                                side: BorderSide(color: AlsColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _approveTeacher(String teacherId) async {
    try {
      final client = SupabaseConfig.client;
      await client
          .from('profiles')
          .update({'approval_status': 'approved'}).eq('id', teacherId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Teacher approved successfully.'),
            backgroundColor: AlsColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: AlsColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _rejectTeacher(String teacherId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Teacher?'),
        content: const Text(
          'This will deny access. The teacher will need to re-register.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AlsColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final client = SupabaseConfig.client;
      await client
          .from('profiles')
          .update({'approval_status': 'rejected'}).eq('id', teacherId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Teacher rejected.'),
            backgroundColor: AlsColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: AlsColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  // PAGE: Settings
  // ────────────────────────────────────────────────────────────
  Widget _buildSettingsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System Settings', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Supabase Project',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _buildSettingRow('Project ID', 'pgfhypaqpzypjofbyugi'),
                _buildSettingRow('Region', 'Southeast Asia'),
                _buildSettingRow(
                  'Status',
                  _killSwitchActive
                      ? 'LOCKED'
                      : (_maintenanceActive ? 'MAINTENANCE' : 'Active'),
                ),
                _buildSettingRow(
                  'Kill Switch',
                  _killSwitchActive ? 'ACTIVE' : 'OFF',
                ),
                _buildSettingRow(
                  'Maintenance',
                  _maintenanceActive ? 'ACTIVE' : 'OFF',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: value == 'ACTIVE' || value == 'LOCKED'
                  ? AlsColors.error
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable Widgets ──
  Widget _buildMetricCard(
    String label,
    String val,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.only(right: 12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
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
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      val,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable(List<String> headers, List<List<String>> rows) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AlsColors.divider),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AlsColors.surface),
        columns: headers
            .map(
              (h) => DataColumn(
                label: Text(
                  h,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            )
            .toList(),
        rows: rows
            .map(
              (r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList()),
            )
            .toList(),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AlsColors.textHint),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: AlsColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Action Handlers ──

  Future<void> _toggleKillSwitch() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _killSwitchActive
              ? 'Deactivate Kill Switch?'
              : '⚠️ Activate Kill Switch?',
        ),
        content: Text(
          _killSwitchActive
              ? 'This will restore normal cloud operations for all users.'
              : 'This will HALT ALL cloud operations. Students, Teachers, and School Admins will see a "Network Locked" screen. Offline studying via SQLite remains active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _killSwitchActive ? AlsColors.secondary : AlsColors.error,
            ),
            child: Text(_killSwitchActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (_killSwitchActive) {
          await _systemService.deactivateKillSwitch();
        } else {
          await _systemService.activateKillSwitch(
            reason: 'Emergency halt activated by admin',
          );
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AlsColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleMaintenance() async {
    try {
      if (_maintenanceActive) {
        await _systemService.disableMaintenance();
      } else {
        await _systemService.enableMaintenance(
          message:
              'System under scheduled maintenance. Please try again later.',
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AlsColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleUserAction(
    Map<String, dynamic> user,
    String action,
  ) async {
    final userId = user['id'] as String?;
    if (userId == null) return;

    try {
      switch (action) {
        case 'promote_school':
          await _systemService.updateUserRole(
            userId: userId,
            newRole: UserRole.schoolAdmin,
          );
          break;
        case 'set_teacher':
          await _systemService.updateUserRole(
            userId: userId,
            newRole: UserRole.teacher,
          );
          break;
        case 'set_student':
          await _systemService.updateUserRole(
            userId: userId,
            newRole: UserRole.student,
          );
          break;
        case 'deactivate':
          await _systemService.toggleUserActive(userId, false);
          break;
        case 'activate':
          await _systemService.toggleUserActive(userId, true);
          break;
      }
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User updated successfully!'),
            backgroundColor: AlsColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AlsColors.error,
          ),
        );
      }
    }
  }

  void _showAddCenterDialog() {
    final nameCtrl = TextEditingController();
    final regionCtrl = TextEditingController();
    final provinceCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Learning Center'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Center Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: regionCtrl,
                decoration: const InputDecoration(labelText: 'Region *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: provinceCtrl,
                decoration: const InputDecoration(labelText: 'Province'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Physical Address',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  regionCtrl.text.trim().isEmpty) return;
              try {
                await _centerService.createCenter(
                  name: nameCtrl.text.trim(),
                  region: regionCtrl.text.trim(),
                  province: provinceCtrl.text.trim().isNotEmpty
                      ? provinceCtrl.text.trim()
                      : null,
                  physicalAddress: addressCtrl.text.trim().isNotEmpty
                      ? addressCtrl.text.trim()
                      : null,
                );
                Navigator.pop(context);
                _loadData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AlsColors.error,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showTeacherAssignment(LearningCenter center) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Teachers at ${center.name}'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _centerService.getCenterTeachers(center.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final teachers = snapshot.data ?? [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAssignTeacherDialog(center),
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Assign Teacher'),
                  ),
                  const SizedBox(height: 16),
                  if (teachers.isEmpty)
                    const Center(child: Text('No teachers assigned yet.'))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: teachers.length,
                        itemBuilder: (context, index) {
                          final t = teachers[index];
                          final profile = t; // Each row is already a user map from getCenterTeachers()
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(
                              profile?['full_name']?.toString() ?? 'Teacher',
                            ),
                            subtitle: Text(profile?['email']?.toString() ?? ''),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: AlsColors.error,
                              ),
                              onPressed: () async {
                                await _centerService.removeTeacher(
                                  centerId: center.id,
                                  teacherId: t['teacher_id'] as String,
                                );
                                Navigator.pop(context);
                                _showTeacherAssignment(center);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAssignTeacherDialog(LearningCenter center) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Teacher'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: FutureBuilder<List<Profile>>(
            future: _centerService.getAvailableTeachers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final teachers = snapshot.data ?? [];
              if (teachers.isEmpty) {
                return const Center(child: Text('No teachers available.'));
              }
              return ListView.builder(
                itemCount: teachers.length,
                itemBuilder: (context, index) {
                  final teacher = teachers[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(teacher.fullName),
                    subtitle: Text(teacher.email ?? ''),
                    onTap: () async {
                      try {
                        await _centerService.assignTeacher(
                          centerId: center.id,
                          teacherId: teacher.id,
                        );
                        Navigator.pop(context); // Close picker
                        Navigator.pop(context); // Close teacher assignment
                        _showTeacherAssignment(center); // Refresh
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: AlsColors.error,
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCenter(LearningCenter center) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Center?'),
        content: Text(
          'Are you sure you want to delete "${center.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AlsColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _centerService.deleteCenter(center.id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AlsColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildMediaLibrary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Library & Storage Test',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Test and manage teacher content uploads (Videos, PDFs, Images).',
                  style: TextStyle(
                    color: AlsColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _pickAndUploadMedia,
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Upload Content'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Bucket Overview
        Row(
          children: [
            _buildBucketInfoCard(
              'Lessons Media',
              'Course materials, videos, and PDFs.',
              Icons.video_library_rounded,
              AlsColors.primary,
            ),
            const SizedBox(width: 16),
            _buildBucketInfoCard(
              'Profile Pictures',
              'User profile images and identity assets.',
              Icons.account_circle_rounded,
              AlsColors.secondary,
            ),
          ],
        ),
        const SizedBox(height: 32),

        Text('Media Inventory', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildMediaTable(),
      ],
    );
  }

  Widget _buildBucketInfoCard(
    String name,
    String desc,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AlsColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      color: AlsColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTable() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      // Use the cached future from _loadData so rebuild doesn't re-query (M-2)
      future: _mediaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                'Failed to load media: ${snapshot.error}',
                style: TextStyle(color: AlsColors.error),
              ),
            ),
          );
        }
        final mediaList = snapshot.data ?? [];
        if (mediaList.isEmpty) {
          return _buildEmptyState(
            'No media files uploaded yet. Start by uploading a test PDF or Video.',
          );
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AlsColors.divider),
          ),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('File Name')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Lesson/Context')),
              DataColumn(label: Text('Size')),
              DataColumn(label: Text('Actions')),
            ],
            rows: mediaList.map((m) {
              final type = m['file_type']?.toString() ?? 'document';
              final size = (m['file_size_bytes'] as num?) ?? 0;
              final sizeMb = (size / (1024 * 1024)).toStringAsFixed(2);

              return DataRow(
                cells: [
                  DataCell(Text(m['file_name']?.toString() ?? 'Untitled')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getMediaColor(type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: _getMediaColor(type),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      (m['lessons'] as Map?)?['title']?.toString() ?? 'General',
                    ),
                  ),
                  DataCell(Text('$sizeMb MB')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          onPressed: () {
                            // TODO: Implement URL launching for testing
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('File URL: ${m['storage_url']}'),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AlsColors.error,
                          ),
                          onPressed: () async {
                            await _mediaService.deleteMedia(
                              LessonMedia.fromJson(m),
                            );
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Color _getMediaColor(String type) {
    switch (type) {
      case 'video':
        return Colors.redAccent;
      case 'pdf':
        return Colors.orangeAccent;
      case 'image':
        return Colors.blueAccent;
      case 'audio':
        return Colors.purpleAccent;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _pickAndUploadMedia() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'mp4', 'png', 'jpg', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;

        // Show loading
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading file...'),
            duration: Duration(seconds: 2),
          ),
        );

        // Look up an existing lesson to associate the media with (C-5)
        final lessons =
            await SupabaseConfig.client.from('lessons').select('id').limit(1);
        if ((lessons as List).isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'No lessons exist yet. Create a course → module → lesson first.'),
                backgroundColor: AlsColors.warning,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return; // Abort upload cleanly
        }
        final lessonId = lessons.first['id'] as String;

        final type = _inferFileType(file.extension ?? '');

        await _mediaService.uploadLessonMedia(
          file: file.bytes!,
          fileName: file.name,
          lessonId: lessonId,
          type: type,
        );

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload Successful!'),
              backgroundColor: AlsColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload Failed: $e'),
            backgroundColor: AlsColors.error,
          ),
        );
      }
    }
  }

  MediaFileType _inferFileType(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp4':
      case 'mov':
        return MediaFileType.video;
      case 'pdf':
        return MediaFileType.pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return MediaFileType.image;
      case 'mp3':
      case 'wav':
        return MediaFileType.audio;
      default:
        return MediaFileType.document;
    }
  }

  Color _getRoleBadgeColor(String role) {
    switch (role) {
      case 'student':
        return AlsColors.strandCommunication;
      case 'teacher':
        return AlsColors.strandMath;
      case 'school_admin':
        return AlsColors.secondary;
      case 'dev_admin':
        return AlsColors.error;
      default:
        return AlsColors.textSecondary;
    }
  }

  // ────────────────────────────────────────────────────────────
  // Course / Module / Lesson Creation Dialogs
  // ────────────────────────────────────────────────────────────

  final _courseServiceAdmin = CourseService();

  void _showCreateCourseDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String selectedStrand = 'communication_skills';

    final strands = [
      'communication_skills',
      'scientific_literacy',
      'mathematical_literacy',
      'life_livelihood_skills',
      'digital_literacy',
      'understanding_self_society',
    ];

    // Find teachers from loaded users
    final teachers = _recentUsers.where((u) => u['role'] == 'teacher').toList();
    String? selectedTeacherId =
        teachers.isNotEmpty ? teachers.first['id'] as String? : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Course'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Course Title *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStrand,
                  decoration: const InputDecoration(labelText: 'ALS Strand *'),
                  items: strands
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.replaceAll('_', ' ')),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedStrand = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (teachers.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedTeacherId,
                    decoration:
                        const InputDecoration(labelText: 'Assign Teacher'),
                    items: teachers
                        .map((t) => DropdownMenuItem(
                              value: t['id'] as String?,
                              child: Text(t['full_name']?.toString() ??
                                  t['email']?.toString() ??
                                  'Teacher'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => selectedTeacherId = v);
                    },
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'PIN Code (optional)',
                    hintText: 'e.g. ABC123',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                // Guard: teacher_id cannot be empty string (M-5)
                if (selectedTeacherId == null ||
                    selectedTeacherId!.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Please select a teacher for this course.'),
                    ),
                  );
                  return;
                }
                try {
                  await _courseServiceAdmin.createCourse(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    strand: selectedStrand,
                    teacherId: selectedTeacherId!,
                    pinCode: pinCtrl.text.trim().isNotEmpty
                        ? pinCtrl.text.trim()
                        : null,
                  );
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: const Text('Course created!'),
                      backgroundColor: AlsColors.success,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AlsColors.error,
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddModuleDialog(String courseId) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Module'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Module Title *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              try {
                // Get current module count for order_index
                final existingModules =
                    await _courseServiceAdmin.getModules(courseId);
                await _courseServiceAdmin.createModule(
                  courseId: courseId,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim().isNotEmpty
                      ? descCtrl.text.trim()
                      : null,
                  orderIndex: existingModules.length,
                );
                Navigator.pop(context);
                setState(() {}); // Refresh expansion tiles
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: const Text('Module added!'),
                    backgroundColor: AlsColors.success,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AlsColors.error,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddLessonDialog(String moduleId) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String contentType = 'text';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Lesson'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Lesson Title *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: contentType,
                  decoration: const InputDecoration(labelText: 'Content Type'),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('Text')),
                    DropdownMenuItem(value: 'video', child: Text('Video')),
                    DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                    DropdownMenuItem(
                        value: 'interactive', child: Text('Interactive')),
                    DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => contentType = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Content / Text Body',
                    hintText: 'Lesson content...',
                  ),
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                try {
                  final existingLessons =
                      await _courseServiceAdmin.getLessons(moduleId);
                  await _courseServiceAdmin.createLesson(
                    moduleId: moduleId,
                    title: titleCtrl.text.trim(),
                    contentJson: contentCtrl.text.trim().isNotEmpty
                        ? contentCtrl.text.trim()
                        : null,
                    contentType: contentType,
                    orderIndex: existingLessons.length,
                  );
                  Navigator.pop(context);
                  setState(() {}); // Refresh
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: const Text('Lesson added!'),
                      backgroundColor: AlsColors.success,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AlsColors.error,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}
