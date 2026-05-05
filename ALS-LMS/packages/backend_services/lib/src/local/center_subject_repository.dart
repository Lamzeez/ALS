import 'package:sqflite/sqflite.dart';
import 'package:backend_services/src/local/local_database.dart';
import 'package:shared_core/shared_core.dart';

/// Repository for managing center subjects in local SQLite storage.
class CenterSubjectRepository {
  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await LocalDatabase.instance.database;
    final results = await db.query(
      DbConstants.tableCenterSubjects,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await LocalDatabase.instance.database;
    return await db.query(DbConstants.tableCenterSubjects);
  }

  Future<void> upsert(Map<String, dynamic> centerSubject) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      DbConstants.tableCenterSubjects,
      centerSubject,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await LocalDatabase.instance.database;
    await db.delete(
      DbConstants.tableCenterSubjects,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
