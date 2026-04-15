import 'package:sqflite/sqflite.dart';
import 'package:shared_services/src/local/local_database.dart';

/// Repository for managing quiz scores in local SQLite storage.
class ScoreRepository {
  Future<List<Map<String, dynamic>>> getStudentScores(
      String studentId) async {
    final db = await LocalDatabase.instance.database;
    return await db.query(
      'scores',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'completed_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getQuizScore(
      String studentId, String quizId) async {
    final db = await LocalDatabase.instance.database;
    final results = await db.query(
      'scores',
      where: 'student_id = ? AND quiz_id = ?',
      whereArgs: [studentId, quizId],
      orderBy: 'completed_at DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertScore(Map<String, dynamic> score) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      'scores',
      score,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<double> getAverageScore(String studentId) async {
    final db = await LocalDatabase.instance.database;
    final result = await db.rawQuery(
      'SELECT AVG(score * 100.0 / total_questions) as avg_score FROM scores WHERE student_id = ?',
      [studentId],
    );
    return (result.first['avg_score'] as double?) ?? 0.0;
  }
}
