import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for student progress tracking (SQLite local cache & Supabase remote).
class ProgressRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<ProgressModel>> getProgressByStudent(String studentId) async {
    final maps = await _db.queryWhere(
      DbConstants.tableProgress,
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'lastAccessedAt DESC',
    );
    return maps.map((m) => ProgressModel.fromMap(m)).toList();
  }

  Future<ProgressModel?> getProgressForLesson(
    String studentId,
    String lessonId,
  ) async {
    final maps = await _db.queryWhere(
      DbConstants.tableProgress,
      where: 'studentId = ? AND lessonId = ?',
      whereArgs: [studentId, lessonId],
    );
    return maps.isNotEmpty ? ProgressModel.fromMap(maps.first) : null;
  }

  Future<void> saveProgress(ProgressModel progress) async {
    await _db.insert(DbConstants.tableProgress, progress.toMap());
  }

  Future<void> updateProgress(ProgressModel progress) async {
    await _db.update(DbConstants.tableProgress, progress.toMap(), progress.id);
  }

  Future<List<ProgressModel>> getPendingSyncProgress() async {
    final maps = await _db.queryWhere(
      DbConstants.tableProgress,
      where: 'syncStatus = ?',
      whereArgs: ['pendingUpload'],
    );
    return maps.map((m) => ProgressModel.fromMap(m)).toList();
  }

  Future<double> getOverallProgress(String studentId) async {
    final all = await getProgressByStudent(studentId);
    if (all.isEmpty) return 0.0;
    return all.fold<double>(0, (sum, p) => sum + p.progressPercent) /
        all.length;
  }

  // ─── Supabase Remote Operations ───

  Future<List<ProgressModel>> fetchRemoteProgress(String studentId) async {
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

  Future<void> pushProgress(ProgressModel progress) async {
    try {
      await Supabase.instance.client.from('progress').upsert(progress.toMap());
    } catch (_) {}
  }
}
