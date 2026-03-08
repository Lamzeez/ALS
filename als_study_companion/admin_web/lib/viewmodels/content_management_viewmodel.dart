import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ViewModel for managing educational content (lessons, quizzes).
class ContentManagementViewModel extends ChangeNotifier {
  List<LessonModel> _lessons = [];
  List<QuizModel> _quizzes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<LessonModel> get lessons => _lessons;
  List<QuizModel> get quizzes => _quizzes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalLessons => _lessons.length;
  int get publishedLessons => _lessons.where((l) => l.isPublished).length;

  Future<void> loadContent() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final lessonsRes = await Supabase.instance.client
          .from('lessons')
          .select();
      final lessons = List<Map<String, dynamic>>.from(lessonsRes as List);
      _lessons = lessons.map((m) => LessonModel.fromMap(m)).toList();

      final quizzesRes = await Supabase.instance.client
          .from('quizzes')
          .select();
      final quizzes = List<Map<String, dynamic>>.from(quizzesRes as List);
      _quizzes = quizzes.map((m) => QuizModel.fromMap(m)).toList();
    } catch (e) {
      _errorMessage = 'Failed to load content: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> deleteLesson(String id) async {
    try {
      await Supabase.instance.client.from('lessons').delete().eq('id', id);
      _lessons.removeWhere((l) => l.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> togglePublish(String lessonId, bool publish) async {
    try {
      await Supabase.instance.client
          .from('lessons')
          .update({'is_published': publish})
          .eq('id', lessonId);
      final index = _lessons.indexWhere((l) => l.id == lessonId);
      if (index >= 0) {
        _lessons[index] = _lessons[index].copyWith(isPublished: publish);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteQuiz(String id) async {
    try {
      await Supabase.instance.client.from('quizzes').delete().eq('id', id);
      _quizzes.removeWhere((q) => q.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleQuizPublish(String quizId, bool publish) async {
    try {
      await Supabase.instance.client
          .from('quizzes')
          .update({'is_published': publish})
          .eq('id', quizId);
      final index = _quizzes.indexWhere((q) => q.id == quizId);
      if (index >= 0) {
        _quizzes[index] = _quizzes[index].copyWith(isPublished: publish);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
