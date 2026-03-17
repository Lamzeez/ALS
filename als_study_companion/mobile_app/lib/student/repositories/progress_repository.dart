import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for student progress tracking.
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
    final map = progress.toMap();
    map['syncStatus'] = 'pendingUpload';
    await _db.insert(DbConstants.tableProgress, map);
  }

  Future<void> updateProgress(ProgressModel progress) async {
    final map = progress.toMap();
    map['syncStatus'] = 'pendingUpload';
    await _db.update(DbConstants.tableProgress, map, progress.id);
  }

  Future<void> syncProgressWithRemote(String studentId) async {
    try {
      final res = await Supabase.instance.client
          .from('progress')
          .select()
          .eq('student_id', studentId);
      
      final remoteItems = List<Map<String, dynamic>>.from(res as List);
      for (final item in remoteItems) {
        // Simple merge: remote wins for now
        await _db.insert(DbConstants.tableProgress, item);
      }
    } catch (e) {
      // Offline or error
    }
  }

  Future<double> getOverallProgress(String studentId) async {
    final all = await getProgressByStudent(studentId);
    if (all.isEmpty) return 0.0;
    return all.fold<double>(0, (sum, p) => sum + p.progressPercent) /
        all.length;
  }
}
