import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_services/shared_services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'quiz_screen.dart';

/// Enhanced Lesson Viewer with video playback, PDF viewing, and progress tracking.
/// Supports both online streaming and offline playback for downloaded content.
class LessonViewerScreen extends StatefulWidget {
  final Lesson lesson;
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
  final _offlineSync = OfflineSyncService.instance;
  final _progressRepo = ProgressRepository();

  // Video player controllers
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoLoading = false;

  // Lesson data
  List<LessonMedia> _media = [];
  Quiz? _quiz;
  bool _isLoadingMedia = true;
  bool _isLoadingQuiz = true;
  bool _isOnline = true;
  bool _isLessonDownloaded = false;

  // Progress tracking
  double _progressPercent = 0.0;
  int _timeSpentSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeLesson();
  }

  Future<void> _initializeLesson() async {
    // Check connectivity
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    _isOnline = result.isNotEmpty && !result.contains(ConnectivityResult.none);

    // Load lesson data
    await Future.wait([
      _loadMedia(),
      _loadQuiz(),
      _loadProgress(),
    ]);

    // Initialize video if lesson has video content
    if (widget.lesson.contentType == LessonContentType.video &&
        _media.isNotEmpty) {
      final videoMedia = _media.firstWhere(
        (m) => m.fileType == 'video',
        orElse: () => _media.first,
      );
      if (videoMedia.storageUrl != null && videoMedia.storageUrl!.isNotEmpty) {
        await _initializeVideoPlayer(videoMedia.storageUrl!);
      }
    }
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    setState(() => _isVideoLoading = true);

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error loading video: $errorMessage',
              style: const TextStyle(color: Colors.red),
            ),
          );
        },
      );

      // Track video progress
      _videoPlayerController!.addListener(_onVideoProgressUpdate);
    } catch (e) {
      debugPrint('Error initializing video: $e');
    } finally {
      if (mounted) setState(() => _isVideoLoading = false);
    }
  }

  void _onVideoProgressUpdate() {
    if (_videoPlayerController == null ||
        !_videoPlayerController!.value.isInitialized) return;

    final position = _videoPlayerController!.value.position;
    final duration = _videoPlayerController!.value.duration;

    if (duration.inSeconds > 0) {
      final progress = (position.inSeconds / duration.inSeconds) * 100;

      if (progress > _progressPercent) {
        setState(() {
          _progressPercent = progress;
          _timeSpentSeconds = position.inSeconds;
        });

        // Save progress periodically
        if (position.inSeconds % 30 == 0) {
          _saveProgress();
        }
      }
    }
  }

  Future<void> _saveProgress() async {
    final studentId = SupabaseConfig.client.auth.currentUser?.id;
    if (studentId == null) return;

    final isCompleted = _progressPercent >= 90;

    try {
      await _offlineSync.trackProgress(
        studentId: studentId,
        lessonId: widget.lesson.id,
        progressPercent: _progressPercent,
        timeSpentMinutes: (_timeSpentSeconds / 60).round(),
        isCompleted: isCompleted,
      );

      // Also save to local storage for offline access
      await _progressRepo.upsertProgress({
        'id': '${studentId}_${widget.lesson.id}',
        'student_id': studentId,
        'lesson_id': widget.lesson.id,
        'progress_percent': _progressPercent,
        'time_spent_minutes': (_timeSpentSeconds / 60).round(),
        'is_completed': isCompleted ? 1 : 0,
        'last_accessed_at': DateTime.now().toIso8601String(),
        if (isCompleted) 'completed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  Future<void> _loadMedia() async {
    try {
      if (_isOnline) {
        _media = await _courseService.getLessonMedia(widget.lesson.id);
      }
    } catch (e) {
      debugPrint('Error loading media: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMedia = false);
    }
  }

  Future<void> _loadQuiz() async {
    try {
      if (_isOnline) {
        _quiz = await _courseService.getQuizForLesson(widget.lesson.id);
      }
    } catch (e) {
      debugPrint('Error loading quiz: $e');
    } finally {
      if (mounted) setState(() => _isLoadingQuiz = false);
    }
  }

  Future<void> _loadProgress() async {
    final studentId = SupabaseConfig.client.auth.currentUser?.id;
    if (studentId == null) return;

    try {
      final progress = await _progressRepo.getLessonProgress(
        studentId,
        widget.lesson.id,
      );

      if (progress != null) {
        setState(() {
          _progressPercent = (progress['progress_percent'] as num?)?.toDouble() ?? 0.0;
          _timeSpentSeconds =
              ((progress['time_spent_minutes'] as num?)?.toInt() ?? 0) * 60;
        });
      }
    } catch (e) {
      debugPrint('Error loading progress: $e');
    }
  }

  @override
  void dispose() {
    // Save final progress
    _saveProgress();

    _videoPlayerController?.removeListener(_onVideoProgressUpdate);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title),
        actions: [
          // Offline indicator
          Icon(
            _isOnline ? Icons.wifi : Icons.wifi_off,
            color: _isOnline ? AlsColors.online : AlsColors.offline,
            size: 20,
          ),
          const SizedBox(width: 8),

          // Duration badge
          if (widget.lesson.durationMinutes != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    '${widget.lesson.durationMinutes}m',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          if (_progressPercent > 0)
            LinearProgressIndicator(
              value: _progressPercent / 100,
              backgroundColor: AlsColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(AlsColors.accent),
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Video Player (if video lesson)
                if (widget.lesson.contentType == LessonContentType.video)
                  _buildVideoPlayer(),

                // PDF Viewer (if PDF lesson)
                if (widget.lesson.contentType == LessonContentType.pdf &&
                    _media.isNotEmpty)
                  _buildPdfViewer(),

                // Text content
                if (widget.lesson.contentJson != null &&
                    widget.lesson.contentJson!['text'] != null)
                  _buildTextContent(),

                // Media attachments
                if (_isLoadingMedia)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_media.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildMediaSection(),
                ],

                // Quiz section
                if (!_isLoadingQuiz && _quiz != null) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildQuizCard(),
                ],

                // Download button for offline access (future enhancement)
                // if (!_isLessonDownloaded && _isOnline) ...[
                //   const SizedBox(height: 24),
                //   _buildDownloadButton(),
                // ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _quiz != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _openQuiz,
                  icon: const Icon(Icons.quiz),
                  label: const Text('Take Quiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AlsColors.accent,
                    foregroundColor: AlsColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildVideoPlayer() {
    final videoMedia = _media.isNotEmpty
        ? _media.firstWhere(
            (m) => m.fileType == 'video',
            orElse: () => _media.first,
          )
        : null;

    final videoUrl = videoMedia?.storageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isVideoLoading)
          Container(
            height: 200,
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          )
        else if (_chewieController != null)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Chewie(controller: _chewieController!),
            ),
          )
        else if (videoUrl != null && videoUrl.isNotEmpty)
          Container(
            height: 200,
            color: Colors.black,
            child: const Center(
              child: Text(
                'Tap play to load video',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          Container(
            height: 200,
            color: Colors.black12,
            child: const Center(
              child: Text(
                'Video not available',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          widget.lesson.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AlsColors.primarySurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle, size: 14, color: AlsColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'VIDEO',
                    style: TextStyle(
                      color: AlsColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_progressPercent > 0)
              Text(
                '${_progressPercent.toStringAsFixed(0)}% complete',
                style: TextStyle(
                  color: AlsColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPdfViewer() {
    final pdfMedia = _media.firstWhere(
      (m) => m.fileType == 'pdf',
      orElse: () => _media.first,
    );

    final pdfUrl = pdfMedia.storageUrl;

    if (pdfUrl == null || pdfUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 500,
          decoration: BoxDecoration(
            border: Border.all(color: AlsColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SfPdfViewer.network(
            pdfUrl,
            enableTextSelection: true,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'PDF',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_progressPercent > 0)
              Text(
                '${_progressPercent.toStringAsFixed(0)}% complete',
                style: TextStyle(
                  color: AlsColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTextContent() {
    final textContent = widget.lesson.contentJson!['text'] as String?;
    if (textContent == null || textContent.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.lesson.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          textContent,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
              ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attachments',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        ..._media.map((m) => _buildMediaCard(m)),
      ],
    );
  }

  Widget _buildMediaCard(LessonMedia media) {
    final fileName = media.fileName ?? 'Unknown file';
    final fileType = media.fileType ?? 'document';
    final storageUrl = media.storageUrl ?? '';
    final fileSizeBytes = media.fileSizeBytes;

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
              : fileType.toString(),
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
    final quizTitle = _quiz!.title;
    final timeLimit = _quiz!.timeLimitMins;
    final maxAttempts = _quiz!.maxAttempts;

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
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _downloadLesson,
        icon: const Icon(Icons.download),
        label: const Text('Download for Offline Access'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _downloadLesson() async {
    final studentId = SupabaseConfig.client.auth.currentUser?.id;
    if (studentId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _offlineSync.downloadCourseData(
        courseId: widget.courseId,
        studentId: studentId,
      );

      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        setState(() => _isLessonDownloaded = true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lesson downloaded successfully!'),
            backgroundColor: AlsColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AlsColors.error,
          ),
        );
      }
    }
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
        Navigator.pop(context, true);
      }
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
