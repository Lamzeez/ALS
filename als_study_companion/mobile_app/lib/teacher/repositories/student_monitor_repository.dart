import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for monitoring student progress (SQLite local cache & Supabase remote).
class StudentMonitorRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<StudentModel>> getStudentsByTeacher(String teacherId) async {
    final maps = await _db.queryWhere(
      DbConstants.tableStudents,
      where: 'teacherId = ?',
      whereArgs: [teacherId],
    );
    return maps.map((m) => StudentModel.fromMap(m)).toList();
  }

  Future<List<ProgressModel>> getStudentProgress(String studentId) async {
    final maps = await _db.queryWhere(
      DbConstants.tableProgress,
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'lastAccessedAt DESC',
    );
    return maps.map((m) => ProgressModel.fromMap(m)).toList();
  }

  Future<StudentModel?> getStudentById(String id) async {
    final map = await _db.queryById(DbConstants.tableStudents, id);
    return map != null ? StudentModel.fromMap(map) : null;
  }

  // ─── Supabase Remote Operations ───

  Future<List<StudentModel>> fetchRemoteStudents(String teacherId) async {
    try {
      final res = await Supabase.instance.client
          .from('students')
          .select()
          .eq('teacher_id', teacherId);
      final items = List<Map<String, dynamic>>.from(res as List);
      final students = items.map((m) => StudentModel.fromMap(m)).toList();
      for (final s in students) {
        await _db.insert(DbConstants.tableStudents, s.toMap());
      }
      return students;
    } catch (_) {
      return [];
    }
  }

  Future<List<ProgressModel>> fetchRemoteStudentProgress(
    String studentId,
  ) async {
    try {
      final res = await Supabase.instance.client
          .from('progress')
          .select()
          .eq('student_id', studentId);
      final items = List<Map<String, dynamic>>.from(res as List);
      final progressList = items.map((m) => ProgressModel.fromMap(m)).toList();
      for (final p in progressList) {
        await _db.insert(DbConstants.tableProgress, p.toMap());
      }
      return progressList;
    } catch (_) {
      return [];
    }
  }
}
