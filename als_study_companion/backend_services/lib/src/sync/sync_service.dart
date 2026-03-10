import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_core/shared_core.dart';
import '../supabase/supabase_database_service.dart';

/// Central synchronization service for offline-first architecture.
///
/// Handles pushing locally-modified records to Supabase and pulling
/// remote changes down to the local SQLite database.
/// Supports exponential backoff on failure and last-write-wins conflict resolution.
class SyncService {
  final SupabaseDatabaseService _databaseService;
  final Connectivity _connectivity;

  SyncStatus _status = SyncStatus.synced;
  SyncStatus get status => _status;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  int _consecutiveFailures = 0;
  static const int _maxRetries = 5;
  static const Duration _baseDelay = Duration(seconds: 2);

  SyncService({
    required SupabaseDatabaseService databaseService,
    Connectivity? connectivity,
  }) : _databaseService = databaseService,
       _connectivity = connectivity ?? Connectivity();

  /// Check if the device currently has internet connectivity.
  Future<bool> get hasConnectivity async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Calculate exponential backoff delay with jitter.
  Duration _backoffDelay(int attempt) {
    final exponential = _baseDelay * pow(2, attempt).toInt();
    final jitter = Duration(
      milliseconds: Random().nextInt(exponential.inMilliseconds ~/ 2),
    );
    return exponential + jitter;
  }

  /// Perform a full sync cycle with exponential backoff on failure.
  ///
  /// [pushCallback] – called to push locally-modified records to Supabase.
  /// [pullCallback] – called to pull latest records from Supabase to SQLite.
  Future<SyncResult> performSync({
    required Future<int> Function() pushCallback,
    required Future<int> Function() pullCallback,
  }) async {
    if (_status == SyncStatus.syncing) {
      return SyncResult(
        pushed: 0,
        pulled: 0,
        success: false,
        message: 'Sync already in progress',
      );
    }

    if (!await hasConnectivity) {
      _status = SyncStatus.error;
      return SyncResult(
        pushed: 0,
        pulled: 0,
        success: false,
        message: 'No internet connection',
      );
    }

    _status = SyncStatus.syncing;

    try {
      // Phase 1: Push local changes
      final pushed = await pushCallback();

      // Phase 2: Pull remote changes
      final pulled = await pullCallback();

      _status = SyncStatus.synced;
      _lastSyncTime = DateTime.now();
      _consecutiveFailures = 0;

      return SyncResult(
        pushed: pushed,
        pulled: pulled,
        success: true,
        message: 'Sync completed',
      );
    } catch (e) {
      _status = SyncStatus.error;
      _consecutiveFailures++;
      return SyncResult(
        pushed: 0,
        pulled: 0,
        success: false,
        message: 'Sync failed: $e',
      );
    }
  }

  /// Perform sync with automatic retries using exponential backoff.
  Future<SyncResult> performSyncWithRetry({
    required Future<int> Function() pushCallback,
    required Future<int> Function() pullCallback,
    int maxRetries = _maxRetries,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      final result = await performSync(
        pushCallback: pushCallback,
        pullCallback: pullCallback,
      );

      if (result.success) return result;

      if (attempt < maxRetries) {
        final delay = _backoffDelay(attempt);
        await Future.delayed(delay);

        // Recheck connectivity before retrying
        if (!await hasConnectivity) {
          return SyncResult(
            pushed: 0,
            pulled: 0,
            success: false,
            message: 'No internet connection after $attempt retries',
          );
        }
      }
    }

    return SyncResult(
      pushed: 0,
      pulled: 0,
      success: false,
      message: 'Sync failed after $maxRetries retries',
    );
  }

  /// Resolve conflicts using last-write-wins strategy.
  ///
  /// Compares [localRecord] and [remoteRecord] by their `updated_at`
  /// timestamps and returns the newer record.
  Map<String, dynamic> resolveConflict(
    Map<String, dynamic> localRecord,
    Map<String, dynamic> remoteRecord,
  ) {
    final localUpdated = DateTime.tryParse(
      (localRecord['updated_at'] ?? localRecord['updatedAt'] ?? '') as String,
    );
    final remoteUpdated = DateTime.tryParse(
      (remoteRecord['updated_at'] ?? remoteRecord['updatedAt'] ?? '') as String,
    );

    if (localUpdated == null && remoteUpdated == null) return remoteRecord;
    if (localUpdated == null) return remoteRecord;
    if (remoteUpdated == null) return localRecord;

    return localUpdated.isAfter(remoteUpdated) ? localRecord : remoteRecord;
  }

  /// Quick push-only sync for a single collection.
  Future<void> pushDocuments(
    String collection,
    List<Map<String, dynamic>> documents,
  ) async {
    if (!await hasConnectivity) return;

    for (final doc in documents) {
      final docId = doc['id'] as String?;
      if (docId != null) {
        await _databaseService.addDocument(collection, docId, doc);
      }
    }
  }

  /// Pull documents from a Supabase table.
  Future<List<Map<String, dynamic>>> pullDocuments(String collection) async {
    if (!await hasConnectivity) return [];
    return _databaseService.getCollection(collection);
  }

  /// Pull documents with a filter.
  Future<List<Map<String, dynamic>>> pullFilteredDocuments(
    String collection, {
    required String field,
    required dynamic isEqualTo,
  }) async {
    if (!await hasConnectivity) return [];
    return _databaseService.queryCollection(
      collection,
      field: field,
      isEqualTo: isEqualTo,
    );
  }

  /// Get the recommended delay before next sync attempt.
  Duration get nextRetryDelay => _backoffDelay(_consecutiveFailures);

  /// Whether the service is in a healthy state (no consecutive failures).
  bool get isHealthy => _consecutiveFailures == 0;
}

/// Result of a sync operation.
class SyncResult {
  final int pushed;
  final int pulled;
  final bool success;
  final String message;

  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.success,
    required this.message,
  });

  @override
  String toString() =>
      'SyncResult(pushed: $pushed, pulled: $pulled, success: $success, message: $message)';
}
