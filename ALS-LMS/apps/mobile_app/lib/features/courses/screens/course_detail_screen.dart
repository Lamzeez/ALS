import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:backend_services/backend_services.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../announcements/screens/announcements_screen.dart';
import 'lesson_viewer_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _courseService = CourseService();
  final _syncService = OfflineSyncService.instance;

  List<Module> _modules = [];
  Map<String, List<Lesson>> _lessonsByModule = {};
  Map<String, ModuleProgress> _progressMap = {}; // Optimized lookup
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 🚀 Optimized: Fetches all data in parallel to avoid "N+1" delay
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // 1. Fetch basic course structure
      final results = await Future.wait([
        _courseService.getModules(widget.courseId),
        _courseService.getModuleProgress(widget.courseId),
      ]);

      _modules = results[0] as List<Module>;
      final rawProgress = results[1] as List<ModuleProgress>;
      
      // 2. Map progress for O(1) lookup
      _progressMap = {for (var p in rawProgress) p.moduleId: p};

      // 3. Parallel fetch lessons for all modules
      final lessonFutures = _modules.map((m) => _courseService.getLessons(m.id)).toList();
      final allLessons = await Future.wait(lessonFutures);

      for (int i = 0; i < _modules.length; i++) {
        _lessonsByModule[_modules[i].id] = allLessons[i];
      }

    } catch (e) {
      debugPrint('[CourseDetail] Error hydrating screen: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _getModuleMastery(String moduleId) => _progressMap[moduleId]?.masteryScore ?? 0;

  String _getModuleStatus(String moduleId) => _progressMap[moduleId]?.status.name ?? 'not_started';

  int _getLessonsViewed(String moduleId) => _progressMap[moduleId]?.lessonsViewed ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.view_module), text: 'Modules'),
            Tab(icon: Icon(Icons.campaign), text: 'Announcements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildModulesTab(),
          AnnouncementsScreen(
            courseId: widget.courseId,
            courseTitle: widget.courseTitle,
            embedded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildModulesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_modules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: AlsColors.textHint),
            const SizedBox(height: 16),
            Text('No Modules Yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Your teacher hasn\'t added\nmodules to this course yet.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Overall progress calculation
    final totalModules = _modules.length;
    final completedModules = _progressMap.values
        .where((p) => p.status == ProgressStatus.completed || p.status == ProgressStatus.mastered)
        .length;
    final overallProgress = totalModules > 0 ? completedModules / totalModules : 0.0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Overall Progress Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AlsColors.primary, AlsColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Course Progress',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(overallProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: overallProgress,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$completedModules of $totalModules modules completed',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Module List ──
          ...List.generate(_modules.length, (index) {
            final module = _modules[index];
            final moduleId = module.id;
            final lessons = _lessonsByModule[moduleId] ?? [];
            final mastery = _getModuleMastery(moduleId);
            final status = _getModuleStatus(moduleId);
            final lessonsViewed = _getLessonsViewed(moduleId);

            return _buildModuleTile(
              module: module,
              lessons: lessons,
              mastery: mastery,
              status: status,
              lessonsViewed: lessonsViewed,
              index: index,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildModuleTile({
    required Module module,
    required List<Lesson> lessons,
    required double mastery,
    required String status,
    required int lessonsViewed,
    required int index,
  }) {
    final title = module.title;
    final description = module.description ?? '';
    final moduleId = module.id;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'completed':
      case 'mastered':
        statusColor = AlsColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = AlsColors.warning;
        statusIcon = Icons.play_circle_fill;
        break;
      default:
        statusColor = AlsColors.textHint;
        statusIcon = Icons.radio_button_unchecked;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, color: statusColor, size: 28),
            if (mastery > 0)
              Text(
                '${mastery.toInt()}%',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
              ),
          ],
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Text(description, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              '$lessonsViewed/${lessons.length} lessons viewed',
              style: TextStyle(fontSize: 11, color: AlsColors.textSecondary),
            ),
          ],
        ),
        children: [
          if (lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No lessons in this module yet.'),
            )
          else
            ...lessons.map((lesson) {
              final lessonTitle = lesson.title;
              final contentType = lesson.contentType;
              IconData typeIcon;
              switch (contentType) {
                case LessonContentType.video:
                  typeIcon = Icons.play_circle_outline;
                  break;
                case LessonContentType.pdf:
                  typeIcon = Icons.picture_as_pdf;
                  break;
                case LessonContentType.interactive:
                  typeIcon = Icons.touch_app;
                  break;
                default:
                  typeIcon = Icons.article_outlined;
              }

              return ListTile(
                leading: Icon(typeIcon, color: AlsColors.primary),
                title: Text(lessonTitle),
                subtitle: Text(
                  contentType.toJson().replaceAll('_', ' '),
                  style: TextStyle(fontSize: 11, color: AlsColors.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // 🛡️ Reliable Progress Tracking: Uses OfflineSyncService
                  if (status == 'not_started' || status == 'locked') {
                    final studentId = AuthService().currentUser?.id;
                    if (studentId != null) {
                      await _syncService.trackModuleProgress(
                        studentId: studentId,
                        moduleId: moduleId,
                        courseId: widget.courseId,
                        status: 'in_progress',
                      );
                    }
                  }

                  if (!mounted) return;
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LessonViewerScreen(
                        lesson: lesson,
                        moduleId: moduleId,
                        courseId: widget.courseId,
                        moduleLessonsCount: lessons.length,
                      ),
                    ),
                  );
                  if (result == true) _loadData();
                },
              );
            }),
        ],
      ),
    );
  }
}

