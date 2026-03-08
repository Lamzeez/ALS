import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/content_management_viewmodel.dart';

/// Content management page with moderation controls.
class ContentManagementPage extends StatefulWidget {
  const ContentManagementPage({super.key});

  @override
  State<ContentManagementPage> createState() => _ContentManagementPageState();
}

class _ContentManagementPageState extends State<ContentManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContentManagementViewModel>().loadContent();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<ContentManagementViewModel>().loadContent(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lessons'),
            Tab(text: 'Quizzes'),
          ],
        ),
      ),
      body: Consumer<ContentManagementViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.errorMessage != null) {
            return Center(child: Text(vm.errorMessage!));
          }

          return Column(
            children: [
              // Stats row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _StatChip(
                      label: 'Total Lessons',
                      value: '${vm.totalLessons}',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Published',
                      value: '${vm.publishedLessons}',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Drafts',
                      value: '${vm.totalLessons - vm.publishedLessons}',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Quizzes',
                      value: '${vm.quizzes.length}',
                      color: Colors.purple,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search content...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _LessonsTab(vm: vm, searchQuery: _searchQuery),
                    _QuizzesTab(vm: vm, searchQuery: _searchQuery),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LessonsTab extends StatelessWidget {
  final ContentManagementViewModel vm;
  final String searchQuery;

  const _LessonsTab({required this.vm, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final filtered = vm.lessons.where((l) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return l.title.toLowerCase().contains(q) ||
          l.subject.toLowerCase().contains(q) ||
          l.description.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No lessons found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Title')),
          DataColumn(label: Text('Subject')),
          DataColumn(label: Text('Grade')),
          DataColumn(label: Text('Video')),
          DataColumn(label: Text('Published')),
          DataColumn(label: Text('Actions')),
        ],
        rows: filtered.map((lesson) {
          return DataRow(
            cells: [
              DataCell(Text(lesson.title, overflow: TextOverflow.ellipsis)),
              DataCell(Text(lesson.subject)),
              DataCell(Text(lesson.gradeLevel)),
              DataCell(
                Icon(
                  lesson.videoUrl != null
                      ? Icons.videocam
                      : Icons.videocam_off_outlined,
                  color: lesson.videoUrl != null ? Colors.green : Colors.grey,
                  size: 20,
                ),
              ),
              DataCell(
                Switch(
                  value: lesson.isPublished,
                  onChanged: (val) => vm.togglePublish(lesson.id, val),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      tooltip: 'Preview',
                      onPressed: () => _showPreview(context, lesson),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red,
                      ),
                      tooltip: 'Delete',
                      onPressed: () =>
                          _confirmDelete(context, vm, lesson.id, lesson.title),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showPreview(BuildContext context, dynamic lesson) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lesson.title),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subject: ${lesson.subject}'),
              Text('Grade Level: ${lesson.gradeLevel}'),
              Text('Duration: ${lesson.durationMinutes} min'),
              const SizedBox(height: 12),
              Text(lesson.description),
              if (lesson.videoUrl != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Video: ${lesson.videoUrl}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (lesson.studyGuideUrl != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Study Guide: ${lesson.studyGuideUrl}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    ContentManagementViewModel vm,
    String id,
    String title,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              vm.deleteLesson(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _QuizzesTab extends StatelessWidget {
  final ContentManagementViewModel vm;
  final String searchQuery;

  const _QuizzesTab({required this.vm, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final filtered = vm.quizzes.where((q) {
      if (searchQuery.isEmpty) return true;
      final s = searchQuery.toLowerCase();
      return q.title.toLowerCase().contains(s);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No quizzes found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Title')),
          DataColumn(label: Text('Lesson ID')),
          DataColumn(label: Text('Time Limit')),
          DataColumn(label: Text('Passing Score')),
          DataColumn(label: Text('Published')),
          DataColumn(label: Text('Actions')),
        ],
        rows: filtered.map((quiz) {
          return DataRow(
            cells: [
              DataCell(Text(quiz.title)),
              DataCell(Text(quiz.lessonId, overflow: TextOverflow.ellipsis)),
              DataCell(Text('${quiz.timeLimitMinutes} min')),
              DataCell(Text('${quiz.passingScore}%')),
              DataCell(
                Switch(
                  value: quiz.isPublished,
                  onChanged: (val) => vm.toggleQuizPublish(quiz.id, val),
                ),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () =>
                      _confirmDeleteQuiz(context, vm, quiz.id, quiz.title),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _confirmDeleteQuiz(
    BuildContext context,
    ContentManagementViewModel vm,
    String id,
    String title,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              vm.deleteQuiz(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
