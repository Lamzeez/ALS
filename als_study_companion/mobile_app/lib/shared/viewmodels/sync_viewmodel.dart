import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:backend_services/backend_services.dart';
import '../../core/database/database_helper.dart';

/// ViewModel for managing data synchronization between local SQLite and Supabase.
class SyncViewModel extends ChangeNotifier {
  final SyncService _syncService;

  SyncStatus _status = SyncStatus.synced;
  bool _isSyncing = false;
  String? _lastSyncTime;
  String? _errorMessage;

  SyncViewModel({required SyncService syncService})
      : _syncService = syncService;

  SyncStatus get status => _status;
  bool get isSyncing => _isSyncing;
  String? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;

  /// All tables to sync.
  static const _syncTables = [
    ('lessons', DbConstants.tableLessons),
    ('quizzes', DbConstants.tableQuizzes),
    ('questions', DbConstants.tableQuestions),
    ('progress', DbConstants.tableProgress),
    ('sessions', DbConstants.tableSessions),
    ('announcements', DbConstants.tableAnnouncements),
    ('als_centers', DbConstants.tableAlsCenters),
    ('students', DbConstants.tableStudents),
    ('teachers', DbConstants.tableTeachers),
  ];

  /// Tables that support pushing local changes (have sync_status column).
  static const _pushableTables = [
    ('progress', DbConstants.tableProgress),
    ('sessions', DbConstants.tableSessions),
    ('announcements', DbConstants.tableAnnouncements),
    ('lessons', DbConstants.tableLessons),
    ('quizzes', DbConstants.tableQuizzes),
  ];

  /// Trigger a full sync cycle using SyncService with retry.
  Future<void> syncAll() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _status = SyncStatus.syncing;
    _errorMessage = null;
    notifyListeners();

    final result = await _syncService.performSyncWithRetry(
      pushCallback: _pushOfflineData,
      pullCallback: _pullCloudUpdates,
    );

    if (result.success) {
      _status = SyncStatus.synced;
      _lastSyncTime = DateTime.now().toIso8601String();
    } else {
      _status = SyncStatus.error;
      _errorMessage = result.message;
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Push locally modified records to Supabase.
  Future<int> _pushOfflineData() async {
    int count = 0;
    final db = DatabaseHelper.instance;

    for (final (remoteTable, localTable) in _pushableTables) {
      final pending = await db.queryWhere(
        localTable,
        where: "sync_status != ?",
        whereArgs: ['synced'],
      );

      if (pending.isNotEmpty) {
        // Prepare data for Supabase (remove sync_status column)
        final List<Map<String, dynamic>> toPush = pending.map((record) {
          final map = Map<String, dynamic>.from(record);
          map.remove('sync_status');
          return map;
        }).toList();

        await _syncService.pushDocuments(remoteTable, toPush);

        for (final record in pending) {
          final id = record['id'] as String?;
          if (id == null) continue;
          
          await db.update(localTable, {'sync_status': 'synced'}, id);
          count++;
        }
      }
    }

    return count;
  }

  /// Pull latest data from Supabase to local SQLite.
  Future<int> _pullCloudUpdates() async {
    int count = 0;
    final db = DatabaseHelper.instance;

    for (final (remoteTable, localTable) in _syncTables) {
      final docs = await _syncService.pullDocuments(remoteTable);
      for (final map in docs) {
        await db.insert(localTable, map);
        count++;
      }
    }

    return count;
  }

  /// Sync only progress data.
  Future<void> syncProgress() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    final result = await _syncService.performSync(
      pushCallback: _pushOfflineData,
      pullCallback: () async => 0,
    );

    if (result.success) {
      _status = SyncStatus.synced;
    } else {
      _status = SyncStatus.error;
      _errorMessage = result.message;
    }

    _isSyncing = false;
    notifyListeners();
  }
}
