import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_services/shared_services.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../enrollment/screens/enroll_course_screen.dart';
import '../../courses/screens/course_detail_screen.dart';
import '../../maintenance/screens/maintenance_screen.dart';
import '../screens/settings_screen.dart';

/// Main dashboard screen — enrolled courses from DB, progress tracking,
/// announcements, and maintenance mode handling.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final _courseService = CourseService();
  final _systemService = SystemService();
  final _announcementService = AnnouncementService();

  List<CourseEnrollment> _enrolledCourses = [];
  List<Announcement> _announcements = [];
  Map<String, List<ModuleProgress>> _courseProgress = {};
  bool _isLoadingCourses = true;
  bool _isLoadingAnnouncements = true;
  bool _isMaintenanceMode = false;
  String? _maintenanceMessage;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _checkSystemStatus();
    _loadEnrolledCourses();
    _loadAnnouncements();
  }

  Future<void> _checkSystemStatus() async {
    final locked = await _systemService.isSystemLocked();
    if (locked) {
      final msg = await _systemService.getSystemMessage();
      if (mounted) {
        setState(() {
          _isMaintenanceMode = true;
          _maintenanceMessage = msg;
        });
      }
    }
  }

  Future<void> _loadEnrolledCourses() async {
    setState(() => _isLoadingCourses = true);
    try {
      _enrolledCourses = await _courseService.getEnrolledCourses();
      // Load progress for each course
      for (final enrollment in _enrolledCourses) {
        final courseId = enrollment.courseId;
        try {
          _courseProgress[courseId] =
              await _courseService.getModuleProgress(courseId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoadingAnnouncements = true);
    try {
      _announcements = await _announcementService.getStudentAnnouncements();
    } catch (e) {
      debugPrint('Error loading announcements: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAnnouncements = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _checkSystemStatus(),
      _loadEnrolledCourses(),
      _loadAnnouncements(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isMaintenanceMode) {
      return MaintenanceScreen(
        message: _maintenanceMessage ?? 'System Under Maintenance',
        onRetry: () async {
          await _checkSystemStatus();
          if (!_isMaintenanceMode) {
            _loadEnrolledCourses();
            _loadAnnouncements();
          }
        },
        onStudyOffline: () {
          setState(() => _isMaintenanceMode = false);
        },
      );
    }

    final connectivity = context.read<ConnectivityService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Learning'),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final profile = state is AuthAuthenticated ? state.profile : null;
              final initial = profile?.fullName.isNotEmpty == true
                  ? profile!.fullName[0].toUpperCase()
                  : 'S';
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = 3),
                child: CircleAvatar(
                  backgroundColor: Colors.white24,
                  backgroundImage: profile?.avatarUrl != null
                      ? NetworkImage(profile!.avatarUrl!)
                      : null,
                  child: profile?.avatarUrl == null
                      ? Text(initial,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold))
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          // Online/Offline indicator
          StreamBuilder<bool>(
            stream: connectivity.onConnectivityChanged,
            initialData: connectivity.isOnline,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline
                      ? AlsColors.online.withValues(alpha: 0.2)
                      : AlsColors.offline.withValues(alpha: 0.2),
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
          _buildProgressTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'News',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EnrollCourseScreen(),
                  ),
                );
                if (result == true) {
                  _loadEnrolledCourses();
                }
              },
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan to Join'),
              backgroundColor: AlsColors.accent,
              foregroundColor: AlsColors.textPrimary,
            )
          : null,
    );
  }

  // ────────────────────────────────────────────────────────────
  // Courses Tab — Shows enrolled courses from DB
  // ────────────────────────────────────────────────────────────
  Widget _buildCoursesTab() {
    return RefreshIndicator(
      onRefresh: _loadEnrolledCourses,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Greeting
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final name = state is AuthAuthenticated
                  ? state.profile?.fullName ?? 'Student'
                  : 'Student';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Magandang araw,',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AlsColors.textSecondary,
                        ),
                  ),
                  Text(name, style: Theme.of(context).textTheme.headlineLarge),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Course count chip
          if (!_isLoadingCourses && _enrolledCourses.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AlsColors.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_enrolledCourses.length} Course${_enrolledCourses.length == 1 ? '' : 's'} Enrolled',
                      style: TextStyle(
                        color: AlsColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Courses list or empty state
          if (_isLoadingCourses)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_enrolledCourses.isEmpty)
            _buildEmptyCourseState()
          else
            ..._enrolledCourses.map((enrollment) {
              final course = enrollment.course;
              if (course == null) return const SizedBox.shrink();
              return _buildCourseCard(course, enrollment);
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyCourseState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AlsColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.menu_book_outlined,
                size: 56, color: AlsColors.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 24),
          Text(
            'No Courses Yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AlsColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan a QR code or enter a PIN\nfrom your teacher to get started.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AlsColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Course course, CourseEnrollment enrollment) {
    final title = course.title;
    final description = course.description ?? '';
    final strandStr = course.strand.name;
    final strandColor = _getStrandColor(strandStr);
    final isSelected = false; // Not used in this screen but kept for consistency

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(
                courseId: course.id,
                courseTitle: title,
              ),
            ),
          ).then((_) => _loadEnrolledCourses());
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Strand color bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: strandColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: strandColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            Icon(Icons.menu_book, color: strandColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (description.isNotEmpty)
                              Text(
                                description,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AlsColors.textHint),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Strand chip + status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: strandColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatStrand(strandStr),
                          style: TextStyle(
                            color: strandColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AlsColors.secondarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          enrollment.status.name.toUpperCase(),
                          style: TextStyle(
                            color: AlsColors.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Announcements Tab
  // ────────────────────────────────────────────────────────────
  Widget _buildAnnouncementsTab() {
    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      child: _isLoadingAnnouncements
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.campaign_outlined,
                                size: 80, color: AlsColors.textHint),
                            const SizedBox(height: 16),
                            Text('No Announcements',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(
                              'Announcements from your teachers\nwill appear here.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
              itemCount: _announcements.length,
                  itemBuilder: (context, index) {
                    final ann = _announcements[index];
                    final courseName = ann.course?.title ?? 'Course';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.campaign,
                                    size: 20, color: AlsColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ann.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              courseName,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AlsColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ann.content,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Progress Tab
  // ────────────────────────────────────────────────────────────
  Widget _buildProgressTab() {
    if (_enrolledCourses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights, size: 80, color: AlsColors.textHint),
            const SizedBox(height: 16),
            Text('Progress & Analytics',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Enroll in a course to start\ntracking your mastery scores.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Your Progress',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),

          // Summary cards
          Builder(builder: (context) {
            final allProgress =
                _courseProgress.values.expand((p) => p).toList();
            final completedModules = allProgress
                .where((p) =>
                    p.status == ProgressStatus.completed ||
                    p.status == ProgressStatus.mastered)
                .length;
            final avgMastery = allProgress.isNotEmpty
                ? allProgress.fold<double>(
                        0, (sum, p) => sum + (p.masteryScore ?? 0)) /
                    allProgress.length
                : 0.0;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildProgressMetric(
                        'Courses',
                        '${_enrolledCourses.length}',
                        Icons.auto_stories,
                        AlsColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProgressMetric(
                        'Completed',
                        '$completedModules',
                        Icons.check_circle_outline,
                        AlsColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildProgressMetric(
                        'Avg Mastery',
                        '${avgMastery.toInt()}%',
                        Icons.insights,
                        AlsColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildProgressMetric(
                        'Active',
                        '${_enrolledCourses.where((e) => e.status == EnrollmentStatus.active).length}',
                        Icons.play_circle_outline,
                        AlsColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
          const SizedBox(height: 24),

          Text('Course Details',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),

          ..._enrolledCourses.map((enrollment) {
            final course = enrollment.course;
            if (course == null) return const SizedBox.shrink();
            return _buildProgressCard(course);
          }),
        ],
      ),
    );
  }

  Widget _buildProgressMetric(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label,
              style: TextStyle(color: AlsColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildProgressCard(Course course) {
    final title = course.title;
    final courseId = course.id;
    final progress = _courseProgress[courseId] ?? [];
    final totalModules = progress.length;
    final completedModules = progress
        .where((p) =>
            p.status == ProgressStatus.completed ||
            p.status == ProgressStatus.mastered)
        .length;
    final overallProgress =
        totalModules > 0 ? completedModules / totalModules : 0.0;
    final avgMastery = totalModules > 0
        ? progress.fold<double>(0, (sum, p) => sum + (p.masteryScore ?? 0)) /
            totalModules
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (totalModules > 0)
                  Text(
                    '${avgMastery.toInt()}% mastery',
                    style: TextStyle(
                      color: AlsColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: overallProgress,
                backgroundColor: AlsColors.divider,
                color: overallProgress >= 1.0
                    ? AlsColors.success
                    : AlsColors.secondary,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              totalModules > 0
                  ? '$completedModules of $totalModules modules completed'
                  : 'No modules available yet',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // Per-module breakdown
            if (progress.isNotEmpty) ...[
              const SizedBox(height: 12),
                ...progress.map((p) {
                  final moduleTitle = p.moduleTitle ?? 'Module';
                  final mastery = p.masteryScore ?? 0;
                  final status = p.status.name;
                  final isDone = status == 'completed' || status == 'mastered';
                  final isInProgress = status == 'in_progress';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle
                              : isInProgress
                                  ? Icons.play_circle
                                  : Icons.radio_button_unchecked,
                          size: 16,
                          color: isDone
                              ? AlsColors.success
                              : isInProgress
                                  ? AlsColors.warning
                                  : AlsColors.textHint,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          moduleTitle.toString(),
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${mastery.toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AlsColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Profile Tab
  // ────────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final profile = state is AuthAuthenticated ? state.profile : null;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),
            // Avatar
            Center(
              child: GestureDetector(
                onTap: () {
                  // TODO: Image picker for avatar
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AlsColors.primarySurface,
                      backgroundImage: profile?.avatarUrl != null
                          ? NetworkImage(profile!.avatarUrl!)
                          : null,
                      child: profile?.avatarUrl == null
                          ? Text(
                              profile?.fullName.isNotEmpty == true
                                  ? profile!.fullName[0].toUpperCase()
                                  : 'S',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: AlsColors.primary,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AlsColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                profile?.fullName ?? 'Student',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Center(
              child: Text(
                profile?.email ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (profile?.lrn != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Chip(
                  label: Text('LRN: ${profile!.lrn}'),
                  avatar: const Icon(Icons.badge, size: 16),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Role badge
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AlsColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${profile?.role.toJson().replaceAll('_', ' ').toUpperCase() ?? 'STUDENT'}',
                  style: TextStyle(
                    color: AlsColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              subtitle: const Text('Name, Student ID, Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Downloaded Content'),
              subtitle: const Text('Manage offline content'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDownloadedContentSheet(),
            ),
            ListTile(
              leading: const Icon(Icons.sync_outlined),
              title: const Text('Sync Status'),
              subtitle: Text(_lastSyncTime == null
                  ? 'Last synced: Never'
                  : 'Last synced: ${_formatSyncTime(_lastSyncTime!)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _syncNow(),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: AlsColors.error),
              title: Text('Sign Out', style: TextStyle(color: AlsColors.error)),
              onTap: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
              },
            ),
          ],
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────
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

  String _formatStrand(String strand) {
    return strand
        .replaceAll('_', ' ')
        .split(' ')
        .map(
            (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _formatSyncTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _syncNow() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Syncing…'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    await _refreshAll();
    if (mounted) {
      setState(() => _lastSyncTime = DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sync complete'),
          backgroundColor: AlsColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showDownloadedContentSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AlsColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Icon(Icons.download_done_rounded,
                  size: 48, color: AlsColors.primary),
              const SizedBox(height: 16),
              Text('Downloaded Content',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Offline lesson download will be available in a future update. '
                'Use "Sync" to keep your course list up to date.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AlsColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
