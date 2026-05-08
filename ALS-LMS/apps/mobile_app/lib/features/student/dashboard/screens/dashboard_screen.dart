import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_core/shared_core.dart';
import 'package:backend_services/backend_services.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../auth/bloc/auth_bloc.dart';
import '../../enrollment/screens/enroll_course_screen.dart';
import '../../../courses/screens/course_detail_screen.dart';
import '../../../maintenance/screens/maintenance_screen.dart';
import 'settings_screen.dart';

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
  final _downloadsService = DownloadsService();

  List<CourseEnrollment> _enrolledCourses = [];
  List<Announcement> _announcements = [];
  List<Download> _downloads = [];
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

  Future<void> _loadDownloads() async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.profile != null) {
        _downloads = await _downloadsService.getStudentDownloads(authState.profile!.id);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      _checkSystemStatus(),
      _loadEnrolledCourses(),
      _loadAnnouncements(),
      _loadDownloads(),
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
                  backgroundImage: profile?.profilePictureUrl != null
                      ? NetworkImage(profile!.profilePictureUrl!)
                      : null,
                  child: profile?.profilePictureUrl == null
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
          // Downloaded content shortcut
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: () => _showDownloadedContentSheet(),
            tooltip: 'Offline Content',
          ),
          // Online/Offline indicator
          StreamBuilder<bool>(
            stream: connectivity.onConnectivityChanged,
            initialData: connectivity.isOnline,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 16, left: 8),
                child: AlsStatusBadge(
                  label: isOnline ? 'Online' : 'Offline',
                  isOnline: isOnline,
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
          // Greeting ... (previous code)
          
          // Continue Learning Shortcut
          if (!_isLoadingCourses && _enrolledCourses.isNotEmpty) ...[
            _buildContinueLearningSection(),
            const SizedBox(height: 32),
          ],

          // Course count chip
          if (!_isLoadingCourses && _enrolledCourses.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const Icon(Icons.sort_rounded, size: 18, color: AlsColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Your Enrolled Courses (${_enrolledCourses.length})',
                    style: TextStyle(
                      color: AlsColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

  Widget _buildContinueLearningSection() {
    // Find the most recently started module
    ModuleProgress? latestProgress;
    DateTime? latestTime;

    for (final progressList in _courseProgress.values) {
      for (final p in progressList) {
        if (p.startedAt != null && (latestTime == null || p.startedAt!.isAfter(latestTime))) {
          latestTime = p.startedAt;
          latestProgress = p;
        }
      }
    }

    if (latestProgress == null) {
      // If none started, just pick the first enrolled course
      if (_enrolledCourses.isEmpty) return const SizedBox.shrink();
      final firstCourse = _enrolledCourses.first.course;
      if (firstCourse == null) return const SizedBox.shrink();
      
      return _buildResumeCard(
        title: 'Start your journey',
        subtitle: firstCourse.title,
        courseId: firstCourse.id,
        progress: 0,
      );
    }

    final course = _enrolledCourses.firstWhere((e) => e.courseId == latestProgress!.courseId).course;
    if (course == null) return const SizedBox.shrink();

    return _buildResumeCard(
      title: 'Continue Learning',
      subtitle: '${course.title}: ${latestProgress.moduleTitle ?? 'Current Module'}',
      courseId: course.id,
      progress: latestProgress.lessonsViewed / (latestProgress.totalLessons > 0 ? latestProgress.totalLessons : 1),
    );
  }

  Widget _buildResumeCard({
    required String title,
    required String subtitle,
    required String courseId,
    required double progress,
  }) {
    return AlsCard(
      padding: EdgeInsets.zero,
      gradient: const LinearGradient(
        colors: [AlsColors.accent, Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CourseDetailScreen(
              courseId: courseId,
              courseTitle: subtitle.split(':')[0],
            ),
          ),
        ).then((_) => _loadEnrolledCourses());
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                color: Colors.white,
                minHeight: 6,
              ),
            ),
          ],
        ),
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

    return AlsCard(
      padding: EdgeInsets.zero,
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
            height: 8,
            decoration: BoxDecoration(
              color: strandColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: strandColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.auto_stories_rounded, color: strandColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatStrand(strandStr),
                            style: TextStyle(
                              color: strandColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AlsColors.textHint.withValues(alpha: 0.5)),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AlsColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 20),
                // Status and Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AlsTag(
                      label: enrollment.status.name.toUpperCase(),
                      color: enrollment.status == EnrollmentStatus.active 
                          ? AlsColors.success 
                          : AlsColors.warning,
                      icon: enrollment.status == EnrollmentStatus.active 
                          ? Icons.play_circle_fill_rounded 
                          : Icons.pause_circle_filled_rounded,
                    ),
                    Text(
                      'Continue Learning',
                      style: TextStyle(
                        color: AlsColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
                      backgroundImage: profile?.profilePictureUrl != null
                          ? NetworkImage(profile!.profilePictureUrl!)
                          : null,
                      child: profile?.profilePictureUrl == null
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
            if (profile?.studentIdNumber != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Chip(
                  label: Text('LRN: ${profile!.studentIdNumber}'),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
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
              Row(
                children: [
                  Icon(Icons.download_done_rounded, color: AlsColors.primary),
                  const SizedBox(width: 12),
                  Text('Downloaded Content',
                      style: Theme.of(ctx).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              if (_downloads.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off, size: 48, color: AlsColors.textHint),
                      const SizedBox(height: 12),
                      Text(
                        'No offline content yet.\nDownload lessons to study without internet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AlsColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _downloads.length,
                    itemBuilder: (context, index) {
                      final d = _downloads[index];
                      return ListTile(
                        leading: Icon(
                          d.status == DownloadStatus.completed
                              ? Icons.check_circle
                              : Icons.downloading,
                          color: d.status == DownloadStatus.completed
                              ? AlsColors.success
                              : AlsColors.secondary,
                        ),
                        title: Text('Lesson ID: ${d.lessonId}'),
                        subtitle: LinearProgressIndicator(
                          value: d.downloadProgress,
                          backgroundColor: AlsColors.divider,
                          color: AlsColors.secondary,
                        ),
                        trailing: Text('${(d.downloadProgress * 100).toInt()}%'),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

