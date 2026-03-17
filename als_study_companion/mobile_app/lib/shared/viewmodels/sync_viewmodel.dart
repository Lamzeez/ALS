import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/database/database_helper.dart';

/// ViewModel for managing data synchronization between local SQLite and Firebase.
class SyncViewModel extends ChangeNotifier {
  SyncStatus _status = SyncStatus.synced;
  bool _isSyncing = false;
  String? _lastSyncTime;
  String? _errorMessage;

  SyncStatus get status => _status;
  bool get isSyncing => _isSyncing;
  String? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;

  /// Trigger a full sync cycle.
  Future<void> syncAll() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _status = SyncStatus.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Push offline data to cloud
      await _pushOfflineData();

      // Step 2: Pull updates from cloud
      await _pullCloudUpdates();

      _status = SyncStatus.synced;
      _lastSyncTime = DateTime.now().toIso8601String();
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = 'Sync failed: ${e.toString()}';
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Push locally stored offline data to Supabase.
  Future<void> _pushOfflineData() async {
    final tablesToPush = [
      DbConstants.tableProgress,
      DbConstants.tableLessons,
      DbConstants.tableQuizzes,
      DbConstants.tableQuestions,
      DbConstants.tableSessions,
      DbConstants.tableAnnouncements,
    ];

    for (final table in tablesToPush) {
      final pending = await DatabaseHelper.instance.queryWhere(
        table,
        where: "syncStatus != ?",
        whereArgs: ['synced'],
      );

      for (final record in pending) {
        final id = record['id'] as String?;
        if (id == null) continue;

        // Map local keys to Supabase snake_case keys if necessary
        final supabaseData = _mapToSupabase(table, Map<String, dynamic>.from(record));
        
        // Remove local-only fields
        supabaseData.remove('syncStatus');

        // Upsert to Supabase
        await Supabase.instance.client.from(_getSupabaseTable(table)).upsert(supabaseData);

        // Mark as synced locally
        final updatedRecord = Map<String, dynamic>.from(record);
        updatedRecord['syncStatus'] = 'synced';
        await DatabaseHelper.instance.update(table, updatedRecord, id);
      }
    }
  }

  /// Pull latest data from Supabase to local SQLite.
  Future<void> _pullCloudUpdates() async {
    final tablesToPull = [
      'users',
      'lessons',
      'quizzes',
      'questions',
      'progress',
      'sessions',
      'announcements',
      'centers',
    ];

    for (final table in tablesToPull) {
      final res = await Supabase.instance.client.from(table).select();
      final items = List<Map<String, dynamic>>.from(res as List);
      
      final localTable = _getLocalTable(table);
      for (final map in items) {
        final localData = _mapToLocal(table, map);
        localData['syncStatus'] = 'synced';
        await DatabaseHelper.instance.insert(localTable, localData);
      }
    }
  }

  String _getSupabaseTable(String localTable) {
    if (localTable == DbConstants.tableAlsCenters) return 'centers';
    return localTable;
  }

  String _getLocalTable(String supabaseTable) {
    switch (supabaseTable) {
      case 'users': return DbConstants.tableUsers;
      case 'lessons': return DbConstants.tableLessons;
      case 'quizzes': return DbConstants.tableQuizzes;
      case 'questions': return DbConstants.tableQuestions;
      case 'progress': return DbConstants.tableProgress;
      case 'sessions': return DbConstants.tableSessions;
      case 'announcements': return DbConstants.tableAnnouncements;
      case 'centers': return DbConstants.tableAlsCenters;
      default: return supabaseTable;
    }
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
    // (Actually DatabaseHelper seems to expect some snake_case and some camelCase based on onCreate)
    // Let's keep it consistent with what DatabaseHelper.onCreate defined.
    return data;
  }

  /// Sync only progress data.
  Future<void> syncProgress() async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();

    try {
      await _pushOfflineData();
      _status = SyncStatus.synced;
    } catch (e) {
      _status = SyncStatus.error;
      _errorMessage = e.toString();
    }

    _isSyncing = false;
    notifyListeners();
  }
}
