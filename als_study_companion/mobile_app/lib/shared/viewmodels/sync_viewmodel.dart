import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:backend_services/backend_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    ('centers', DbConstants.tableAlsCenters),
    ('students', DbConstants.tableStudents),
    ('teachers', DbConstants.tableTeachers),
  ];

  /// Tables that support pushing local changes (have syncStatus column).
  static const _pushableTables = [
    ('progress', DbConstants.tableProgress),
    ('lessons', DbConstants.tableLessons),
    ('quizzes', DbConstants.tableQuizzes),
    ('questions', DbConstants.tableQuestions),
    ('sessions', DbConstants.tableSessions),
    ('announcements', DbConstants.tableAnnouncements),
  ];

  /// Trigger a full sync cycle using SyncService with retry.
  Future<void> syncAll() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _status = SyncStatus.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
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
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = 'Sync failed: ${e.toString()}';
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
        where: "syncStatus != ?",
        whereArgs: ['synced'],
      );

      if (pending.isNotEmpty) {
        for (final record in pending) {
          final id = record['id'] as String?;
          if (id == null) continue;

          // Map local keys to Supabase snake_case keys
          final supabaseData = _mapToSupabase(localTable, Map<String, dynamic>.from(record));
          
          // Remove local-only fields
          supabaseData.remove('sync_status');

          // Upsert to Supabase
          await Supabase.instance.client.from(remoteTable).upsert(supabaseData);

          // Mark as synced locally
          final updatedRecord = Map<String, dynamic>.from(record);
          updatedRecord['syncStatus'] = 'synced';
          await db.update(localTable, updatedRecord, id);
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
      final res = await Supabase.instance.client.from(remoteTable).select();
      final docs = List<Map<String, dynamic>>.from(res as List);
      
      for (final map in docs) {
        final localData = _mapToLocal(localTable, map);
        localData['syncStatus'] = 'synced';
        await db.insert(localTable, localData);
        count++;
      }
    }

    return count;
  }

  Map<String, dynamic> _mapToSupabase(String table, Map<String, dynamic> data) {
    // Convert camelCase to snake_case for Supabase
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      final snakeKey = key.replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => '_${match.group(1)!.toLowerCase()}',
      );
      result[snakeKey] = value;
    });
    return result;
  }

  Map<String, dynamic> _mapToLocal(String table, Map<String, dynamic> data) {
    // Convert snake_case to camelCase for local DB if necessary
    // Based on DatabaseHelper.onCreate, we use camelCase for most things.
    final result = <String, dynamic>{};
    data.forEach((key, value) {
      final camelKey = key.replaceAllMapped(
        RegExp(r'_([a-z])'),
        (match) => match.group(1)!.toUpperCase(),
      );
      result[camelKey] = value;
    });
    return result;
  }

  /// Sync only progress data.
  Future<void> syncProgress() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
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
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = e.toString();
    }

    _isSyncing = false;
    notifyListeners();
  }
}
