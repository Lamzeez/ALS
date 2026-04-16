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

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoLoading = false;

  List<LessonMedia> _media = [];
  Quiz? _quiz;
  bool _isLoadingMedia = true;
  bool _isLoadingQuiz = true;
  bool _isOnline = true;
  
  double _progressPercent = 0.0;
  int _timeSpentSeconds = 0;
  int _lastSavedSecond = -1; // Throttling helper

  @override
  void initState() {
    super.initState();
    _initializeLesson();
  }

  Future<void> _initializeLesson() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    _isOnline = result.isNotEmpty && !result.contains(ConnectivityResult.none);

    await Future.wait([
      _loadMedia(),
      _loadQuiz(),
      _loadProgress(),
    ]);

    if (widget.lesson.contentType == LessonContentType.video && _media.isNotEmpty) {
      final videoMedia = _media.firstWhere(
        (m) => m.fileType == MediaFileType.video,
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
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        placeholder: const Center(child: CircularProgressIndicator()),
      );

      _videoPlayerController!.addListener(_onVideoProgressUpdate);
    } catch (e) {
      debugPrint('Error initializing video: $e');
    } finally {
      if (mounted) setState(() => _isVideoLoading = false);
    }
  }

  void _onVideoProgressUpdate() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;

    final position = _videoPlayerController!.value.position;
    final duration = _videoPlayerController!.value.duration;

    if (duration.inSeconds > 0) {
      final progress = (position.inSeconds / duration.inSeconds) * 100;
      if (progress > _progressPercent) {
        setState(() {
          _progressPercent = progress;
          _timeSpentSeconds = position.inSeconds;
        });

        // 🛡️ Throttled Sync: Only every 30 seconds
        final currentSec = position.inSeconds;
        if (currentSec % 30 == 0 && currentSec != _lastSavedSecond) {
          _lastSavedSecond = currentSec;
          _saveProgress();
        }
      }
    }
  }

  Future<void> _saveProgress() async {
    final studentId = AuthService().currentUser?.id;
    if (studentId == null) return;

    final isCompleted = _progressPercent >= 90;

    try {
      // Log progress to the sync service
      await _offlineSync.trackModuleProgress(
        studentId: studentId,
        moduleId: widget.moduleId,
        courseId: widget.courseId,
        status: isCompleted ? 'completed' : 'in_progress',
      );
    } catch (e) {
      debugPrint('Error saving sync progress: $e');
    }
  }

  Future<void> _loadMedia() async {
    try {
      _media = await _courseService.getLessonMedia(widget.lesson.id);
    } finally {
      if (mounted) setState(() => _isLoadingMedia = false);
    }
  }

  Future<void> _loadQuiz() async {
    try {
      _quiz = await _courseService.getQuizForLesson(widget.lesson.id);
    } finally {
      if (mounted) setState(() => _isLoadingQuiz = false);
    }
  }

  Future<void> _loadProgress() async {
    final studentId = AuthService().currentUser?.id;
    if (studentId == null) return;
    try {
      final progress = await _progressRepo.getLessonProgress(studentId, widget.lesson.id);
      if (progress != null) {
        setState(() {
          _progressPercent = (progress['progress_percent'] as num?)?.toDouble() ?? 0.0;
          _timeSpentSeconds = ((progress['time_spent_minutes'] as num?)?.toInt() ?? 0) * 60;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
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
          Icon(_isOnline ? Icons.wifi : Icons.wifi_off, 
               color: _isOnline ? AlsColors.online : AlsColors.offline, size: 20),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
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
                if (widget.lesson.contentType == LessonContentType.video) _buildVideoPlayer(),
                if (widget.lesson.contentType == LessonContentType.pdf && _media.isNotEmpty) _buildPdfViewer(),
                
                // --- RICH CONTENT RENDERER ---
                if (widget.lesson.contentJson != null) _buildRichContent(),

                if (_isLoadingMedia) 
                  const Center(child: CircularProgressIndicator())
                else if (_media.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildMediaSection(),
                ],

                if (!_isLoadingQuiz && _quiz != null) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  _buildQuizCard(),
                ],
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

  Widget _buildRichContent() {
    final json = widget.lesson.contentJson!;
    final text = json['text'] as String? ?? '';
    final body = json['body'] as String? ?? ''; // Support for alternate key

    if (text.isEmpty && body.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.lesson.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Text(text.isNotEmpty ? text : body, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    if (_isVideoLoading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    if (_chewieController == null) return const SizedBox.shrink();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPdfViewer() {
    final pdfMedia = _media.firstWhere((m) => m.fileType == MediaFileType.pdf, orElse: () => _media.first);
    if (pdfMedia.storageUrl == null) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 500,
          child: SfPdfViewer.network(pdfMedia.storageUrl!),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attachments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ..._media.map((m) => _buildMediaCard(m)),
      ],
    );
  }

  Widget _buildMediaCard(LessonMedia media) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file, color: AlsColors.primary),
        title: Text(media.fileName ?? 'File'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openUrl(media.storageUrl ?? ''),
      ),
    );
  }

  Widget _buildQuizCard() {
    return Card(
      color: AlsColors.primarySurface,
      child: ListTile(
        leading: const Icon(Icons.quiz, color: AlsColors.primary),
        title: Text(_quiz!.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${_quiz!.maxAttempts} attempts allowed'),
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
      if (passed == true) Navigator.pop(context, true);
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
