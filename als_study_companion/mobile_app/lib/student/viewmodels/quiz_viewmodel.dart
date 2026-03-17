import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import '../repositories/quiz_repository.dart';

/// ViewModel for student quiz taking.
class QuizViewModel extends ChangeNotifier {
  final QuizRepository _repository = QuizRepository();

  QuizModel? _currentQuiz;
  List<QuestionModel> _questions = [];
  int _currentQuestionIndex = 0;
  Map<int, int> _selectedAnswers = {};
  bool _isLoading = false;
  bool _isSubmitted = false;
  int _score = 0;
  String? _errorMessage;

  QuizModel? get currentQuiz => _currentQuiz;
  List<QuestionModel> get questions => _questions;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<int, int> get selectedAnswers => _selectedAnswers;
  bool get isLoading => _isLoading;
  bool get isSubmitted => _isSubmitted;
  int get score => _score;
  String? get errorMessage => _errorMessage;
  QuestionModel? get currentQuestion =>
      _questions.isNotEmpty && _currentQuestionIndex < _questions.length
      ? _questions[_currentQuestionIndex]
      : null;
  bool get isLastQuestion => _currentQuestionIndex == _questions.length - 1;
  int get answeredCount => _selectedAnswers.length;

  /// Load a quiz and its questions.
  Future<void> loadQuiz(String quizId) async {
    _isLoading = true;
    _errorMessage = null;
    _isSubmitted = false;
    _selectedAnswers = {};
    _currentQuestionIndex = 0;
    _score = 0;
    notifyListeners();

    try {
      _currentQuiz = await _repository.getQuizById(quizId);
      if (_currentQuiz != null) {
        _questions = await _repository.getQuestionsByQuiz(quizId);
      }
    } catch (e) {
      _errorMessage = 'Failed to load quiz: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Select an answer for the current question.
  void selectAnswer(int questionIndex, int optionIndex) {
    _selectedAnswers[questionIndex] = optionIndex;
    notifyListeners();
  }

  /// Move to the next question.
  void nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  /// Move to the previous question.
  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  /// Submit the quiz and calculate score.
  Future<void> submitQuiz({String? studentId, String? lessonId}) async {
    _score = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctOptionIndex) {
        _score++;
      }
    }
    _isSubmitted = true;
    notifyListeners();
  }

  /// Get score as percentage.
  double get scorePercent =>
      _questions.isNotEmpty ? (_score / _questions.length) * 100 : 0;

  /// Check if the student passed.
  bool get passed =>
      _currentQuiz != null && scorePercent >= _currentQuiz!.passingScore;

  void resetQuiz() {
    _currentQuiz = null;
    _questions = [];
    _currentQuestionIndex = 0;
    _selectedAnswers = {};
    _isSubmitted = false;
    _score = 0;
    notifyListeners();
  }
}
