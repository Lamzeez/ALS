import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import '../repositories/teacher_lesson_repository.dart';

/// ViewModel for teacher lesson management (upload, edit, publish).
class TeacherLessonViewModel extends ChangeNotifier {
  final TeacherLessonRepository _repository = TeacherLessonRepository();

  List<LessonModel> _lessons = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<LessonModel> get lessons => _lessons;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadLessons(String teacherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Try remote first, fallback to local
      final remote = await _repository.fetchRemoteLessons(teacherId);
      _lessons = remote.isNotEmpty
          ? remote
          : await _repository.getLessonsByTeacher(teacherId);
    } catch (e) {
      try {
        _lessons = await _repository.getLessonsByTeacher(teacherId);
      } catch (_) {
        _errorMessage = 'Failed to load lessons: ${e.toString()}';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createLesson(LessonModel lesson) async {
    try {
      await _repository.createLesson(lesson);
      _repository.pushLesson(lesson); // push to remote (fire-and-forget)
      _lessons.insert(0, lesson);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create lesson: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateLesson(LessonModel lesson) async {
    try {
      await _repository.updateLesson(lesson);
      _repository.pushLesson(lesson); // push to remote (fire-and-forget)
      final index = _lessons.indexWhere((l) => l.id == lesson.id);
      if (index >= 0) {
        _lessons[index] = lesson;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update lesson: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> publishLesson(String lessonId) async {
    try {
      await _repository.publishLesson(lessonId);
      final index = _lessons.indexWhere((l) => l.id == lessonId);
      if (index >= 0) {
        _lessons[index] = _lessons[index].copyWith(isPublished: true);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to publish lesson: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteLesson(String lessonId) async {
    try {
      await _repository.deleteLesson(lessonId);
      _lessons.removeWhere((l) => l.id == lessonId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete lesson: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
