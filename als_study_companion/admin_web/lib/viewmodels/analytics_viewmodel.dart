import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ViewModel for analytics and reporting with real Supabase data.
class AnalyticsViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  // Analytics data
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalLessons = 0;
  int _totalQuizzes = 0;
  double _averageProgress = 0.0;
  int _activeUsers = 0;
  int _publishedLessons = 0;
  int _pendingTeachers = 0;
  List<Map<String, dynamic>> _recentActivity = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalStudents => _totalStudents;
  int get totalTeachers => _totalTeachers;
  int get totalLessons => _totalLessons;
  int get totalQuizzes => _totalQuizzes;
  double get averageProgress => _averageProgress;
  int get activeUsers => _activeUsers;
  int get publishedLessons => _publishedLessons;
  int get pendingTeachers => _pendingTeachers;
  List<Map<String, dynamic>> get recentActivity => _recentActivity;

  Future<void> loadAnalytics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = Supabase.instance.client;

      // Fetch user counts by role
      final usersRes = await client
          .from('users')
          .select('role, teacher_verified');
      final users = List<Map<String, dynamic>>.from(usersRes as List);
      _totalStudents = users.where((u) => u['role'] == 'student').length;
      _totalTeachers = users.where((u) => u['role'] == 'teacher').length;
      _activeUsers = users
          .where((u) => u['is_active'] == true || u['is_active'] == 1)
          .length;
      _pendingTeachers = users
          .where(
            (u) =>
                u['role'] == 'teacher' &&
                (u['teacher_verified'] == false ||
                    u['teacher_verified'] == null),
          )
          .length;

      // Lesson counts
      final lessonsRes = await client
          .from('lessons')
          .select('id, is_published');
      final lessons = List<Map<String, dynamic>>.from(lessonsRes as List);
      _totalLessons = lessons.length;
      _publishedLessons = lessons
          .where((l) => l['is_published'] == true || l['is_published'] == 1)
          .length;

      // Quiz count
      final quizzesRes = await client.from('quizzes').select('id');
      _totalQuizzes = (quizzesRes as List).length;

      // Average progress
      final progressRes = await client
          .from('progress')
          .select('progress_percent');
      final progressList = List<Map<String, dynamic>>.from(progressRes as List);
      if (progressList.isNotEmpty) {
        final total = progressList.fold<double>(
          0,
          (sum, p) => sum + ((p['progress_percent'] as num?)?.toDouble() ?? 0),
        );
        _averageProgress = total / progressList.length;
      } else {
        _averageProgress = 0;
      }

      // Recent audit logs (last 20)
      try {
        final logsRes = await client
            .from('audit_logs')
            .select()
            .order('created_at', ascending: false)
            .limit(20);
        _recentActivity = List<Map<String, dynamic>>.from(logsRes as List);
      } catch (_) {
        _recentActivity = [];
      }
    } catch (e) {
      _errorMessage = 'Failed to load analytics: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }
}
