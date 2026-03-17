import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import '../repositories/lesson_repository.dart';

/// ViewModel for student lesson browsing and viewing.
class LessonViewModel extends ChangeNotifier {
  final LessonRepository _repository = LessonRepository();

  List<LessonModel> _lessons = [];
  LessonModel? _selectedLesson;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedSubject = '';

  List<LessonModel> get lessons => _lessons;
  LessonModel? get selectedLesson => _selectedLesson;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedSubject => _selectedSubject;

  /// Load all available lessons (try remote first, fallback to local).
  Future<void> loadLessons() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Try fetching from Supabase first (caches to local SQLite)
      final remote = await _repository.fetchRemoteLessons();
      if (remote.isNotEmpty) {
        _lessons = remote;
      } else {
        _lessons = await _repository.getLocalLessons();
      }
    } catch (e) {
      // Fallback to local on any error
      try {
        _lessons = await _repository.getLocalLessons();
      } catch (_) {
        _errorMessage = 'Failed to load lessons: ${e.toString()}';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load lessons filtered by subject.
  Future<void> loadLessonsBySubject(String subject) async {
    _isLoading = true;
    _selectedSubject = subject;
    notifyListeners();

    try {
      _lessons = await _repository.getLessonsBySubject(subject);
    } catch (e) {
      _errorMessage = 'Failed to load lessons: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Select a specific lesson for detailed view.
  Future<void> selectLesson(String lessonId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedLesson = await _repository.getLessonById(lessonId);
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearSelection() {
    _selectedLesson = null;
    notifyListeners();
  }
}
