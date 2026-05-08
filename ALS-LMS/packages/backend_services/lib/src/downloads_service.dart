import 'dart:developer' as developer;
import 'dart:io';
import 'package:shared_core/shared_core.dart';
import 'supabase_client.dart';
import 'local/local_database.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class DownloadsService {
  final _client = http.Client();

  /// 🎯 Get all downloads for the current student
  Future<List<Download>> getStudentDownloads(String studentId) async {
    try {
      final db = await LocalDatabase.instance.database;
      final localRows = await db.query('downloads', where: 'student_id = ?', whereArgs: [studentId]);
      
      return localRows.map((r) => Download.fromJson(r)).toList();
    } catch (e) {
      developer.log('Error fetching student downloads', error: e, name: 'DownloadsService');
      return [];
    }
  }

  /// 🎯 Start a real download
  Future<void> startDownload(String studentId, String lessonId) async {
    try {
      final db = await LocalDatabase.instance.database;
      final downloadId = '${studentId}_$lessonId';

      // 1. Get lesson media URL from Supabase
      final mediaRows = await SupabaseConfig.client
          .from('lesson_media')
          .select('storage_url, file_name, file_type')
          .eq('lesson_id', lessonId);

      if (mediaRows.isEmpty) throw Exception('No media found for lesson $lessonId');
      
      final media = mediaRows.first;
      final url = media['storage_url'] as String;
      final fileName = media['file_name'] as String;
      
      // 2. Prepare local path
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(appDir.path, 'downloads'));
      if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
      
      final localPath = p.join(downloadsDir.path, '${lessonId}_$fileName');

      // 3. Create/Update Download record to 'downloading'
      final download = Download(
        id: downloadId,
        studentId: studentId,
        lessonId: lessonId,
        status: DownloadStatus.downloading,
        downloadProgress: 0.0,
        localFilePath: localPath,
      );

      await db.insert('downloads', download.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);

      // 4. Perform HTTP download with progress
      final response = await _client.send(http.Request('GET', Uri.parse(url)));
      final total = response.contentLength ?? 0;
      int received = 0;
      
      final file = File(localPath);
      final sink = file.openWrite();

      await response.stream.map((chunk) {
        received += chunk.length;
        if (total > 0) {
          final progress = received / total;
          // Update DB occasionally to avoid too many writes
          if (received % (1024 * 512) == 0 || received == total) {
             db.update('downloads', 
              {'download_progress': progress},
              where: 'id = ?', whereArgs: [downloadId]
            );
          }
        }
        return chunk;
      }).pipe(sink);

      // 5. Mark as completed
      await db.update('downloads', 
        {
          'download_progress': 1.0, 
          'status': DownloadStatus.completed.toJson(),
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?', whereArgs: [downloadId]
      );

      // 6. Sync status to Supabase (Optional, but good for cross-device visibility)
      try {
        await SupabaseConfig.client.from('downloads').upsert({
          'id': downloadId,
          'student_id': studentId,
          'lesson_id': lessonId,
          'status': 'completed',
          'download_progress': 1.0,
        });
      } catch (_) {}

      developer.log('Download completed: $localPath', name: 'DownloadsService');
      
    } catch (e) {
      developer.log('Download failed', error: e, name: 'DownloadsService');
      final db = await LocalDatabase.instance.database;
      await db.update('downloads', 
        {'status': DownloadStatus.failed.toJson()},
        where: 'lesson_id = ?', whereArgs: [lessonId]
      );
    }
  }

  Future<Download?> getDownload(String studentId, String lessonId) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query('downloads', 
      where: 'student_id = ? AND lesson_id = ?', 
      whereArgs: [studentId, lessonId]
    );
    if (rows.isEmpty) return null;
    return Download.fromJson(rows.first);
  }
}
