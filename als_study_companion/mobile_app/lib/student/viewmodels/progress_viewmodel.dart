import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import '../repositories/progress_repository.dart';

/// ViewModel for tracking student learning progress.
class ProgressViewModel extends ChangeNotifier {
  final ProgressRepository _repository = ProgressRepository();

  List<ProgressModel> _progressList = [];
  double _overallProgress = 0.0;
  bool _isLoading = false;
  String? _errorMessage;

  List<ProgressModel> get progressList => _progressList;
  double get overallProgress => _overallProgress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load all progress for a student.
  Future<void> loadProgress(String studentId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Try remote first for latest data
      final remote = await _repository.fetchRemoteProgress(studentId);
      if (remote.isNotEmpty) {
        _progressList = remote;
      } else {
        _progressList = await _repository.getProgressByStudent(studentId);
      }
      _overallProgress = await _repository.getOverallProgress(studentId);
    } catch (e) {
      // Fallback to local on any error
      try {
        _progressList = await _repository.getProgressByStudent(studentId);
        _overallProgress = await _repository.getOverallProgress(studentId);
      } catch (_) {
        _errorMessage = 'Failed to load progress: ${e.toString()}';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Update progress for a specific lesson.
  Future<void> updateLessonProgress({
    required String studentId,
    required String lessonId,
    required double progressPercent,
    int? quizScore,
    int timeSpentMinutes = 0,
  }) async {
    try {
      var existing = await _repository.getProgressForLesson(
        studentId,
        lessonId,
      );
      final now = DateTime.now();

      if (existing != null) {
        existing = existing.copyWith(
          progressPercent: progressPercent,
          quizScore: quizScore,
          timeSpentMinutes: existing.timeSpentMinutes + timeSpentMinutes,
          syncStatus: SyncStatus.pendingUpload,
          lastAccessedAt: now,
          updatedAt: now,
        );
        await _repository.updateProgress(existing);
      } else {
        final progress = ProgressModel(
          id: '${studentId}_$lessonId',
          studentId: studentId,
          lessonId: lessonId,
          progressPercent: progressPercent,
          quizScore: quizScore,
          timeSpentMinutes: timeSpentMinutes,
          syncStatus: SyncStatus.pendingUpload,
          lastAccessedAt: now,
          createdAt: now,
          updatedAt: now,
        );
        await _repository.saveProgress(progress);
      }

      // Refresh
      await loadProgress(studentId);
    } catch (e) {
      _errorMessage = 'Failed to update progress: ${e.toString()}';
      notifyListeners();
    }
  }
}
