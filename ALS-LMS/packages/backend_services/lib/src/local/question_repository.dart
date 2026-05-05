import 'package:sqflite/sqflite.dart';
import 'package:backend_services/src/local/local_database.dart';

/// Repository for managing quiz questions in local SQLite storage.
class QuestionRepository {
  Future<List<Map<String, dynamic>>> getQuestionsByQuiz(
      String quizId) async {
    final db = await LocalDatabase.instance.database;
    return await db.query(
      'questions',
      where: 'quiz_id = ?',
      whereArgs: [quizId],
      orderBy: 'order_index ASC',
    );
  }

  Future<void> insertQuestions(
      List<Map<String, dynamic>> questions) async {
    final db = await LocalDatabase.instance.database;
    final batch = db.batch();
    for (final question in questions) {
      batch.insert(
        'questions',
        question,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteQuestionsByQuiz(String quizId) async {
    final db = await LocalDatabase.instance.database;
    await db.delete(
      'questions',
      where: 'quiz_id = ?',
      whereArgs: [quizId],
    );
  }
}
