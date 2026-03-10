import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// Repository for managing content downloads (SQLite local cache & Supabase remote).
class DownloadRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<DownloadModel>> getDownloadsByStudent(String studentId) async {
    final maps = await _db.queryWhere(
      DbConstants.tableDownloads,
      where: 'studentId = ?',
      whereArgs: [studentId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => DownloadModel.fromMap(m)).toList();
  }

  Future<DownloadModel?> getDownloadForLesson(
    String studentId,
    String lessonId,
  ) async {
    final maps = await _db.queryWhere(
      DbConstants.tableDownloads,
      where: 'studentId = ? AND lessonId = ?',
      whereArgs: [studentId, lessonId],
    );
    return maps.isNotEmpty ? DownloadModel.fromMap(maps.first) : null;
  }

  Future<void> saveDownload(DownloadModel download) async {
    await _db.insert(DbConstants.tableDownloads, download.toMap());
  }

  Future<void> updateDownload(DownloadModel download) async {
    await _db.update(DbConstants.tableDownloads, download.toMap(), download.id);
  }

  Future<void> deleteDownload(String id) async {
    await _db.delete(DbConstants.tableDownloads, id);
  }

  Future<List<DownloadModel>> getCompletedDownloads(String studentId) async {
    final maps = await _db.queryWhere(
      DbConstants.tableDownloads,
      where: 'studentId = ? AND status = ?',
      whereArgs: [studentId, 'downloaded'],
    );
    return maps.map((m) => DownloadModel.fromMap(m)).toList();
  }

  // ─── Supabase Remote Operations ───

  Future<List<DownloadModel>> fetchRemoteDownloads(String studentId) async {
    try {
      final res = await Supabase.instance.client
          .from('downloads')
          .select()
          .eq('student_id', studentId);
      final items = List<Map<String, dynamic>>.from(res as List);
      final downloads = items.map((m) => DownloadModel.fromMap(m)).toList();
      for (final d in downloads) {
        await _db.insert(DbConstants.tableDownloads, d.toMap());
      }
      return downloads;
    } catch (_) {
      return [];
    }
  }

  Future<void> pushDownload(DownloadModel download) async {
    try {
      await Supabase.instance.client
          .from('downloads')
          .upsert(download.toMap());
    } catch (_) {}
  }
}
