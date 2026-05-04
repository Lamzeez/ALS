import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_services/shared_services.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../student/dashboard/screens/settings_screen.dart';

/// Dashboard for teacher and admin users.
/// Tabs: My Courses | Announcements | Students | Profile
class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _currentIndex = 0;
  final _courseService = CourseService();
  final _announcementService = AnnouncementService();
  final _sessionService = SessionService();
  final _systemService = SystemService();

  List<Course> _courses = [];
  bool _isLoadingCourses = true;
  bool _isMaintenanceMode = false;
  String? _maintenanceMessage;

  // Selected course for student/announcement view
  Course? _selectedCourse;

  @override
  void initState() {
    super.initState();
    _checkSystemStatus();
    _loadCourses();
  }

  Future<void> _checkSystemStatus() async {
    final locked = await _systemService.isSystemLocked();
    if (locked && mounted) {
      final msg = await _systemService.getSystemMessage();
      setState(() {
        _isMaintenanceMode = true;
        _maintenanceMessage = msg;
      });
    }
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoadingCourses = true);
    try {
      _courses = await _courseService.getTeacherCourses();
      if (_courses.isNotEmpty && _selectedCourse == null) {
        _selectedCourse = _courses.first;
      }
    } catch (e) {
      debugPrint('[Teacher] Error loading courses: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCourses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isMaintenanceMode) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction_rounded, size: 64),
              const SizedBox(height: 16),
              Text(_maintenanceMessage ?? 'System Under Maintenance'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await _checkSystemStatus();
                  if (!_isMaintenanceMode) _loadCourses();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Portal'),
        actions: [
          StreamBuilder<bool>(
            stream: context.read<ConnectivityService>().onConnectivityChanged,
            initialData: context.read<ConnectivityService>().isOnline,
            builder: (_, snapshot) {
              final isOnline = snapshot.data ?? false;
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isOnline ? AlsColors.online : AlsColors.offline)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline ? AlsColors.online : AlsColors.offline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildCoursesTab(),
          _buildAnnouncementsTab(),
          _buildSessionsTab(),
          _buildStudentsTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Announce',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Tab 0: My Courses
  // ─────────────────────────────────────────────────────────
  Widget _buildCoursesTab() {
    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: _isLoadingCourses
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 72, color: AlsColors.textHint),
                      const SizedBox(height: 16),
                      Text('No published courses yet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Publish a course from the admin portal\nto see it here.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AlsColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _courses.length,
                  itemBuilder: (_, i) => _buildCourseCard(_courses[i]),
                ),
    );
  }

  Widget _buildCourseCard(Course course) {
    final title = course.title;
    final strand = course.strand;
    final strandName = strand.name;
    final strandColor = _getStrandColor(strandName);
    final isSelected = _selectedCourse?.id == course.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isSelected
            ? BorderSide(color: AlsColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedCourse = course),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 48,
                decoration: BoxDecoration(
                  color: strandColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(_formatStrand(strandName),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AlsColors.textSecondary)),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: AlsColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Tab 1: Announcements
  // ─────────────────────────────────────────────────────────
  Widget _buildAnnouncementsTab() {
    if (_selectedCourse == null) {
      return const Center(child: Text('Select a course first'));
    }
    return _AnnouncementsManager(
      course: _selectedCourse!,
      announcementService: _announcementService,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Tab 2: Sessions
  // ─────────────────────────────────────────────────────────
  Widget _buildSessionsTab() {
    return _SessionsManager(
      sessionService: _sessionService,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Tab 3: Students
  // ─────────────────────────────────────────────────────────
  Widget _buildStudentsTab() {
    if (_selectedCourse == null) {
      return const Center(child: Text('Select a course first'));
    }
    return _StudentsView(
      course: _selectedCourse!,
      courseService: _courseService,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Tab 4: Profile
  // ─────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final profile = state is AuthAuthenticated ? state.profile : null;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AlsColors.primarySurface,
                backgroundImage: profile?.profilePictureUrl != null
                    ? NetworkImage(profile!.profilePictureUrl!)
                    : null,
                child: profile?.profilePictureUrl == null
                    ? Text(
                        profile?.fullName.isNotEmpty == true
                            ? profile!.fullName[0].toUpperCase()
                            : 'T',
                        style:
                            TextStyle(fontSize: 36, color: AlsColors.primary),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                profile?.fullName ?? 'Teacher',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Center(
              child: Text(
                profile?.email ?? '',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AlsColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AlsColors.accentLight.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  profile?.role == UserRole.schoolAdmin
                      ? 'School Admin'
                      : profile?.role == UserRole.devAdmin
                          ? 'Dev Admin'
                          : 'Teacher',
                  style: TextStyle(
                      color: AlsColors.accentDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Account Settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: AlsColors.error),
              title: Text('Sign Out', style: TextStyle(color: AlsColors.error)),
              onTap: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
            ),
          ],
        );
      },
    );
  }

  Color _getStrandColor(String strand) {
    switch (strand) {
      case 'communication_skills':
        return AlsColors.strandCommunication;
      case 'scientific_literacy':
        return AlsColors.strandScience;
      case 'mathematical_literacy':
        return AlsColors.strandMath;
      case 'life_livelihood_skills':
        return AlsColors.strandLife;
      case 'digital_literacy':
        return AlsColors.strandDigital;
      case 'understanding_self_society':
        return AlsColors.strandSociety;
      default:
        return AlsColors.primary;
    }
  }

  String _formatStrand(String strand) =>
      strand.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
}

// ─────────────────────────────────────────────────────────────────────
// Sub-widget: Announcements manager for teacher
// ─────────────────────────────────────────────────────────────────────
class _AnnouncementsManager extends StatefulWidget {
  final Course course;
  final AnnouncementService announcementService;

  const _AnnouncementsManager(
      {required this.course, required this.announcementService});

  @override
  State<_AnnouncementsManager> createState() => _AnnouncementsManagerState();
}

class _AnnouncementsManagerState extends State<_AnnouncementsManager> {
  List<Announcement> _announcements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AnnouncementsManager old) {
    super.didUpdateWidget(old);
    if (old.course.id != widget.course.id) _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _announcements = await widget.announcementService
          .getCourseAnnouncements(widget.course.id);
    } catch (e) {
      debugPrint('[Teacher] Error loading announcements: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _announcements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined,
                              size: 64, color: AlsColors.textHint),
                          const SizedBox(height: 12),
                          Text('No announcements yet',
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _announcements.length,
                      itemBuilder: (_, i) => _buildCard(_announcements[i]),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Announcement'),
      ),
    );
  }

  Widget _buildCard(Announcement a) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: a.isPinned
            ? Icon(Icons.push_pin, color: AlsColors.accentDark)
            : const Icon(Icons.campaign_outlined),
        title: Text(a.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(a.content, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: AlsColors.error),
          onPressed: () async {
            try {
              await widget.announcementService.deleteAnnouncement(a.id);
              _load();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _showCreateSheet() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    bool isPinned = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Announcement',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isPinned,
                        onChanged: (v) =>
                            setSheetState(() => isPinned = v ?? false),
                      ),
                      const Text('Pin this announcement'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final content = contentCtrl.text.trim();
                        if (title.isEmpty || content.isEmpty) return;
                        try {
                          await widget.announcementService.createAnnouncement(
                            courseId: widget.course.id,
                            title: title,
                            content: content,
                            isPinned: isPinned,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Post Announcement'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sub-widget: Students list for teacher
// ─────────────────────────────────────────────────────────────────────
class _StudentsView extends StatefulWidget {
  final Course course;
  final CourseService courseService;

  const _StudentsView({required this.course, required this.courseService});

  @override
  State<_StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<_StudentsView> {
  List<Profile> _enrollments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_StudentsView old) {
    super.didUpdateWidget(old);
    if (old.course.id != widget.course.id) _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _enrollments = await widget.courseService
          .getCourseStudents(widget.course.id);
    } catch (e) {
      debugPrint('[Teacher] Error loading students: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseTitle = widget.course.title;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '$courseTitle — ${_enrollments.length} Student${_enrollments.length == 1 ? '' : 's'}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: _enrollments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 64, color: AlsColors.textHint),
                              const SizedBox(height: 12),
                              Text('No enrolled students yet',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _enrollments.length,
                          itemBuilder: (_, i) {
                            final profile = _enrollments[i];
                            final name = profile.fullName;
                            final email = profile.email ?? '';
                            final studentIdNumber = profile.studentIdNumber;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AlsColors.primarySurface,
                                backgroundImage: profile.profilePictureUrl != null 
                                    ? NetworkImage(profile.profilePictureUrl!) 
                                    : null,
                                child: profile.profilePictureUrl == null 
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                        style: TextStyle(color: AlsColors.primary),
                                      )
                                    : null,
                              ),
                              title: Text(name),
                              subtitle: Text(studentIdNumber != null ? 'LRN: $studentIdNumber' : email),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sub-widget: Sessions manager for teacher
// ─────────────────────────────────────────────────────────────────────
class _SessionsManager extends StatefulWidget {
  final SessionService sessionService;

  const _SessionsManager({required this.sessionService});

  @override
  State<_SessionsManager> createState() => _SessionsManagerState();
}

class _SessionsManagerState extends State<_SessionsManager> {
  List<Session> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.profile != null) {
        _sessions = await widget.sessionService.getTeacherSessions(authState.profile!.id);
      }
    } catch (e) {
      debugPrint('[Teacher] Error loading sessions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_note_outlined, size: 64, color: AlsColors.textHint),
                          const SizedBox(height: 12),
                          Text('No sessions scheduled', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sessions.length,
                      itemBuilder: (_, i) => _buildCard(_sessions[i]),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }

  Widget _buildCard(Session s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AlsColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.event, color: AlsColors.primary),
        ),
        title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.scheduledAt.toLocal()}'.split('.')[0]),
            if (s.location != null) Text('📍 ${s.location}'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(s.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            s.status.name.toUpperCase(),
            style: TextStyle(color: _getStatusColor(s.status), fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.scheduled: return AlsColors.warning;
      case SessionStatus.live: return AlsColors.online;
      case SessionStatus.completed: return AlsColors.success;
      case SessionStatus.cancelled: return AlsColors.error;
    }
  }

  void _showCreateSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Schedule Session', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location')),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Date & Time'),
                  subtitle: Text(selectedDate.toString()),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setSheetState(() => selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final authState = context.read<AuthBloc>().state;
                      if (authState is AuthAuthenticated && authState.profile != null) {
                        await widget.sessionService.createSession(
                          teacherId: authState.profile!.id,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          location: locCtrl.text.trim(),
                          scheduledAt: selectedDate,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      }
                    },
                    child: const Text('Schedule'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}

