import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import '../repositories/student_monitor_repository.dart';

/// ViewModel for teacher to monitor assigned students.
class StudentMonitorViewModel extends ChangeNotifier {
  final StudentMonitorRepository _repository = StudentMonitorRepository();

  List<StudentModel> _students = [];
  List<ProgressModel> _selectedStudentProgress = [];
  StudentModel? _selectedStudent;
  bool _isLoading = false;
  String? _errorMessage;

  List<StudentModel> get students => _students;
  List<ProgressModel> get selectedStudentProgress => _selectedStudentProgress;
  StudentModel? get selectedStudent => _selectedStudent;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadStudents(String teacherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Try remote first, fallback to local
      final remote = await _repository.fetchRemoteStudents(teacherId);
      _students = remote.isNotEmpty
          ? remote
          : await _repository.getStudentsByTeacher(teacherId);
    } catch (e) {
      try {
        _students = await _repository.getStudentsByTeacher(teacherId);
      } catch (_) {
        _errorMessage = 'Failed to load students: ${e.toString()}';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> viewStudentProgress(String studentId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedStudent = await _repository.getStudentById(studentId);
      // Try remote progress first, fallback to local
      final remoteProgress =
          await _repository.fetchRemoteStudentProgress(studentId);
      _selectedStudentProgress = remoteProgress.isNotEmpty
          ? remoteProgress
          : await _repository.getStudentProgress(studentId);
    } catch (e) {
      try {
        _selectedStudent = await _repository.getStudentById(studentId);
        _selectedStudentProgress =
            await _repository.getStudentProgress(studentId);
      } catch (_) {
        _errorMessage = 'Failed to load progress: ${e.toString()}';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearSelection() {
    _selectedStudent = null;
    _selectedStudentProgress = [];
    notifyListeners();
  }
}
