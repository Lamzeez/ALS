import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for teacher lesson management operations (SQLite local cache & Supabase remote).
class TeacherLessonRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<LessonModel>> getLessonsByTeacher(String teacherId) async {
    final maps = await _db.queryWhere(
      DbConstants.tableLessons,
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => LessonModel.fromMap(m)).toList();
  }

  Future<void> createLesson(LessonModel lesson) async {
    await _db.insert(DbConstants.tableLessons, lesson.toMap());
  }

  Future<void> updateLesson(LessonModel lesson) async {
    await _db.update(DbConstants.tableLessons, lesson.toMap(), lesson.id);
  }

  Future<void> deleteLesson(String id) async {
    await _db.delete(DbConstants.tableLessons, id);
  }

  Future<void> publishLesson(String id) async {
    final lesson = await _db.queryById(DbConstants.tableLessons, id);
    if (lesson != null) {
      lesson['is_published'] = 1;
      lesson['updated_at'] = DateTime.now().toIso8601String();
      await _db.update(DbConstants.tableLessons, lesson, id);
    }
  }

  // ─── Supabase Remote Operations ───

  Future<List<LessonModel>> fetchRemoteLessons(String teacherId) async {
    try {
      final res = await Supabase.instance.client
          .from('lessons')
          .select()
          .eq('teacher_id', teacherId)
          .order('updated_at', ascending: false);
      final items = List<Map<String, dynamic>>.from(res as List);
      final lessons = items.map((m) => LessonModel.fromMap(m)).toList();
      for (final lesson in lessons) {
        await _db.insert(DbConstants.tableLessons, lesson.toMap());
      }
      return lessons;
    } catch (_) {
      return [];
    }
  }

  Future<void> pushLesson(LessonModel lesson) async {
    try {
      await Supabase.instance.client.from('lessons').upsert(lesson.toMap());
    } catch (_) {}
  }
}
