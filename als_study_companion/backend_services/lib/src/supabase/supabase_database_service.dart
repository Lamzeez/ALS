import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_core/shared_core.dart';

/// Service for Supabase database operations.
///
/// Provides CRUD operations for all tables: users, lessons, quizzes,
/// questions, progress, sessions, announcements, als_centers.
class SupabaseDatabaseService {
  final SupabaseClient _client;

  SupabaseDatabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // ─── Generic CRUD ────────────────────────────────────────────────────

  /// Insert or replace a row in a table.
  Future<void> addDocument(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _client.from(table).upsert({...data, 'id': id});
  }

  /// Get a single row by id.
  Future<Map<String, dynamic>?> getDocument(String table, String id) async {
    final res = await _client.from(table).select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  /// Update a row by id.
  Future<void> updateDocument(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _client.from(table).update(data).eq('id', id);
  }

  /// Delete a row by id.
  Future<void> deleteDocument(String table, String id) async {
    await _client.from(table).delete().eq('id', id);
  }

  /// Get all rows from a table.
  Future<List<Map<String, dynamic>>> getCollection(String table) async {
    final res = await _client.from(table).select();
    return List<Map<String, dynamic>>.from(res);
  }

  /// Query rows with a single equality filter.
  Future<List<Map<String, dynamic>>> queryCollection(
    String table, {
    required String field,
    required dynamic isEqualTo,
  }) async {
    final res = await _client.from(table).select().eq(field, isEqualTo);
    return List<Map<String, dynamic>>.from(res);
  }

  // ─── Lessons ─────────────────────────────────────────────────────────

  /// Get all lessons, optionally filtered by teacher ID.
  Future<List<LessonModel>> getLessons({String? teacherId}) async {
    dynamic query = _client.from('lessons').select();
    if (teacherId != null) {
      query = (query as PostgrestFilterBuilder).eq('teacher_id', teacherId);
    }
    final res = await query;
    final items = List<Map<String, dynamic>>.from(res);
    return items.map((m) => LessonModel.fromMap(m)).toList();
  }

  /// Save or update a lesson.
  Future<void> saveLesson(LessonModel lesson) async {
    await _client.from('lessons').upsert(lesson.toMap());
  }

  // ─── Quizzes ─────────────────────────────────────────────────────────

  /// Get quizzes for a lesson.
  Future<List<QuizModel>> getQuizzesForLesson(String lessonId) async {
    final res = await _client
        .from('quizzes')
        .select()
        .eq('lesson_id', lessonId);
    final items = List<Map<String, dynamic>>.from(res);
    return items.map((m) => QuizModel.fromMap(m)).toList();
  }

  /// Save a quiz.
  Future<void> saveQuiz(QuizModel quiz) async {
    await _client.from('quizzes').upsert(quiz.toMap());
  }

  // ─── Questions ───────────────────────────────────────────────────────

  /// Get questions for a quiz.
  Future<List<QuestionModel>> getQuestionsForQuiz(String quizId) async {
    final res = await _client.from('questions').select().eq('quiz_id', quizId);
    final items = List<Map<String, dynamic>>.from(res);
    return items.map((m) => QuestionModel.fromMap(m)).toList();
  }

  /// Save a question.
  Future<void> saveQuestion(QuestionModel question) async {
    await _client.from('questions').upsert(question.toMap());
  }

  // ─── Progress ────────────────────────────────────────────────────────

  /// Get student progress records.
  Future<List<ProgressModel>> getStudentProgress(String studentId) async {
    final res = await _client
        .from('progress')
        .select()
        .eq('student_id', studentId);
    final items = List<Map<String, dynamic>>.from(res);
    return items.map((m) => ProgressModel.fromMap(m)).toList();
  }

  /// Save progress record.
  Future<void> saveProgress(ProgressModel progress) async {
    await _client.from('progress').upsert(progress.toMap());
  }

  // ─── Sessions ────────────────────────────────────────────────────────

  /// Get sessions for a teacher.
  Future<List<SessionModel>> getTeacherSessions(String teacherId) async {
    final res = await _client
        .from('sessions')
        .select()
        .eq('teacher_id', teacherId);
    final items = List<Map<String, dynamic>>.from(res);
    return items.map((m) => SessionModel.fromMap(m)).toList();
  }

  /// Save a session.
  Future<void> saveSession(SessionModel session) async {
    await _client.from('sessions').upsert(session.toMap());
  }

  // ─── Announcements ───────────────────────────────────────────────────

  /// Get announcements, optionally by center.
  Future<List<AnnouncementModel>> getAnnouncements({String? centerId}) async {
    dynamic query = _client.from('announcements').select();
    if (centerId != null) {
      query = (query as PostgrestFilterBuilder).contains('target', {
        'center_ids': [centerId],
      });
    }
    final res = await (query as PostgrestFilterBuilder).order(
      'created_at',
      ascending: false,
    );
    final items = List<Map<String, dynamic>>.from(res);
    return items.map((m) => AnnouncementModel.fromMap(m)).toList();
  }

  /// Save an announcement.
  Future<void> saveAnnouncement(AnnouncementModel announcement) async {
    await _client.from('announcements').upsert(announcement.toMap());
  }

  // ─── ALS Centers ─────────────────────────────────────────────────────

  /// Get all ALS centers.
  Future<List<AlsCenterModel>> getAlsCenters() async {
    final res = await _client.from('als_centers').select();
    final items = List<Map<String, dynamic>>.from(res);
    return items.map((m) => AlsCenterModel.fromMap(m)).toList();
  }

  /// Save an ALS center.
  Future<void> saveAlsCenter(AlsCenterModel center) async {
    await _client.from('als_centers').upsert(center.toMap());
  }

  // ─── Users ───────────────────────────────────────────────────────────

  /// Get all users, optionally filtered by role.
  Future<List<UserModel>> getUsers({UserRole? role}) async {
    dynamic query = _client.from('users').select();
    if (role != null) {
      query = (query as PostgrestFilterBuilder).eq('role', role.name);
    }
    final res = await query;
    final items = List<Map<String, dynamic>>.from(res);
    return items.map((m) => UserModel.fromMap(m)).toList();
  }
}
