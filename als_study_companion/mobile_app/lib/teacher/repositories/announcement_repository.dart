import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for announcement operations.
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
}
