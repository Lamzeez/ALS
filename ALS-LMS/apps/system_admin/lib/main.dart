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
    debugPrint('[System Admin] Initialization failed: $e');
  }
  runApp(const AlsSystemAdminApp());
}

class AlsSystemAdminApp extends StatelessWidget {
  const AlsSystemAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '9Class System Admin',
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
              const SnackBar(content: Text('Access Denied: Only System Admins can log in here.')),
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

  int _totalUsers = 0;
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalCenters = 0;
  List<Map<String, dynamic>> _recentUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseConfig.client;
      final allProfiles = await client.from('profiles').select('id, role');
      _totalUsers = (allProfiles as List).length;
      _totalStudents = allProfiles.where((u) => u['role'] == 'student').length;
      _totalTeachers = allProfiles.where((u) => u['role'] == 'teacher').length;

      final profiles = await client.from('profiles').select().order('created_at', ascending: false).limit(20);
      _recentUsers = List<Map<String, dynamic>>.from(profiles);

      final centers = await _centerService.getCenters();
      _totalCenters = centers.length;

    } catch (e) {
      debugPrint('[System Admin] Load Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_NavItem> get _navItems => [
    _NavItem(Icons.dashboard_rounded, 'System Overview'),
    _NavItem(Icons.pending_actions_rounded, 'Registrations'),
    _NavItem(Icons.people_rounded, 'Global Users'),
    _NavItem(Icons.security_rounded, 'System Security'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 280,
            color: Colors.black,
            child: Column(
              children: [
                _buildSidebarHeader(),
                const SizedBox(height: 24),
                ..._navItems.asMap().entries.map((entry) => _buildSidebarItem(entry.value.icon, entry.value.label, _selectedNavIndex == entry.key, () => setState(() => _selectedNavIndex = entry.key))),
                const Spacer(),
                _buildRefreshButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildTopNav(),
                Expanded(
                  child: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(32), child: _buildCurrentPage()),
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
      case 'System Overview': return _buildOverview();
      case 'Registrations': return const CenterRegistrationReviewPage();
      case 'Global Users': return _buildUserMgmt();
      case 'System Security': return const Center(child: Text('Security Controls - Restricted.'));
      default: return _buildOverview();
    }
  }

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _buildMetricCard('Total Users', '$_totalUsers', Icons.people, AlsColors.primary),
          _buildMetricCard('Centers', '$_totalCenters', Icons.location_city, AlsColors.strandDigital),
          _buildMetricCard('Students', '$_totalStudents', Icons.school, AlsColors.strandCommunication),
          _buildMetricCard('Teachers', '$_totalTeachers', Icons.person, AlsColors.strandMath),
        ]),
        const SizedBox(height: 32),
        Text('Global Recent Users', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildDataTable(
          ['Name', 'Email', 'Role'], 
          _recentUsers.take(10).map((u) => <String>[
            u['full_name']?.toString() ?? 'N/A', 
            u['email']?.toString() ?? 'N/A', 
            u['role']?.toString() ?? 'N/A'
          ]).toList()
        ),
      ],
    );
  }

  Widget _buildUserMgmt() => _buildDataTable(
    ['Name', 'Email', 'Role', 'Status'], 
    _recentUsers.map((u) => <String>[
      u['full_name']?.toString() ?? 'N/A', 
      u['email']?.toString() ?? 'N/A', 
      u['role']?.toString() ?? 'N/A', 
      (u['is_active'] == true) ? 'Active' : 'Inactive'
    ]).toList()
  );

  Widget _buildSidebarHeader() => Container(padding: const EdgeInsets.all(28), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('9Class', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text('SYSTEM ADMIN', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))]));
  Widget _buildSidebarItem(IconData icon, String label, bool isActive, VoidCallback onTap) => ListTile(leading: Icon(icon, color: isActive ? Colors.white : Colors.white54, size: 20), title: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontSize: 14)), onTap: onTap);
  Widget _buildTopNav() => Container(height: 72, padding: const EdgeInsets.symmetric(horizontal: 32), decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AlsColors.divider))), child: Row(children: [Text(_navItems[_selectedNavIndex].label, style: Theme.of(context).textTheme.titleLarge), const Spacer(), const Icon(Icons.admin_panel_settings, color: AlsColors.error), const SizedBox(width: 8), const Text('Root Admin', style: TextStyle(fontWeight: FontWeight.bold))]));
  Widget _buildMetricCard(String label, String val, IconData icon, Color color) => Expanded(child: Card(margin: const EdgeInsets.only(right: 12), child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [Icon(icon, color: color, size: 28), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))])]))));
  Widget _buildDataTable(List<String> headers, List<List<String>> rows) => Container(width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AlsColors.divider)), child: DataTable(columns: headers.map((h) => DataColumn(label: Text(h))).toList(), rows: rows.map((r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList())).toList()));
  Widget _buildRefreshButton() => TextButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh, size: 14), label: const Text('Refresh System'));
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}
