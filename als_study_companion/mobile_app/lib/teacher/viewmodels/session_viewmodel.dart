import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import '../repositories/session_repository.dart';

/// ViewModel for scheduling and managing learning sessions.
class SessionViewModel extends ChangeNotifier {
  final SessionRepository _repository = SessionRepository();

  List<SessionModel> _sessions = [];
  List<SessionModel> _upcomingSessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SessionModel> get sessions => _sessions;
  List<SessionModel> get upcomingSessions => _upcomingSessions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadSessions(String teacherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Try remote first, fallback to local
      final remote = await _repository.fetchRemoteSessions(teacherId);
      if (remote.isNotEmpty) {
        _sessions = remote;
      } else {
        _sessions = await _repository.getSessionsByTeacher(teacherId);
      }
      _upcomingSessions = await _repository.getUpcomingSessions(teacherId);
    } catch (e) {
      try {
        _sessions = await _repository.getSessionsByTeacher(teacherId);
        _upcomingSessions = await _repository.getUpcomingSessions(teacherId);
      } catch (_) {
        _errorMessage = 'Failed to load sessions: ${e.toString()}';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createSession(SessionModel session) async {
    try {
      await _repository.createSession(session);
      _repository.pushSession(session); // push to remote (fire-and-forget)
      _sessions.insert(0, session);
      _upcomingSessions =
          _sessions
              .where(
                (s) => s.scheduledAt.isAfter(DateTime.now()) && !s.isCompleted,
              )
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to create session: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeSession(String sessionId) async {
    try {
      await _repository.completeSession(sessionId);
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index >= 0) {
        _sessions[index] = _sessions[index].copyWith(isCompleted: true);
      }
      _upcomingSessions.removeWhere((s) => s.id == sessionId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to complete session: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    try {
      await _repository.deleteSession(sessionId);
      _sessions.removeWhere((s) => s.id == sessionId);
      _upcomingSessions.removeWhere((s) => s.id == sessionId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete session: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
