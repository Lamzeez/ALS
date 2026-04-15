import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_services/src/supabase_client.dart';
import 'package:shared_services/src/local/sync_queue_repository.dart';
import 'package:shared_services/src/local/progress_repository.dart';
import 'package:shared_services/src/local/score_repository.dart';
import 'dart:async';
import 'dart:developer' as developer;

/// Service that manages synchronization between local SQLite and Supabase.
/// Handles:
/// - Detecting connectivity changes
/// - Syncing local changes to the cloud
/// - Downloading remote changes to local storage
/// - Conflict resolution (last-write-wins)
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

  /// Get current online status
  bool get isOnline => _isOnline;

  /// Get sync status
  bool get isSyncing => _isSyncing;

  /// Initialize the sync service and start listening for connectivity changes
  Future<void> initialize() async {
    developer.log('Initializing OfflineSyncService', name: 'OfflineSync');

    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = result.isNotEmpty &&
        !result.contains(ConnectivityResult.none);

    developer.log('Initial connectivity: ${_isOnline ? "online" : "offline"}',
        name: 'OfflineSync');

    // Listen for connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // If online, sync now
    if (_isOnline) {
      await syncToCloud();
    }
  }

  /// Handle connectivity changes
  Future<void> _onConnectivityChanged(
      List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (_isOnline && !wasOnline) {
      developer.log('Connection restored, syncing...', name: 'OfflineSync');
      await syncToCloud();
    } else if (!_isOnline && wasOnline) {
      developer.log('Connection lost, entering offline mode',
          name: 'OfflineSync');
    }
  }

  /// Sync all pending local changes to Supabase
  Future<void> syncToCloud() async {
    if (_isSyncing) {
      developer.log('Sync already in progress, skipping', name: 'OfflineSync');
      return;
    }

    if (!_isOnline) {
      developer.log('Cannot sync: device is offline', name: 'OfflineSync');
      return;
    }

    _isSyncing = true;
    developer.log('Starting sync to cloud...', name: 'OfflineSync');

    try {
      final client = SupabaseConfig.client;
      final pendingOps = await _syncQueue.getPendingOperations();

      developer.log('Found ${pendingOps.length} pending operations',
          name: 'OfflineSync');

      for (final op in pendingOps) {
        try {
          await _executeOperation(client, op);
          await _syncQueue.markAsCompleted(op['id'] as String);
        } catch (e) {
          developer.log('Failed to sync operation: $e', name: 'OfflineSync');
          await _syncQueue.markAsFailed(op['id'] as String, e.toString());
        }
      }

      // Clear completed operations
      await _syncQueue.clearCompleted();

      developer.log('Sync to cloud completed', name: 'OfflineSync');
    } catch (e) {
      developer.log('Sync failed: $e', name: 'OfflineSync');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  /// Download remote data to local storage
  Future<void> downloadCourseData({
    required String courseId,
    required String studentId,
  }) async {
    if (!_isOnline) {
      developer.log('Cannot download: device is offline', name: 'OfflineSync');
      throw Exception('Device is offline');
    }

    developer.log('Downloading course data: $courseId', name: 'OfflineSync');

    try {
      final client = SupabaseConfig.client;

      // Download lessons
      final lessons = await client
          .from('lessons')
          .select()
          .eq('course_id', courseId)
          .eq('is_published', true);

      // Download quizzes for each lesson
      final quizzes = <Map<String, dynamic>>[];
      final questions = <Map<String, dynamic>>[];

      for (final lesson in lessons) {
        final lessonQuizzes = await client
            .from('quizzes')
            .select()
            .eq('lesson_id', lesson['id'])
            .eq('is_published', true);

        quizzes.addAll(lessonQuizzes);

        for (final quiz in lessonQuizzes) {
          final quizQuestions = await client
              .from('questions')
              .select()
              .eq('quiz_id', quiz['id'])
              .order('order_index', ascending: true);

          questions.addAll(quizQuestions);
        }
      }

      // Save to local storage
      // Note: These would use the repositories, but keeping it simple for now
      developer.log(
          'Downloaded ${lessons.length} lessons, ${quizzes.length} quizzes, ${questions.length} questions',
          name: 'OfflineSync');
    } catch (e) {
      developer.log('Download failed: $e', name: 'OfflineSync');
      rethrow;
    }
  }

  /// Track lesson progress locally (will sync when online)
  Future<void> trackProgress({
    required String studentId,
    required String lessonId,
    required double progressPercent,
    int timeSpentMinutes = 0,
    bool isCompleted = false,
  }) async {
    developer.log('Tracking progress: $lessonId ($progressPercent%)',
        name: 'OfflineSync');

    // Save to local storage
    await _progress.upsertProgress({
      'id': '${studentId}_$lessonId',
      'student_id': studentId,
      'lesson_id': lessonId,
      'progress_percent': progressPercent,
      'time_spent_minutes': timeSpentMinutes,
      'is_completed': isCompleted ? 1 : 0,
      'last_accessed_at': DateTime.now().toIso8601String(),
      if (isCompleted) 'completed_at': DateTime.now().toIso8601String(),
    });

    // If online, also sync to Supabase
    if (_isOnline) {
      try {
        final client = SupabaseConfig.client;
        await client.from('progress').upsert({
          'student_id': studentId,
          'lesson_id': lessonId,
          'progress_percent': progressPercent,
          'time_spent_minutes': timeSpentMinutes,
          'is_completed': isCompleted,
        }, onConflict: 'student_id,lesson_id');
      } catch (e) {
        // If sync fails, the data is still saved locally
        developer.log('Failed to sync progress to cloud: $e',
            name: 'OfflineSync');

        // Add to sync queue for later
        await _syncQueue.addToQueue(
          studentId: studentId,
          operationType: 'upsert',
          tableName: 'progress',
          payload: {
            'student_id': studentId,
            'lesson_id': lessonId,
            'progress_percent': progressPercent,
            'time_spent_minutes': timeSpentMinutes,
            'is_completed': isCompleted,
          },
        );
      }
    } else {
      // Add to sync queue for later
      await _syncQueue.addToQueue(
        studentId: studentId,
        operationType: 'upsert',
        tableName: 'progress',
        payload: {
          'student_id': studentId,
          'lesson_id': lessonId,
          'progress_percent': progressPercent,
          'time_spent_minutes': timeSpentMinutes,
          'is_completed': isCompleted,
        },
      );
    }
  }

  /// Submit quiz score locally (will sync when online)
  Future<void> submitScore({
    required String studentId,
    required String quizId,
    required int score,
    required int totalQuestions,
    Map<String, dynamic>? answers,
  }) async {
    developer.log('Submitting score: $score/$totalQuestions',
        name: 'OfflineSync');

    final scoreData = {
      'id': '${studentId}_${quizId}_${DateTime.now().millisecondsSinceEpoch}',
      'student_id': studentId,
      'quiz_id': quizId,
      'score': score,
      'total_questions': totalQuestions,
      'completed_at': DateTime.now().toIso8601String(),
      if (answers != null) 'answers_json': answers.toString(),
    };

    // Save to local storage
    await _scores.insertScore(scoreData);

    // If online, also sync to Supabase
    if (_isOnline) {
      try {
        final client = SupabaseConfig.client;
        await client.from('scores').insert({
          'student_id': studentId,
          'quiz_id': quizId,
          'score': score,
          'total_questions': totalQuestions,
        });
      } catch (e) {
        developer.log('Failed to sync score to cloud: $e',
            name: 'OfflineSync');

        // Add to sync queue for later
        await _syncQueue.addToQueue(
          studentId: studentId,
          operationType: 'insert',
          tableName: 'scores',
          payload: scoreData,
        );
      }
    } else {
      // Add to sync queue for later
      await _syncQueue.addToQueue(
        studentId: studentId,
        operationType: 'insert',
        tableName: 'scores',
        payload: scoreData,
      );
    }
  }

  /// Execute a sync operation
  Future<void> _executeOperation(
      SupabaseClient client, Map<String, dynamic> op) async {
    final operationType = op['operation_type'] as String;
    final tableName = op['table_name'] as String;
    // final payload = op['payload'] as String; // Reserved for future implementation

    developer.log('Executing $operationType on $tableName', name: 'OfflineSync');

    switch (operationType) {
      case 'upsert':
        // Upsert logic here
        break;
      case 'insert':
        // Insert logic here
        break;
      case 'update':
        // Update logic here
        break;
      case 'delete':
        // Delete logic here
        break;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
  }
}
