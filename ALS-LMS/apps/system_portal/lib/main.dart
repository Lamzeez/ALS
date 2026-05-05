import 'package:flutter/material.dart';
import 'package:backend_services/backend_services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_core/shared_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login_screen.dart';
import 'center_registration_review_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('[System Portal] Initialization failed: $e');
  }
  runApp(const AlsSystemPortalApp());
}

class AlsSystemPortalApp extends StatelessWidget {
  const AlsSystemPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ALS System Admin',
      theme: AlsTheme.lightTheme,
      darkTheme: AlsTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SystemAuthGate(),
      },
    );
  }
}

class SystemAuthGate extends StatefulWidget {
  const SystemAuthGate({super.key});

  @override
  State<SystemAuthGate> createState() => _SystemAuthGateState();
}

class _SystemAuthGateState extends State<SystemAuthGate> {
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
    
    if (_profile == null || _profile!.role != UserRole.systemAdmin) {
      return WebLoginScreen(
        onLoginSuccess: (p) {
          if (p.role == UserRole.systemAdmin) {
            setState(() => _profile = p);
          } else {
            AuthService().signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Access Denied: System Admin only.')),
            );
          }
        },
      );
    }

    return SystemDashboard(adminProfile: _profile!);
  }
}

class SystemDashboard extends StatefulWidget {
  final Profile adminProfile;
  const SystemDashboard({super.key, required this.adminProfile});

  @override
  State<SystemDashboard> createState() => _SystemDashboardState();
}

class _SystemDashboardState extends State<SystemDashboard> {
  int _selectedNavIndex = 0;
  final _systemService = SystemService();
  final _centerService = CenterService();

  // Global Data
  int _totalUsers = 0;
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalCenters = 0;
  String _totalStorage = '0.00';
  String _avgMastery = '0.0';
  List<Map<String, dynamic>> _recentUsers = [];
  List<LearningCenter> _centers = [];
  List<ActivityLog> _activityLogs = [];
  bool _isLoading = true;
  bool _killSwitchActive = false;
  bool _maintenanceActive = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseConfig.client;

      // 1. User Stats
      final allProfiles = await client.from('profiles').select('id, role');
      _totalUsers = (allProfiles as List).length;
      _totalStudents = allProfiles.where((u) => u['role'] == 'student').length;
      _totalTeachers = allProfiles.where((u) => u['role'] == 'teacher').length;

      // 2. Recent Activity
      final profiles = await client.from('profiles').select().order('created_at', ascending: false).limit(20);
      _recentUsers = List<Map<String, dynamic>>.from(profiles);

      // 3. Global Entities
      _centers = await _centerService.getCenters();
      _totalCenters = _centers.length;

      // 4. System Logs
      _activityLogs = await _systemService.getActivityLogs(limit: 25);

      // 5. System State
      final settings = await _systemService.getSettings();
      for (final s in settings) {
        if (s.key == 'kill_switch') _killSwitchActive = s.value['active'] == true;
        if (s.key == 'maintenance_mode') _maintenanceActive = s.value['enabled'] == true;
      }

    } catch (e) {
      debugPrint('[System Admin] Load Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_NavItem> get _navItems => [
    _NavItem(Icons.dashboard_rounded, 'Overview'),
    _NavItem(Icons.pending_actions_rounded, 'Registrations'),
    _NavItem(Icons.people_rounded, 'User Management'),
    _NavItem(Icons.security_rounded, 'System Controls'),
    _NavItem(Icons.analytics_rounded, 'Activity Logs'),
    _NavItem(Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
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

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: Colors.black87,
      child: Column(
        children: [
          _buildSidebarHeader(),
          const SizedBox(height: 24),
          ..._navItems.asMap().entries.map((entry) {
            return _buildSidebarItem(entry.value.icon, entry.value.label, _selectedNavIndex == entry.key, () => setState(() => _selectedNavIndex = entry.key));
          }),
          const Spacer(),
          if (_killSwitchActive) _buildAlertBadge('KILL SWITCH ACTIVE'),
          const SizedBox(height: 16),
          _buildRefreshButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    final navLabel = _navItems[_selectedNavIndex].label;
    switch (navLabel) {
      case 'Overview': return _buildOverview();
      case 'Registrations': return const CenterRegistrationReviewPage();
      case 'User Management': return _buildUserMgmt();
      case 'System Controls': return _buildControls();
      case 'Activity Logs': return _buildLogs();
      case 'Settings': return _buildSettings();
      default: return _buildOverview();
    }
  }

  // --- Views ---

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildMetricCard('Total Users', '$_totalUsers', Icons.people, AlsColors.primary),
            _buildMetricCard('Centers', '$_totalCenters', Icons.location_city, AlsColors.strandDigital),
            _buildMetricCard('Students', '$_totalStudents', Icons.school, AlsColors.strandCommunication),
            _buildMetricCard('Teachers', '$_totalTeachers', Icons.person, AlsColors.strandMath),
          ],
        ),
        const SizedBox(height: 32),
        Text('Global Recent Users', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildDataTable(['Name', 'Email', 'Role'], _recentUsers.take(10).map((u) => [u['full_name'] ?? 'N/A', u['email'] ?? 'N/A', u['role'] ?? 'N/A']).toList().cast<List<String>>()),
      ],
    );
  }

  Widget _buildUserMgmt() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Global User Management', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        _buildDataTable(['Name', 'Email', 'Role', 'Status'], _recentUsers.map((u) => [
          u['full_name'] ?? 'N/A',
          u['email'] ?? 'N/A',
          u['role'] ?? 'N/A',
          (u['is_active'] == true) ? 'Active' : 'Inactive',
        ]).toList().cast<List<String>>()),
      ],
    );
  }

  // --- REUSABLE SYSTEM WIDGETS ---

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(28),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ALS-LMS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text('System Administrator', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: isActive ? Colors.white : Colors.white54, size: 20),
      title: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontSize: 14)),
      onTap: onTap,
    );
  }

  Widget _buildTopNav() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AlsColors.divider))),
      child: Row(
        children: [
          Text(_navItems[_selectedNavIndex].label, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          const Icon(Icons.admin_panel_settings, color: AlsColors.error),
          const SizedBox(width: 8),
          const Text('Root Administrator', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String val, IconData icon, Color color) {
    return Expanded(child: Card(margin: const EdgeInsets.only(right: 12), child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
      Icon(icon, color: color, size: 28),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ]),
    ]))));
  }

  Widget _buildDataTable(List<String> headers, List<List<String>> rows) {
    return Container(width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AlsColors.divider)), child: DataTable(
      columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
      rows: rows.map((r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList())).toList(),
    ));
  }

  Widget _buildAlertBadge(String text) {
    return Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(8), color: Colors.red, child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)));
  }

  Widget _buildRefreshButton() => TextButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 14), label: const Text('Reload System Data'));

  Widget _buildControls() => const Center(child: Text('System Controls - Kill Switch & Maintenance'));
  Widget _buildLogs() => const Center(child: Text('Global Audit Logs'));
  Widget _buildSettings() => const Center(child: Text('Global Configuration'));
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}
