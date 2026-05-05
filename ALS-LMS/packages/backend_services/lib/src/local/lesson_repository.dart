import 'package:sqflite/sqflite.dart';
import 'package:backend_services/src/local/local_database.dart';

/// Repository for managing lessons in local SQLite storage.
class LessonRepository {
  Future<List<Map<String, dynamic>>> getLessonsByCourse(
      String courseId) async {
    final db = await LocalDatabase.instance.database;
    return await db.query(
      'lessons',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'order_index ASC',
    );
  }

  Future<Map<String, dynamic>?> getLessonById(String lessonId) async {
    final db = await LocalDatabase.instance.database;
    final results = await db.query(
      'lessons',
      where: 'id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertLessons(List<Map<String, dynamic>> lessons) async {
    final db = await LocalDatabase.instance.database;
    final batch = db.batch();
    for (final lesson in lessons) {
      batch.insert(
        'lessons',
        lesson,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteLessonsByCourse(String courseId) async {
    final db = await LocalDatabase.instance.database;
    await db.delete(
      'lessons',
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
  }

  Future<bool> isLessonDownloaded(String lessonId) async {
    final db = await LocalDatabase.instance.database;
    final results = await db.query(
      'lessons',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<int> getTotalLessons() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM lessons');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
