import 'package:sqflite/sqflite.dart';
import 'package:backend_services/src/local/local_database.dart';

/// Repository for managing student progress in local SQLite storage.
class ProgressRepository {
  Future<List<Map<String, dynamic>>> getStudentProgress(
      String studentId) async {
    final db = await LocalDatabase.instance.database;
    return await db.query(
      'progress',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'last_accessed_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getLessonProgress(
      String studentId, String lessonId) async {
    final db = await LocalDatabase.instance.database;
    final results = await db.query(
      'progress',
      where: 'student_id = ? AND lesson_id = ?',
      whereArgs: [studentId, lessonId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> upsertProgress(Map<String, dynamic> progress) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      'progress',
      progress,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateProgress({
    required String studentId,
    required String lessonId,
    required double progressPercent,
    int timeSpentMinutes = 0,
    bool isCompleted = false,
  }) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'progress',
      {
        'progress_percent': progressPercent,
        'time_spent_minutes': timeSpentMinutes,
        'is_completed': isCompleted ? 1 : 0,
        'last_accessed_at': DateTime.now().toIso8601String(),
        if (isCompleted) 'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'student_id = ? AND lesson_id = ?',
      whereArgs: [studentId, lessonId],
    );
  }

  Future<double> getCourseCompletionPercentage(
      String studentId, String courseId) async {
    final db = await LocalDatabase.instance.database;
    final result = await db.rawQuery('''
      SELECT AVG(p.progress_percent) as avg_progress
      FROM progress p
      INNER JOIN lessons l ON p.lesson_id = l.id
      WHERE p.student_id = ? AND l.course_id = ?
    ''', [studentId, courseId]);

    return (result.first['avg_progress'] as double?) ?? 0.0;
  }

  Future<int> getCompletedLessonsCount(String studentId) async {
    final db = await LocalDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM progress WHERE student_id = ? AND is_completed = 1',
      [studentId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
