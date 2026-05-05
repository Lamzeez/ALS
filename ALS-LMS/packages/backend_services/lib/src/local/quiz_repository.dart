import 'package:sqflite/sqflite.dart';
import 'package:backend_services/src/local/local_database.dart';

/// Repository for managing quizzes in local SQLite storage.
class QuizRepository {
  Future<List<Map<String, dynamic>>> getQuizzesByLesson(
      String lessonId) async {
    final db = await LocalDatabase.instance.database;
    return await db.query(
      'quizzes',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
    );
  }

  Future<Map<String, dynamic>?> getQuizById(String quizId) async {
    final db = await LocalDatabase.instance.database;
    final results = await db.query(
      'quizzes',
      where: 'id = ?',
      whereArgs: [quizId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertQuizzes(List<Map<String, dynamic>> quizzes) async {
    final db = await LocalDatabase.instance.database;
    final batch = db.batch();
    for (final quiz in quizzes) {
      batch.insert(
        'quizzes',
        quiz,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<bool> isQuizDownloaded(String quizId) async {
    final db = await LocalDatabase.instance.database;
    final results = await db.query(
      'quizzes',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [quizId],
      limit: 1,
    );
    return results.isNotEmpty;
  }
}
