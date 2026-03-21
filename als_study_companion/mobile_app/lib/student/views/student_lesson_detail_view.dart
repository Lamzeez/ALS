import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../repositories/quiz_repository.dart';
import '../viewmodels/quiz_viewmodel.dart';
import 'student_quiz_view.dart';

/// Detailed view for a single lesson.
class StudentLessonDetailView extends StatefulWidget {
  final LessonModel lesson;

  const StudentLessonDetailView({super.key, required this.lesson});

  @override
  State<StudentLessonDetailView> createState() => _StudentLessonDetailViewState();
}

class _StudentLessonDetailViewState extends State<StudentLessonDetailView> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  QuizModel? _lessonQuiz;
  bool _isLoadingQuiz = true;

  @override
  void initState() {
    super.initState();
    if (widget.lesson.videoUrl != null && widget.lesson.videoUrl!.isNotEmpty) {
      _initVideo();
    }
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final repo = QuizRepository();
    final quizzes = await repo.getQuizzesByLesson(widget.lesson.id);
    if (mounted) {
      setState(() {
        if (quizzes.isNotEmpty) {
          _lessonQuiz = quizzes.first;
        }
        _isLoadingQuiz = false;
      });
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link')),
        );
      }
    }
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.lesson.videoUrl!),
    );
    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() => _isVideoInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.lesson.subject)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Player Section
            if (widget.lesson.videoUrl != null && widget.lesson.videoUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: _isVideoInitialized
                      ? Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(_videoController!),
                            _VideoControls(controller: _videoController!),
                            VideoProgressIndicator(
                              _videoController!,
                              allowScrubbing: true,
                            ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.book, size: 64, color: Colors.white),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lesson.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(label: Text(widget.lesson.subject)),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.lesson.durationMinutes} minutes',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.lesson.description,
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (widget.lesson.studyGuideUrl != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _launchURL(widget.lesson.studyGuideUrl!),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Download Study Guide'),
                      ),
                    ),
                  const SizedBox(height: 32),
                  if (_isLoadingQuiz)
                    const Center(child: CircularProgressIndicator())
                  else if (_lessonQuiz != null)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () {
                          context.read<QuizViewModel>().loadQuiz(_lessonQuiz!.id);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentQuizView(
                                quizId: _lessonQuiz!.id,
                                lessonId: widget.lesson.id,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.quiz),
                        label: const Text('Take Quiz'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const _VideoControls({required this.controller});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 50),
      reverseDuration: const Duration(milliseconds: 200),
      child: widget.controller.value.isPlaying
          ? const SizedBox.shrink()
          : Container(
              color: Colors.black26,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.white, size: 50),
                  onPressed: () {
                    widget.controller.play();
                    setState(() {});
                  },
                ),
              ),
            ),
    );
  }
}
