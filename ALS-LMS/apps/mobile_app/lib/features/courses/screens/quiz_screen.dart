import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:backend_services/backend_services.dart';
import 'package:shared_ui/shared_ui.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;
  final String moduleId;
  final String courseId;
  final int moduleLessonsCount;

  const QuizScreen({
    super.key,
    required this.quiz,
    required this.moduleId,
    required this.courseId,
    required this.moduleLessonsCount,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _courseService = CourseService();

  List<QuizQuestion> _questions = [];
  Map<int, String> _answers = {}; // questionIndex → selected answer
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isCompleted = false;
  int _currentQuestionIndex = 0;
  double _score = 0;
  double _maxScore = 0;
  double _percentage = 0;
  bool _isPassing = false;

  // Timer
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _hasTimeLimit = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      _questions = await _courseService.getQuizQuestions(
        widget.quiz.id,
      );

      final timeLimitMins = widget.quiz.timeLimitMins;
      if (timeLimitMins != null && timeLimitMins > 0) {
        _hasTimeLimit = true;
        _remainingSeconds = timeLimitMins * 60;
        _startTimer();
      }
    } catch (e) {
      debugPrint('Error loading questions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _submitQuiz();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(int questionIndex, String answer) {
    setState(() => _answers[questionIndex] = answer);
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    _timer?.cancel();

    try {
      // Grade the quiz
      _maxScore = 0;
      _score = 0;
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final questionJson = q.questionJson;
        final points = q.points;
        _maxScore += points;

        final correctAnswer = questionJson['correct_answer']?.toString() ?? '';
        final userAnswer = _answers[i] ?? '';
        if (userAnswer.isNotEmpty &&
            userAnswer.toLowerCase() == correctAnswer.toLowerCase()) {
          _score += points;
        }
      }

      _percentage = _maxScore > 0 ? (_score / _maxScore) * 100 : 0;
      final passingScore = widget.quiz.passingScore;
      _isPassing = _percentage >= passingScore;

      // Build answers map
      final answersMap = <String, dynamic>{};
      for (int i = 0; i < _questions.length; i++) {
        answersMap['q_${_questions[i].id}'] = _answers[i] ?? '';
      }

      // Get attempt number
      final previousScores = await _courseService.getScoresForQuiz(
        widget.quiz.id,
      );
      final attemptNum = previousScores.length + 1;

      // Calculate time taken
      final timeLimitMins = widget.quiz.timeLimitMins ?? 0;
      final totalTimeSecs =
          timeLimitMins > 0 ? (timeLimitMins * 60) - _remainingSeconds : 0;

      // Submit score
      await _courseService.submitQuizScore(
        quizId: widget.quiz.id,
        score: _score,
        maxScore: _maxScore,
        attemptNum: attemptNum,
        answers: answersMap,
        timeTakenSecs: totalTimeSecs,
      );

      // Update module progress if passing
      if (_isPassing) {
        await _courseService.upsertModuleProgress(
          moduleId: widget.moduleId,
          courseId: widget.courseId,
          status: 'completed',
          masteryScore: _percentage,
          lessonsViewed: widget.moduleLessonsCount,
          totalLessons: widget.moduleLessonsCount,
        );
      }

      setState(() => _isCompleted = true);
    } catch (e) {
      debugPrint('Error submitting quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting: $e'),
            backgroundColor: AlsColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isCompleted) return _buildResultScreen();

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz, size: 64, color: AlsColors.textHint),
              const SizedBox(height: 16),
              Text('No questions found',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      );
    }

    return _buildQuizUI();
  }

  Widget _buildQuizUI() {
    final question = _questions[_currentQuestionIndex];
    final questionJson = question.questionJson;
    final questionText = questionJson['text'] as String? ?? '';
    final options = (questionJson['options'] as List<dynamic>?)
            ?.map((o) => o.toString())
            .toList() ??
        [];
    final selectedAnswer = _answers[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        actions: [
          if (_hasTimeLimit)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _remainingSeconds < 60 ? Colors.red : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer,
                        size: 16,
                        color: _remainingSeconds < 60
                            ? Colors.white
                            : Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          color: _remainingSeconds < 60
                              ? Colors.white
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            backgroundColor: AlsColors.divider,
            color: AlsColors.primary,
            minHeight: 4,
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Question number
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                  style: TextStyle(
                    color: AlsColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),

                // Question text
                Text(
                  questionText,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 24),

                // Options
                ...options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isSelected = selectedAnswer == option;
                  final letter = String.fromCharCode(65 + index); // A, B, C...

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _selectAnswer(_currentQuestionIndex, option),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AlsColors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AlsColors.primary
                                : AlsColors.divider,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AlsColors.primary
                                    : AlsColors.divider,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AlsColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentQuestionIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _currentQuestionIndex--);
                      },
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentQuestionIndex > 0) const SizedBox(width: 12),
                Expanded(
                  child: _currentQuestionIndex == _questions.length - 1
                      ? ElevatedButton(
                          onPressed:
                              _isSubmitting ? null : () => _confirmSubmit(),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Submit'),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            setState(() => _currentQuestionIndex++);
                          },
                          child: const Text('Next'),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSubmit() {
    final unanswered = _questions.length - _answers.length;
    if (unanswered > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submit Quiz?'),
          content: Text(
            'You have $unanswered unanswered question${unanswered == 1 ? '' : 's'}. '
            'Are you sure you want to submit?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Review'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _submitQuiz();
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      );
    } else {
      _submitQuiz();
    }
  }

  Widget _buildResultScreen() {
    final passingScore = widget.quiz.passingScore;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _isPassing
                      ? AlsColors.success.withValues(alpha: 0.1)
                      : AlsColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPassing ? Icons.check_circle : Icons.cancel,
                  size: 56,
                  color: _isPassing ? AlsColors.success : AlsColors.error,
                ),
              ),
              const SizedBox(height: 24),

              // Status text
              Text(
                _isPassing ? 'Congratulations!' : 'Keep Trying!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _isPassing ? AlsColors.success : AlsColors.error,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _isPassing
                    ? 'You passed the quiz!'
                    : 'You need ${passingScore.toInt()}% to pass.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),

              // Score card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AlsColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_percentage.toInt()}%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: _isPassing ? AlsColors.success : AlsColors.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_score.toInt()} / ${_maxScore.toInt()} points',
                      style: TextStyle(
                        fontSize: 16,
                        color: AlsColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_answers.length} of ${_questions.length} answered',
                      style: TextStyle(
                        fontSize: 13,
                        color: AlsColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _isPassing);
                  },
                  child: Text(_isPassing ? 'Continue' : 'Back to Lesson'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

