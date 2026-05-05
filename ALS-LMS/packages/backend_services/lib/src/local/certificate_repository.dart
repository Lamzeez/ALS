import 'package:sqflite/sqflite.dart';
import 'package:backend_services/src/local/local_database.dart';
import 'package:shared_core/shared_core.dart';

/// Repository for managing certificates in local SQLite storage.
class CertificateRepository {
  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await LocalDatabase.instance.database;
    final results = await db.query(
      DbConstants.tableCertificates,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final db = await LocalDatabase.instance.database;
    return await db.query(DbConstants.tableCertificates);
  }

  Future<void> upsert(Map<String, dynamic> certificate) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      DbConstants.tableCertificates,
      certificate,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await LocalDatabase.instance.database;
    await db.delete(
      DbConstants.tableCertificates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
