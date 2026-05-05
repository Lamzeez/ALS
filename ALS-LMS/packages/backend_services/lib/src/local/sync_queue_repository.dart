import 'package:sqflite/sqflite.dart';
import 'package:backend_services/src/local/local_database.dart';

/// Repository for managing the sync queue (offline operations pending upload).
class SyncQueueRepository {
  /// Add an operation to the sync queue
  Future<void> addToQueue({
    required String studentId,
    required String operationType,
    required String tableName,
    required Map<String, dynamic> payload,
  }) async {
    final db = await LocalDatabase.instance.database;
    await db.insert('sync_queue', {
      'id': _generateId(),
      'student_id': studentId,
      'operation_type': operationType,
      'table_name': tableName,
      'payload': payload.toString(),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  /// Get all pending operations
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await LocalDatabase.instance.database;
    return await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  /// Mark an operation as completed
  Future<void> markAsCompleted(String queueId) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'sync_queue',
      {'status': 'completed'},
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  /// Mark an operation as failed
  Future<void> markAsFailed(String queueId, String error) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'sync_queue',
      {
        'status': 'failed',
        'last_error': error,
        'retry_count': db.rawInsert(
          'SELECT retry_count + 1 FROM sync_queue WHERE id = ?',
          [queueId],
        ),
      },
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  /// Retry failed operations
  Future<void> retryFailedOperations() async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'sync_queue',
      {
        'status': 'pending',
        'retry_count': db.rawInsert(
          'SELECT retry_count + 1 FROM sync_queue WHERE status = ?',
          ['failed'],
        ),
      },
      where: 'status = ?',
      whereArgs: ['failed'],
    );
  }

  /// Clear completed operations
  Future<void> clearCompleted() async {
    final db = await LocalDatabase.instance.database;
    await db.delete(
      'sync_queue',
      where: 'status = ?',
      whereArgs: ['completed'],
    );
  }

  /// Get queue statistics
  Future<Map<String, int>> getQueueStats() async {
    final db = await LocalDatabase.instance.database;
    final pending = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue WHERE status = ?',
      ['pending'],
    );
    final failed = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue WHERE status = ?',
      ['failed'],
    );

    return {
      'pending': Sqflite.firstIntValue(pending) ?? 0,
      'failed': Sqflite.firstIntValue(failed) ?? 0,
    };
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
