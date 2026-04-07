import 'package:flutter/material.dart';
import 'package:shared_services/shared_services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'quiz_screen.dart';

class LessonViewerScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final String moduleId;
  final String courseId;
  final int moduleLessonsCount;

  const LessonViewerScreen({
    super.key,
    required this.lesson,
    required this.moduleId,
    required this.courseId,
    required this.moduleLessonsCount,
  });

  @override
  State<LessonViewerScreen> createState() => _LessonViewerScreenState();
}

class _LessonViewerScreenState extends State<LessonViewerScreen> {
  final _courseService = CourseService();
  List<Map<String, dynamic>> _media = [];
  Map<String, dynamic>? _quiz;
  bool _isLoadingMedia = true;
  bool _isLoadingQuiz = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
    _loadQuiz();
  }

  Future<void> _loadMedia() async {
    try {
      _media = await _courseService.getLessonMedia(
        widget.lesson['id'] as String,
      );
    } catch (e) {
      debugPrint('Error loading media: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMedia = false);
    }
  }

  Future<void> _loadQuiz() async {
    try {
      _quiz = await _courseService.getQuizForLesson(
        widget.lesson['id'] as String,
      );
    } catch (e) {
      debugPrint('Error loading quiz: $e');
    } finally {
      if (mounted) setState(() => _isLoadingQuiz = false);
    }
  }

  String _getContentText() {
    final contentJson = widget.lesson['content_json'];
    if (contentJson == null) return '';
    if (contentJson is Map) {
      return contentJson['text']?.toString() ?? '';
    }
    return contentJson.toString();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.lesson['title'] as String? ?? 'Lesson';
    final contentType = widget.lesson['content_type'] as String? ?? 'text';
    final contentText = _getContentText();
    final durationMins = (widget.lesson['duration_minutes'] as num?)?.toInt();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (durationMins != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        '${durationMins}m',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Content type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AlsColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getContentIcon(contentType),
                  size: 16,
                  color: AlsColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  contentType.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: AlsColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),

          // Content text
          if (contentText.isNotEmpty)
            Text(
              contentText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
            ),

          // Media attachments
          if (_isLoadingMedia)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_media.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Attachments',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ..._media.map((m) => _buildMediaCard(m)),
          ],

          // Quiz button
          if (!_isLoadingQuiz && _quiz != null) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _buildQuizCard(),
          ],

          const SizedBox(height: 40),
        ],
      ),
      floatingActionButton: (!_isLoadingQuiz && _quiz != null)
          ? FloatingActionButton.extended(
              onPressed: _openQuiz,
              icon: const Icon(Icons.quiz),
              label: const Text('Take Quiz'),
              backgroundColor: AlsColors.accent,
              foregroundColor: AlsColors.textPrimary,
            )
          : null,
    );
  }

  Widget _buildMediaCard(Map<String, dynamic> media) {
    final fileName = media['file_name'] as String? ?? 'File';
    final fileType = media['file_type'] as String? ?? 'document';
    final storageUrl = media['storage_url'] as String? ?? '';
    final fileSizeBytes = (media['file_size_bytes'] as num?)?.toInt();

    IconData icon;
    switch (fileType) {
      case 'video':
        icon = Icons.play_circle_filled;
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf;
        break;
      case 'image':
        icon = Icons.image;
        break;
      case 'audio':
        icon = Icons.audiotrack;
        break;
      default:
        icon = Icons.insert_drive_file;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AlsColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AlsColors.primary),
        ),
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          fileSizeBytes != null
              ? '${(fileSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB'
              : fileType,
          style: TextStyle(fontSize: 12, color: AlsColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: () => _openUrl(storageUrl),
        ),
      ),
    );
  }

  Widget _buildQuizCard() {
    final quizTitle = _quiz!['title'] as String? ?? 'Quiz';
    final timeLimit = (_quiz!['time_limit_mins'] as num?)?.toInt();
    final maxAttempts = (_quiz!['max_attempts'] as num?)?.toInt() ?? 3;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AlsColors.primarySurface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz, color: AlsColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    quizTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (timeLimit != null) ...[
                  Icon(Icons.timer, size: 14, color: AlsColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '$timeLimit min',
                    style: TextStyle(
                      fontSize: 12,
                      color: AlsColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Icon(Icons.repeat, size: 14, color: AlsColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '$maxAttempts attempts',
                  style: TextStyle(
                    fontSize: 12,
                    color: AlsColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openQuiz,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Quiz'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openQuiz() {
    if (_quiz == null) return;
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          quiz: _quiz!,
          moduleId: widget.moduleId,
          courseId: widget.courseId,
          moduleLessonsCount: widget.moduleLessonsCount,
        ),
      ),
    ).then((passed) {
      if (passed == true) {
        Navigator.pop(context, true); // signal refresh to course detail
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _getContentIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_outline;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'interactive':
        return Icons.touch_app;
      case 'mixed':
        return Icons.layers;
      default:
        return Icons.article;
    }
  }
}
