import 'package:sqflite/sqflite.dart';
import 'package:backend_services/src/local/local_database.dart';
import 'package:shared_core/shared_core.dart';

/// Repository for managing course timelines in local SQLite storage.
class CourseTimelineRepository {
  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await LocalDatabase.instance.database;
    final results = await db.query(
      DbConstants.tableCourseTimeline,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await LocalDatabase.instance.database;
    return await db.query(DbConstants.tableCourseTimeline);
  }

  Future<void> upsert(Map<String, dynamic> timeline) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      DbConstants.tableCourseTimeline,
      timeline,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await LocalDatabase.instance.database;
    await db.delete(
      DbConstants.tableCourseTimeline,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
