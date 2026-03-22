import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:backend_services/backend_services.dart';
import 'package:shared_core/shared_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../database/database_helper.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Initialize environment and Supabase
      await dotenv.load();
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL']!,
        anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      );

      // 2. Setup Services
      final dbService = SupabaseDatabaseService(client: Supabase.instance.client);
      final syncService = SyncService(databaseService: dbService);
      
      // 3. Define the pushable tables (matching SyncViewModel)
      const pushableTables = [
        ('progress', DbConstants.tableProgress),
        ('sessions', DbConstants.tableSessions),
        ('announcements', DbConstants.tableAnnouncements),
        ('lessons', DbConstants.tableLessons),
        ('quizzes', DbConstants.tableQuizzes),
      ];

      // 4. Perform Push
      final db = DatabaseHelper.instance;
      int pushedCount = 0;

      for (final (remoteTable, localTable) in pushableTables) {
        final pending = await db.queryWhere(
          localTable,
          where: "sync_status != ?",
          whereArgs: ['synced'],
        );

        if (pending.isNotEmpty) {
          final List<Map<String, dynamic>> toPush = pending.map((record) {
            final map = Map<String, dynamic>.from(record);
            map.remove('sync_status');
            return map;
          }).toList();

          await syncService.pushDocuments(remoteTable, toPush);

          for (final record in pending) {
            final id = record['id'] as String?;
            if (id == null) continue;
            await db.update(localTable, {'sync_status': 'synced'}, id);
            pushedCount++;
          }
        }
      }

      print('Background Sync: Successfully pushed $pushedCount records.');
      return Future.value(true);
    } catch (e) {
      print('Background Sync Error: $e');
      return Future.value(false);
    }
  });
}

class BackgroundSyncService {
  static const String syncTaskName = "com.als.study.companion.sync_task";

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    // Register periodic task (every 15 minutes - minimum for Android)
    await Workmanager().registerPeriodicTask(
      "periodic-sync-task",
      syncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }
}
