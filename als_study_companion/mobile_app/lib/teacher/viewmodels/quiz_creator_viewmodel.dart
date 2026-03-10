import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import '../repositories/quiz_creator_repository.dart';

/// ViewModel for creating and managing quizzes.
class QuizCreatorViewModel extends ChangeNotifier {
  final QuizCreatorRepository _repository = QuizCreatorRepository();

  List<QuizModel> _quizzes = [];
  List<QuestionModel> _questions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<QuizModel> get quizzes => _quizzes;
  List<QuestionModel> get questions => _questions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadQuizzes(String teacherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Try remote first, fallback to local
      final remote = await _repository.fetchRemoteQuizzes(teacherId);
      _quizzes = remote.isNotEmpty
          ? remote
          : await _repository.getQuizzesByTeacher(teacherId);
    } catch (e) {
      try {
        _quizzes = await _repository.getQuizzesByTeacher(teacherId);
      } catch (_) {
        _errorMessage = 'Failed to load quizzes: ${e.toString()}';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadQuestions(String quizId) async {
    try {
      _questions = await _repository.getQuestionsByQuiz(quizId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load questions: ${e.toString()}';
      notifyListeners();
    }
  }

  Future<bool> createQuiz(QuizModel quiz) async {
    try {
      await _repository.createQuiz(quiz);
      _repository.pushQuiz(quiz); // push to remote (fire-and-forget)
      _quizzes.insert(0, quiz);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create quiz: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addQuestion(QuestionModel question) async {
    try {
      await _repository.addQuestion(question);
      _repository.pushQuestion(question); // push to remote (fire-and-forget)
      _questions.add(question);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add question: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteQuiz(String quizId) async {
    try {
      await _repository.deleteQuiz(quizId);
      _quizzes.removeWhere((q) => q.id == quizId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete quiz: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
