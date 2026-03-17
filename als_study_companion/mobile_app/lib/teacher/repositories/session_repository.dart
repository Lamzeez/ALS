import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for session scheduling operations.
class SessionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<SessionModel>> getSessionsByTeacher(String teacherId) async {
    final maps = await _db.queryWhere(
      DbConstants.tableSessions,
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      orderBy: 'scheduled_at DESC',
    );
    return maps.map((m) => SessionModel.fromMap(m)).toList();
  }

  Future<List<SessionModel>> getUpcomingSessions(String teacherId) async {
    final now = DateTime.now().toIso8601String();
    final maps = await _db.queryWhere(
      DbConstants.tableSessions,
      where: 'teacher_id = ? AND scheduled_at > ? AND is_completed = 0',
      whereArgs: [teacherId, now],
      orderBy: 'scheduled_at ASC',
    );
    return maps.map((m) => SessionModel.fromMap(m)).toList();
  }

  Future<void> createSession(SessionModel session) async {
    final map = session.toMap();
    map['syncStatus'] = 'pendingUpload';
    await _db.insert(DbConstants.tableSessions, map);
  }

  Future<void> updateSession(SessionModel session) async {
    final map = session.toMap();
    map['syncStatus'] = 'pendingUpload';
    await _db.update(DbConstants.tableSessions, map, session.id);
  }

  Future<void> deleteSession(String id) async {
    await _db.delete(DbConstants.tableSessions, id);
    try {
      await Supabase.instance.client.from('sessions').delete().eq('id', id);
    } catch (_) {}
  }

  Future<void> completeSession(String id) async {
    final session = await _db.queryById(DbConstants.tableSessions, id);
    if (session != null) {
      final updated = Map<String, dynamic>.from(session);
      updated['is_completed'] = 1;
      updated['syncStatus'] = 'pendingUpload';
      updated['updated_at'] = DateTime.now().toIso8601String();
      await _db.update(DbConstants.tableSessions, updated, id);
    }
  }
}
