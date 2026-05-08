import 'package:flutter/material.dart';
import 'package:backend_services/backend_services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_core/shared_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login_screen.dart';
import 'center_registration_screen.dart';
import 'subject_management_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('[Center Portal] Initialization failed: $e');
  }
  runApp(const AlsCenterPortalApp());
}

class AlsCenterPortalApp extends StatelessWidget {
  const AlsCenterPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '9Class Center Portal',
      theme: AlsTheme.lightTheme,
      darkTheme: AlsTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const CenterAuthGate(),
        '/register': (context) => const CenterRegistrationScreen(),
      },
    );
  }
}

class CenterAuthGate extends StatefulWidget {
  const CenterAuthGate({super.key});

  @override
  State<CenterAuthGate> createState() => _CenterAuthGateState();
}

class _CenterAuthGateState extends State<CenterAuthGate> {
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
    
    if (_profile == null || _profile!.role != UserRole.centerAdmin) {
      return WebLoginScreen(
        onLoginSuccess: (p) {
          if (p.role == UserRole.centerAdmin) {
            setState(() => _profile = p);
          } else {
            AuthService().signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Access Denied: Only Center Admins can log in here.')),
            );
          }
        },
        registrationRoute: '/register', 
      );
    }

    return CenterDashboard(adminProfile: _profile!);
  }
}

class CenterDashboard extends StatefulWidget {
  final Profile adminProfile;
  const CenterDashboard({super.key, required this.adminProfile});

  @override
  State<CenterDashboard> createState() => _CenterDashboardState();
}

class _CenterDashboardState extends State<CenterDashboard> {
  int _selectedNavIndex = 0;
  final _centerService = CenterService();
  
  String? get _myCenterId => widget.adminProfile.alsCenterId;

  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalCourses = 0;
  int _totalEnrollments = 0;
  List<Map<String, dynamic>> _recentUsers = [];
  List<Map<String, dynamic>> _courses = [];
  List<CenterSubject> _offeredSubjects = [];
  LearningCenter? _myCenter;
  List<Map<String, dynamic>> _pendingTeachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_myCenterId == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final courseService = CourseService();
      
      // 1. Center Profiles
      final centerProfiles = await SupabaseConfig.client
          .from('profiles')
          .select('id, role, full_name, email, is_active, created_at')
          .eq('als_center_id', _myCenterId!)
          .order('created_at', ascending: false);
      
      final profilesList = List<Map<String, dynamic>>.from(centerProfiles);
      _recentUsers = profilesList;
      _totalStudents = profilesList.where((u) => u['role'] == 'student').length;
      _totalTeachers = profilesList.where((u) => u['role'] == 'teacher').length;

      // 2. Center Courses
      final courses = await courseService.getCoursesByCenter(_myCenterId!);
      
      // Since we already have the courses from the service (which filters by teachers),
      // we just need to make sure we have teacher names for the UI.
      // We can fetch teacher names for the courses we found.
      final teacherIds = courses.map((c) => c.teacherId).whereType<String>().toSet().toList();
      
      List<Map<String, dynamic>> coursesWithTeachers = [];
      if (teacherIds.isNotEmpty) {
        final teacherProfiles = await SupabaseConfig.client
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', teacherIds);
        
        final teacherMap = {for (var p in teacherProfiles) p['id']: p['full_name']};
        
        coursesWithTeachers = courses.map((c) {
          final json = c.toJson();
          json['profiles'] = {'full_name': teacherMap[c.teacherId] ?? 'Unknown'};
          return json;
        }).toList();
      } else {
        coursesWithTeachers = courses.map((c) => c.toJson()).toList();
      }
      
      _courses = coursesWithTeachers;
      _totalCourses = _courses.length;

      // 3. Offered Subjects
      _offeredSubjects = await courseService.getCenterSubjects(_myCenterId!);

      // 4. Pending Teachers
      final pending = await SupabaseConfig.client
          .from('profiles')
          .select('id, full_name, email, employee_id, created_at')
          .eq('role', 'teacher')
          .eq('approval_status', 'pending')
          .eq('als_center_id', _myCenterId!)
          .order('created_at', ascending: true);
      _pendingTeachers = List<Map<String, dynamic>>.from(pending);
      
      _myCenter = await _centerService.getCenter(_myCenterId!);

    } catch (e) {
      debugPrint('[Center Portal] Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_NavItem> get _navItems => [
    _NavItem(Icons.dashboard_rounded, 'Overview'),
    _NavItem(Icons.how_to_reg_rounded, 'Teacher Approvals'),
    _NavItem(Icons.group_rounded, 'Teachers & Students'),
    _NavItem(Icons.auto_stories_rounded, 'Curriculum'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                          padding: const EdgeInsets.all(40),
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
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildSidebarHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _navItems.asMap().entries.map((entry) {
                return _buildSidebarItem(
                  entry.value.icon,
                  entry.value.label,
                  _selectedNavIndex == entry.key,
                  () => setState(() => _selectedNavIndex = entry.key),
                );
              }).toList(),
            ),
          ),
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
      case 'Teacher Approvals': return _buildApprovals();
      case 'Teachers & Students': return _buildUserDirectory();
      case 'Curriculum': return _buildCurriculumManagement();
      default: return _buildOverview();
    }
  }

  // --- Views ---

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_myCenter != null) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AlsColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.location_city_rounded, color: AlsColors.primary, size: 32),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _myCenter!.name,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '${_myCenter!.region} • ${_myCenter!.address}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],

        Row(
          children: [
            _buildMetricCard('Teachers', '$_totalTeachers', Icons.person_rounded, const Color(0xFF6366F1)),
            _buildMetricCard('Students', '$_totalStudents', Icons.school_rounded, const Color(0xFF10B981)),
            _buildMetricCard('Courses', '$_totalCourses', Icons.auto_stories_rounded, const Color(0xFFF59E0B)),
            _buildMetricCard('Subjects', '${_offeredSubjects.length}', Icons.category_rounded, const Color(0xFF3B82F6)),
          ],
        ),
        const SizedBox(height: 48),
        
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 20),
        Row(
          children: [
            _buildQuickAction('Review Teacher Requests', Icons.pending_actions_rounded, AlsColors.warning, () => setState(() => _selectedNavIndex = 1)),
            const SizedBox(width: 20),
            _buildQuickAction('Manage Curriculum', Icons.settings_suggest_rounded, AlsColors.primary, () => setState(() => _selectedNavIndex = 3)),
          ],
        ),
      ],
    );
  }

  Widget _buildCurriculumManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Curriculum Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const Text('Manage authorized subjects and monitor teacher-led courses.', style: TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 40),

        SubjectManagementView(
          alsCenterId: _myCenterId ?? '',
          onSubjectsChanged: _loadData,
        ),
        
        const SizedBox(height: 56),
        const Text('Active Courses by Subject', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 20),

        if (_offeredSubjects.isEmpty) 
          _buildEmptyState('No subjects defined yet. Add subjects above to see course distribution.')
        else 
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _offeredSubjects.length,
            itemBuilder: (context, index) {
              final subject = _offeredSubjects[index];
              final subjectCourses = _courses.where((c) => c['subject_id'] == subject.id).toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  leading: CircleAvatar(
                    backgroundColor: AlsColors.primary.withValues(alpha: 0.1),
                    child: Text(subject.subjectCode.substring(0, 1), style: const TextStyle(color: AlsColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(subject.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                  subtitle: Text('${subjectCourses.length} Active Courses'),
                  children: [
                    if (subjectCourses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('No courses created for this subject yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                      )
                    else
                      Column(
                        children: subjectCourses.map((course) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          leading: const Icon(Icons.class_rounded, size: 20, color: Color(0xFF64748B)),
                          title: Text(course['title'] ?? 'Untitled Course', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          subtitle: Text('Teacher: ${course['profiles']?['full_name'] ?? 'Unknown'} • Status: ${course['is_published'] == true ? 'Published' : 'Draft'}'),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFCBD5E1)),
                        )).toList(),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildUserDirectory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Teachers & Students', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Manage all accounts linked to this center.', style: TextStyle(color: AlsColors.textSecondary)),
        const SizedBox(height: 24),
        _buildDataTable(
          ['Full Name', 'Email Address', 'Role', 'Account Status'], 
          _recentUsers.map((u) => <String>[
            u['full_name']?.toString() ?? 'N/A',
            u['email']?.toString() ?? 'N/A',
            u['role']?.toString() ?? 'student',
            (u['is_active'] == true) ? 'Active' : 'Inactive',
          ]).toList()
        ),
      ],
    );
  }

  Widget _buildApprovals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Teacher Approvals', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Verify employment before granting access.', style: TextStyle(color: AlsColors.textSecondary)),
        const SizedBox(height: 24),
        if (_pendingTeachers.isEmpty) _buildEmptyState('Great job! No pending teacher requests at the moment.')
        else _buildDataTable(
          ['Applicant Name', 'Email', 'Employee ID', 'Action'], 
          _pendingTeachers.map((t) => <String>[
            t['full_name'] ?? '',
            t['email'] ?? '',
            t['employee_id'] ?? 'N/A',
            'Verify Now'
          ]).toList()
        ),
      ],
    );
  }

  // --- Reusable UI Helpers ---

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(28),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('9Class', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -1)),
          Text('CENTER PORTAL', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isActive ? Colors.white : Colors.white60, size: 20),
        title: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white60, fontSize: 14, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildTopNav() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AlsColors.divider))),
      child: Row(
        children: [
          Text(_navItems[_selectedNavIndex].label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Text('Center Admin', style: TextStyle(color: AlsColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          const CircleAvatar(backgroundColor: AlsColors.primarySurface, child: Icon(Icons.person_rounded, color: AlsColors.primary, size: 20)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String val, IconData icon, Color color) {
    return Expanded(child: Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AlsColors.divider)),
      margin: const EdgeInsets.only(right: 16), 
      child: Padding(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 16),
          Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ))
    ));
  }

  Widget _buildQuickAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(child: InkWell(
      onTap: onTap, 
      borderRadius: BorderRadius.circular(16), 
      child: Container(
        padding: const EdgeInsets.all(24), 
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AlsColors.divider),
          borderRadius: BorderRadius.circular(16)
        ), 
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Spacer(),
          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
        ])
      )
    ));
  }

  Widget _buildDataTable(List<String> headers, List<List<String>> rows) {
    return Container(
      width: double.infinity, 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AlsColors.divider)), 
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AlsColors.surface),
          columns: headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))).toList(),
          rows: rows.map((r) => DataRow(cells: r.map((c) => DataCell(Text(c, style: const TextStyle(fontSize: 13)))).toList())).toList(),
        ),
      )
    );
  }

  Widget _buildRefreshButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16), 
      child: OutlinedButton.icon(
        onPressed: _loadData, 
        icon: const Icon(Icons.sync_rounded, color: Colors.white70, size: 16), 
        label: const Text('Sync Data', style: TextStyle(color: Colors.white70, fontSize: 12)), 
        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
      )
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(child: Padding(padding: const EdgeInsets.all(60), child: Column(children: [
      Icon(Icons.auto_awesome_mosaic_rounded, size: 48, color: AlsColors.textHint),
      const SizedBox(height: 16),
      Text(message, style: TextStyle(color: AlsColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
    ])));
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}
