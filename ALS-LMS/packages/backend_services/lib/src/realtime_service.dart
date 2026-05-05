import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_core/shared_core.dart';
import 'supabase_client.dart';

/// Real-time subscription manager for live data updates.
/// Manages WebSocket connections to Supabase Realtime for announcements,
/// course updates, grades, and other live data synchronization.
class RealtimeService {
  static RealtimeService? _instance;
  static RealtimeService get instance => _instance ??= RealtimeService._();

  RealtimeService._();

  // Channel subscriptions
  RealtimeChannel? _announcementsChannel;
  RealtimeChannel? _gradesChannel;
  RealtimeChannel? _courseUpdatesChannel;
  RealtimeChannel? _attendanceChannel;

  // Stream controllers for broadcasting updates
  StreamController<AnnouncementUpdate> _announcementController =
      StreamController<AnnouncementUpdate>.broadcast();
  StreamController<GradeUpdate> _gradeController =
      StreamController<GradeUpdate>.broadcast();
  StreamController<CourseUpdate> _courseUpdateController =
      StreamController<CourseUpdate>.broadcast();
  StreamController<AttendanceUpdate> _attendanceController =
      StreamController<AttendanceUpdate>.broadcast();

  // Enrolled course IDs for realtime filtering (H-2)
  Set<String> _enrolledCourseIds = {};

  // Connection state
  bool _isInitialized = false;
  String? _currentUserId;

  // Public streams for UI to listen to
  Stream<AnnouncementUpdate> get onAnnouncementUpdate =>
      _announcementController.stream;
  Stream<GradeUpdate> get onGradeUpdate => _gradeController.stream;
  Stream<CourseUpdate> get onCourseUpdate => _courseUpdateController.stream;
  Stream<AttendanceUpdate> get onAttendanceUpdate =>
      _attendanceController.stream;

  /// Initialize real-time subscriptions for the current user.
  Future<void> initialize({required String userId}) async {
    if (_isInitialized && _currentUserId == userId) {
      developer.log('Realtime already initialized for user: $userId',
          name: 'RealtimeService');
      return;
    }

    try {
      await dispose();

      // Recreate controllers if they were closed by a previous dispose() (M-4)
      if (_announcementController.isClosed) {
        _announcementController =
            StreamController<AnnouncementUpdate>.broadcast();
      }
      if (_gradeController.isClosed) {
        _gradeController = StreamController<GradeUpdate>.broadcast();
      }
      if (_courseUpdateController.isClosed) {
        _courseUpdateController = StreamController<CourseUpdate>.broadcast();
      }
      if (_attendanceController.isClosed) {
        _attendanceController = StreamController<AttendanceUpdate>.broadcast();
      }

      _currentUserId = userId;
      developer.log('Initializing realtime subscriptions for user: $userId',
          name: 'RealtimeService');

      // Load enrolled course IDs before subscribing (H-2)
      await _loadEnrolledCourses(userId);

      await _initializeAnnouncementSubscription(userId);
      await _initializeGradeSubscription(userId);
      await _initializeCourseUpdateSubscription(userId);
      await _initializeAttendanceSubscription(userId);

      _isInitialized = true;
      developer.log('All realtime subscriptions initialized successfully',
          name: 'RealtimeService');
    } catch (e, stackTrace) {
      developer.log('Failed to initialize realtime subscriptions',
          error: e,
          stackTrace: stackTrace,
          name: 'RealtimeService',
          level: 1000);
      rethrow;
    }
  }

  /// Load the set of course IDs the user is enrolled in for realtime filtering.
  Future<void> _loadEnrolledCourses(String userId) async {
    try {
      final rows = await SupabaseConfig.client
          .from('course_enrollments')
          .select('course_id')
          .eq('student_id', userId)
          .eq('status', 'active');
      _enrolledCourseIds = {for (final r in rows) r['course_id'] as String};
      developer.log(
          'Loaded ${_enrolledCourseIds.length} enrolled courses for realtime filter',
          name: 'RealtimeService');
    } catch (e) {
      developer.log('Failed to load enrolled courses for realtime filter',
          error: e, name: 'RealtimeService', level: 800);
      _enrolledCourseIds = {};
    }
  }

  /// Subscribe to announcements.
  Future<void> _initializeAnnouncementSubscription(String userId) async {
    try {
      _announcementsChannel = SupabaseConfig.client
          .channel('announcements_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'announcements',
            callback: (payload) => _handleAnnouncementChange(payload, userId),
          );
      await _announcementsChannel!.subscribe((status, [error]) {
        if (error != null) {
          developer.log('Announcement subscription error: $error',
              name: 'RealtimeService', level: 900);
        } else {
          developer.log('Announcement subscription active: $status',
              name: 'RealtimeService');
        }
      });
    } catch (e) {
      developer.log('Failed to subscribe to announcements',
          error: e, name: 'RealtimeService', level: 900);
      rethrow;
    }
  }

  /// Subscribe to grade/score updates.
  Future<void> _initializeGradeSubscription(String userId) async {
    try {
      _gradesChannel =
          SupabaseConfig.client.channel('grades_$userId').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'scores',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'student_id',
                  value: userId,
                ),
                callback: _handleGradeChange,
              );
      await _gradesChannel!.subscribe((status, [error]) {
        if (error != null) {
          developer.log('Grade subscription error: $error',
              name: 'RealtimeService', level: 900);
        } else {
          developer.log('Grade subscription active: $status',
              name: 'RealtimeService');
        }
      });
    } catch (e) {
      developer.log('Failed to subscribe to grades',
          error: e, name: 'RealtimeService', level: 900);
      rethrow;
    }
  }

  /// Subscribe to course updates (new lessons, modules, etc.).
  Future<void> _initializeCourseUpdateSubscription(String userId) async {
    try {
      _courseUpdatesChannel = SupabaseConfig.client
          .channel('course_updates_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'courses',
            callback: (payload) => _handleCourseChange(payload, userId),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'modules',
            callback: (payload) => _handleModuleChange(payload, userId),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'lessons',
            callback: (payload) => _handleLessonChange(payload, userId),
          );
      await _courseUpdatesChannel!.subscribe((status, [error]) {
        if (error != null) {
          developer.log('Course update subscription error: $error',
              name: 'RealtimeService', level: 900);
        } else {
          developer.log('Course update subscription active: $status',
              name: 'RealtimeService');
        }
      });
    } catch (e) {
      developer.log('Failed to subscribe to course updates',
          error: e, name: 'RealtimeService', level: 900);
      rethrow;
    }
  }

  /// Subscribe to attendance updates.
  Future<void> _initializeAttendanceSubscription(String userId) async {
    try {
      _attendanceChannel =
          SupabaseConfig.client.channel('attendance_$userId').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'attendance_records',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'student_id',
                  value: userId,
                ),
                callback: _handleAttendanceChange,
              );
      await _attendanceChannel!.subscribe((status, [error]) {
        if (error != null) {
          developer.log('Attendance subscription error: $error',
              name: 'RealtimeService', level: 900);
        } else {
          developer.log('Attendance subscription active: $status',
              name: 'RealtimeService');
        }
      });
    } catch (e) {
      developer.log('Failed to subscribe to attendance',
          error: e, name: 'RealtimeService', level: 900);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------

  void _handleAnnouncementChange(PostgresChangePayload payload, String userId) {
    try {
      final eventType = _mapPostgresEvent(payload.eventType);
      final data =
          payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      if (data.isEmpty) return;
      _checkUserEnrollmentAndNotify(data['course_id'] as String?, () {
        final update = AnnouncementUpdate(
          type: eventType,
          announcement: Announcement.fromJson(data),
        );
        _announcementController.add(update);
        developer.log('Announcement update: ${eventType.name}',
            name: 'RealtimeService');
      });
    } catch (e) {
      developer.log('Error processing announcement change',
          error: e, name: 'RealtimeService', level: 900);
    }
  }

  void _handleGradeChange(PostgresChangePayload payload) {
    try {
      final eventType = _mapPostgresEvent(payload.eventType);
      final data =
          payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      if (data.isEmpty) return;
      final update = GradeUpdate(
        type: eventType,
        studentId: data['student_id'] as String,
        lessonId: data['lesson_id'] as String,
        // Use num? cast to safely handle both int and double from the DB (M-1)
        score: (data['score'] as num?)?.toInt(),
        maxScore: (data['max_score'] as num?)?.toInt(),
      );
      _gradeController.add(update);
      developer.log(
          'Grade update: ${eventType.name} - Score: ${update.score}/${update.maxScore}',
          name: 'RealtimeService');
    } catch (e) {
      developer.log('Error processing grade change',
          error: e, name: 'RealtimeService', level: 900);
    }
  }

  void _handleCourseChange(PostgresChangePayload payload, String userId) {
    try {
      final eventType = _mapPostgresEvent(payload.eventType);
      final data =
          payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      if (data.isEmpty) return;
      _checkUserEnrollmentAndNotify(data['id'] as String?, () {
        final update = CourseUpdate(
          type: eventType,
          entityType: CourseEntityType.course,
          courseId: data['id'] as String,
          title: data['title'] as String?,
        );
        _courseUpdateController.add(update);
        developer.log('Course update: ${eventType.name}',
            name: 'RealtimeService');
      });
    } catch (e) {
      developer.log('Error processing course change',
          error: e, name: 'RealtimeService', level: 900);
    }
  }

  void _handleModuleChange(PostgresChangePayload payload, String userId) {
    try {
      final eventType = _mapPostgresEvent(payload.eventType);
      final data =
          payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      if (data.isEmpty) return;
      final update = CourseUpdate(
        type: eventType,
        entityType: CourseEntityType.module,
        moduleId: data['id'] as String?,
        courseId: data['course_id'] as String,
        title: data['title'] as String?,
      );
      _courseUpdateController.add(update);
      developer.log('Module update: ${eventType.name}',
          name: 'RealtimeService');
    } catch (e) {
      developer.log('Error processing module change',
          error: e, name: 'RealtimeService', level: 900);
    }
  }

  void _handleLessonChange(PostgresChangePayload payload, String userId) {
    try {
      final eventType = _mapPostgresEvent(payload.eventType);
      final data =
          payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      if (data.isEmpty) return;
      final update = CourseUpdate(
        type: eventType,
        entityType: CourseEntityType.lesson,
        lessonId: data['id'] as String?,
        moduleId: data['module_id'] as String?,
        title: data['title'] as String?,
      );
      _courseUpdateController.add(update);
      developer.log('Lesson update: ${eventType.name}',
          name: 'RealtimeService');
    } catch (e) {
      developer.log('Error processing lesson change',
          error: e, name: 'RealtimeService', level: 900);
    }
  }

  void _handleAttendanceChange(PostgresChangePayload payload) {
    try {
      final eventType = _mapPostgresEvent(payload.eventType);
      final data =
          payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      if (data.isEmpty) return;
      final update = AttendanceUpdate(
        type: eventType,
        studentId: data['student_id'] as String,
        courseId: data['course_id'] as String,
        date: DateTime.parse(data['date'] as String),
        status: AttendanceStatus.values.firstWhere(
          (s) => s.name == data['status'],
          orElse: () => AttendanceStatus.absent,
        ),
      );
      _attendanceController.add(update);
      developer.log('Attendance update: ${eventType.name}',
          name: 'RealtimeService');
    } catch (e) {
      developer.log('Error processing attendance change',
          error: e, name: 'RealtimeService', level: 900);
    }
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  RealtimeUpdateType _mapPostgresEvent(PostgresChangeEvent event) {
    switch (event.name.toLowerCase()) {
      case 'insert':
        return RealtimeUpdateType.created;
      case 'update':
        return RealtimeUpdateType.updated;
      case 'delete':
        return RealtimeUpdateType.deleted;
      default:
        return RealtimeUpdateType.updated;
    }
  }

  /// Check if user is enrolled in course before notifying about updates (H-2).
  void _checkUserEnrollmentAndNotify(String? courseId, void Function() notify) {
    if (courseId == null || _currentUserId == null) return;
    // Only propagate events for courses this user is enrolled in.
    if (_enrolledCourseIds.contains(courseId)) {
      notify();
    }
  }

  /// Clean up all subscriptions and resources.
  Future<void> dispose() async {
    try {
      developer.log('Disposing realtime subscriptions',
          name: 'RealtimeService');
      await _announcementsChannel?.unsubscribe();
      await _gradesChannel?.unsubscribe();
      await _courseUpdatesChannel?.unsubscribe();
      await _attendanceChannel?.unsubscribe();
      _announcementsChannel = null;
      _gradesChannel = null;
      _courseUpdatesChannel = null;
      _attendanceChannel = null;

      // Close StreamControllers to free listeners (M-4)
      if (!_announcementController.isClosed) {
        await _announcementController.close();
      }
      if (!_gradeController.isClosed) {
        await _gradeController.close();
      }
      if (!_courseUpdateController.isClosed) {
        await _courseUpdateController.close();
      }
      if (!_attendanceController.isClosed) {
        await _attendanceController.close();
      }

      _enrolledCourseIds = {};
      _isInitialized = false;
      _currentUserId = null;
      developer.log('All realtime subscriptions disposed',
          name: 'RealtimeService');
    } catch (e) {
      developer.log('Error disposing realtime subscriptions',
          error: e, name: 'RealtimeService', level: 900);
    }
  }

  bool get isConnected => _isInitialized;
  String? get currentUserId => _currentUserId;
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

enum RealtimeUpdateType { created, updated, deleted }

enum CourseEntityType { course, module, lesson }

enum AttendanceStatus { present, absent, late, excused }

class AnnouncementUpdate {
  final RealtimeUpdateType type;
  final Announcement announcement;

  const AnnouncementUpdate({required this.type, required this.announcement});
}

class GradeUpdate {
  final RealtimeUpdateType type;
  final String studentId;
  final String lessonId;
  final int? score;
  final int? maxScore;

  const GradeUpdate({
    required this.type,
    required this.studentId,
    required this.lessonId,
    this.score,
    this.maxScore,
  });
}

class CourseUpdate {
  final RealtimeUpdateType type;
  final CourseEntityType entityType;
  final String? courseId;
  final String? moduleId;
  final String? lessonId;
  final String? title;

  const CourseUpdate({
    required this.type,
    required this.entityType,
    this.courseId,
    this.moduleId,
    this.lessonId,
    this.title,
  });
}

class AttendanceUpdate {
  final RealtimeUpdateType type;
  final String studentId;
  final String courseId;
  final DateTime date;
  final AttendanceStatus status;

  const AttendanceUpdate({
    required this.type,
    required this.studentId,
    required this.courseId,
    required this.date,
    required this.status,
  });
}

