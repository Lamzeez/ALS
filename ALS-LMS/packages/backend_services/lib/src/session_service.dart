import 'dart:developer' as developer;
import 'package:shared_core/shared_core.dart';
import 'supabase_client.dart';

class SessionService {
  /// 🎯 Get all sessions for a teacher
  Future<List<Session>> getTeacherSessions(String teacherId) async {
    try {
      final rows = await SupabaseConfig.client
          .from('sessions')
          .select('*')
          .eq('teacher_id', teacherId)
          .order('scheduled_at', ascending: false);
      
      return (rows as List).map((r) => Session.fromJson(r)).toList();
    } catch (e) {
      developer.log('Error fetching teacher sessions', error: e, name: 'SessionService');
      return [];
    }
  }

  /// 🎯 Create a new session
  Future<Session?> createSession({
    required String teacherId,
    required String title,
    String? description,
    required DateTime scheduledAt,
    int durationMinutes = 60,
    String? location,
  }) async {
    try {
      final result = await SupabaseConfig.client.from('sessions').insert({
        'teacher_id': teacherId,
        'title': title,
        'description': description,
        'scheduled_at': scheduledAt.toIso8601String(),
        'duration_minutes': durationMinutes,
        'location': location,
        'status': 'scheduled',
      }).select().single();
      
      return Session.fromJson(result);
    } catch (e) {
      developer.log('Error creating session', error: e, name: 'SessionService');
      return null;
    }
  }

  /// 🎯 Update session status
  Future<bool> updateSessionStatus(String sessionId, SessionStatus status) async {
    try {
      await SupabaseConfig.client
          .from('sessions')
          .update({'status': status.toJson()})
          .eq('id', sessionId);
      return true;
    } catch (e) {
      developer.log('Error updating session status', error: e, name: 'SessionService');
      return false;
    }
  }
}

