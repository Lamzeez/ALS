import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_services/src/supabase_client.dart';
import 'package:shared_services/src/local/sync_queue_repository.dart';
import 'package:shared_services/src/local/progress_repository.dart';
import 'package:shared_services/src/local/score_repository.dart';
import 'dart:async';
import 'dart:developer' as developer;

/// Service that manages synchronization between local SQLite and Supabase.
class OfflineSyncService {
  static OfflineSyncService? _instance;
  static OfflineSyncService get instance =>
      _instance ??= OfflineSyncService._();

  OfflineSyncService._();

  final Connectivity _connectivity = Connectivity();
  final SyncQueueRepository _syncQueue = SyncQueueRepository();
  final ProgressRepository _progress = ProgressRepository();
  final ScoreRepository _scores = ScoreRepository();

  bool _isOnline = true;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  Future<void> initialize() async {
    developer.log('Initializing OfflineSyncService', name: 'OfflineSync');
    final result = await _connectivity.checkConnectivity();
    _isOnline = result.isNotEmpty && !result.contains(ConnectivityResult.none);

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    if (_isOnline) {
      syncToCloud();
    }
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (_isOnline && !wasOnline) {
      developer.log('Connection restored, syncing...', name: 'OfflineSync');
      syncToCloud();
    }
  }

  /// Sync all pending local changes to Supabase
  Future<void> syncToCloud() async {
    if (_isSyncing || !_isOnline) return;
    
    final client = SupabaseConfig.safeClient;
    if (client == null) {
      developer.log('Skipping sync: Supabase not initialized.', name: 'OfflineSync');
      return;
    }

    _isSyncing = true;
    try {
      final pendingOps = await _syncQueue.getPendingOperations();

      if (pendingOps.isEmpty) {
        _isSyncing = false;
        return;
      }

      developer.log('Syncing ${pendingOps.length} operations...', name: 'OfflineSync');

      for (final op in pendingOps) {
        try {
          await _executeOperation(client, op);
          await _syncQueue.markAsCompleted(op['id'].toString());
        } catch (e) {
          developer.log('Operation failed: $e', name: 'OfflineSync');
          await _syncQueue.markAsFailed(op['id'].toString(), e.toString());
        }
      }

      await _syncQueue.clearCompleted();
      developer.log('Sync completed successfully', name: 'OfflineSync');
    } catch (e) {
      developer.log('Sync loop failed: $e', name: 'OfflineSync');
    } finally {
      _isSyncing = false;
    }
  }

  /// The "Core Pipe": Translates local queue items into Supabase commands
  Future<void> _executeOperation(SupabaseClient client, Map<String, dynamic> op) async {
    final String type = op['operation_type'];
    final String table = op['table_name'];
    final dynamic rawPayload = op['payload'];
    
    // Handle payload if it's stored as a JSON string in SQLite
    Map<String, dynamic> payload;
    if (rawPayload is String) {
      payload = jsonDecode(rawPayload);
    } else {
      payload = Map<String, dynamic>.from(rawPayload);
    }

    developer.log('Cloud Sync: $type on $table', name: 'OfflineSync');

    switch (table) {
      case 'progress':
      case 'module_progress':
        // Progress uses student_id and module_id as composite key
        await client.from(table).upsert(payload, onConflict: 'student_id,module_id');
        break;
      case 'scores':
        // Scores are usually single-insert entries
        await client.from(table).insert(payload);
        break;
      default:
        // Generic fallback for other tables
        if (type == 'upsert') {
          await client.from(table).upsert(payload);
        } else if (type == 'insert') {
          await client.from(table).insert(payload);
        }
    }
  }

  /// Manually track progress (Offline-First)
  Future<void> trackModuleProgress({
    required String studentId,
    required String moduleId,
    required String courseId,
    required String status,
    double masteryScore = 0,
  }) async {
    final data = {
      'student_id': studentId,
      'module_id': moduleId,
      'course_id': courseId,
      'status': status,
      'mastery_score': masteryScore,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // 1. Save to Local SQLite immediately
    await _progress.upsertProgress(data);

    // 2. Add to Sync Queue
    await _syncQueue.addToQueue(
      studentId: studentId,
      operationType: 'upsert',
      tableName: 'module_progress',
      payload: data,
    );

    // 3. Trigger background sync if online
    if (_isOnline) syncToCloud();
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
  }
}
