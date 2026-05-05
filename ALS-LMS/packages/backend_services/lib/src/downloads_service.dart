import 'dart:developer' as developer;
import 'package:shared_core/shared_core.dart';
import 'supabase_client.dart';
import 'local/local_database.dart';
import 'package:sqflite/sqflite.dart';

class DownloadsService {
  /// 🎯 Get all downloads for the current student
  Future<List<Download>> getStudentDownloads(String studentId) async {
    try {
      // Prefer local storage for offline access
      final db = await LocalDatabase.instance.database;
      final localRows = await db.query('downloads', where: 'student_id = ?', whereArgs: [studentId]);
      
      if (localRows.isNotEmpty) {
        return localRows.map((r) => Download.fromJson(r)).toList();
      }

      // Fallback to Supabase if local is empty
      final rows = await SupabaseConfig.client
          .from('downloads')
          .select('*')
          .eq('student_id', studentId);
      
      final downloads = (rows as List).map((r) => Download.fromJson(r)).toList();
      
      // Sync to local
      for (final d in downloads) {
        await db.insert('downloads', d.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      
      return downloads;
    } catch (e) {
      developer.log('Error fetching student downloads', error: e, name: 'DownloadsService');
      return [];
    }
  }

  /// 🎯 Start/Simulate a download
  Future<void> startDownload(String studentId, String lessonId) async {
    try {
      final db = await LocalDatabase.instance.database;
      final downloadId = '${studentId}_$lessonId';
      
      final download = Download(
        id: downloadId,
        studentId: studentId,
        lessonId: lessonId,
        status: DownloadStatus.downloading,
        downloadProgress: 0.1,
      );

      // Save locally
      await db.insert('downloads', download.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      
      // Update Supabase
      await SupabaseConfig.client.from('downloads').upsert(download.toJson());

      // Simulate progress (for demo purposes)
      _simulateProgress(downloadId, studentId);
      
    } catch (e) {
      developer.log('Error starting download', error: e, name: 'DownloadsService');
    }
  }

  void _simulateProgress(String id, String studentId) async {
    final db = await LocalDatabase.instance.database;
    for (double p = 0.2; p <= 1.0; p += 0.2) {
      await Future.delayed(const Duration(seconds: 1));
      final status = p >= 1.0 ? DownloadStatus.completed : DownloadStatus.downloading;
      
      await db.update('downloads', 
        {'download_progress': p, 'status': status.toJson()},
        where: 'id = ?', whereArgs: [id]
      );
      
      // We don't necessarily need to sync every 20% to cloud in real-time if offline
      if (p >= 1.0) {
        await SupabaseConfig.client.from('downloads').update({'download_progress': 1.0, 'status': 'completed'}).eq('id', id);
      }
    }
  }
}

