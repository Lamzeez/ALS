import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for announcement operations (SQLite local cache & Supabase remote).
class AnnouncementRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<AnnouncementModel>> getAnnouncements() async {
    final maps = await _db.queryWhere(
      DbConstants.tableAnnouncements,
      where: 'isActive = 1',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => AnnouncementModel.fromMap(m)).toList();
  }

  Future<List<AnnouncementModel>> getAnnouncementsByAuthor(
    String authorId,
  ) async {
    final maps = await _db.queryWhere(
      DbConstants.tableAnnouncements,
      where: 'authorId = ?',
      whereArgs: [authorId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => AnnouncementModel.fromMap(m)).toList();
  }

  Future<void> createAnnouncement(AnnouncementModel announcement) async {
    final map = announcement.toMap();
    map['syncStatus'] = 'pendingUpload';
    await _db.insert(DbConstants.tableAnnouncements, map);
  }

  Future<void> deleteAnnouncement(String id) async {
    await _db.delete(DbConstants.tableAnnouncements, id);
    try {
      await Supabase.instance.client.from('announcements').delete().eq('id', id);
    } catch (_) {}
  }

  // ─── Supabase Remote Operations ───

  Future<List<AnnouncementModel>> fetchRemoteAnnouncements() async {
    try {
      final res = await Supabase.instance.client
          .from('announcements')
          .select()
          .order('created_at', ascending: false);
      final items = List<Map<String, dynamic>>.from(res as List);
      final announcements =
          items.map((m) => AnnouncementModel.fromMap(m)).toList();
      for (final a in announcements) {
        await _db.insert(DbConstants.tableAnnouncements, a.toMap());
      }
      return announcements;
    } catch (_) {
      return [];
    }
  }

  Future<void> pushAnnouncement(AnnouncementModel announcement) async {
    try {
      await Supabase.instance.client
          .from('announcements')
          .upsert(announcement.toMap());
    } catch (_) {}
  }
}
