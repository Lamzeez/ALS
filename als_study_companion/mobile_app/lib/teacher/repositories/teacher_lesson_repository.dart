import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for teacher lesson management operations.
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
    final map = lesson.toMap();
    map['syncStatus'] = 'pendingUpload';
    await _db.insert(DbConstants.tableLessons, map);
  }

  Future<void> updateLesson(LessonModel lesson) async {
    final map = lesson.toMap();
    map['syncStatus'] = 'pendingUpload';
    await _db.update(DbConstants.tableLessons, map, lesson.id);
  }

  Future<void> deleteLesson(String id) async {
    // For delete, we might need a tombstone or just delete locally and 
    // try to delete on Supabase immediately if online.
    // For now, just delete locally.
    await _db.delete(DbConstants.tableLessons, id);
    try {
      await Supabase.instance.client.from('lessons').delete().eq('id', id);
    } catch (_) {}
  }

  Future<void> publishLesson(String id) async {
    final lesson = await _db.queryById(DbConstants.tableLessons, id);
    if (lesson != null) {
      final updated = Map<String, dynamic>.from(lesson);
      updated['is_published'] = 1;
      updated['syncStatus'] = 'pendingUpload';
      updated['updated_at'] = DateTime.now().toIso8601String();
      await _db.update(DbConstants.tableLessons, updated, id);
    }
  }
}
