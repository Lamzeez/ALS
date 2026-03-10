import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for session scheduling operations (SQLite local cache & Supabase remote).
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
    await _db.insert(DbConstants.tableSessions, session.toMap());
  }

  Future<void> updateSession(SessionModel session) async {
    await _db.update(DbConstants.tableSessions, session.toMap(), session.id);
  }

  Future<void> deleteSession(String id) async {
    await _db.delete(DbConstants.tableSessions, id);
  }

  Future<void> completeSession(String id) async {
    final session = await _db.queryById(DbConstants.tableSessions, id);
    if (session != null) {
      session['is_completed'] = 1;
      session['updated_at'] = DateTime.now().toIso8601String();
      await _db.update(DbConstants.tableSessions, session, id);
    }
  }

  // ─── Supabase Remote Operations ───

  Future<List<SessionModel>> fetchRemoteSessions(String teacherId) async {
    try {
      final res = await Supabase.instance.client
          .from('sessions')
          .select()
          .eq('teacher_id', teacherId)
          .order('scheduled_at', ascending: false);
      final items = List<Map<String, dynamic>>.from(res as List);
      final sessions = items.map((m) => SessionModel.fromMap(m)).toList();
      for (final session in sessions) {
        await _db.insert(DbConstants.tableSessions, session.toMap());
      }
      return sessions;
    } catch (_) {
      return [];
    }
  }

  Future<void> pushSession(SessionModel session) async {
    try {
      await Supabase.instance.client.from('sessions').upsert(session.toMap());
    } catch (_) {}
  }
}
