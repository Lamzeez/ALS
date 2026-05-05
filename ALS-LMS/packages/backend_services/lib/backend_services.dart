/// Shared services for the ALS-LMS system.
///
/// Provides authentication, Supabase client management,
/// data synchronization, connectivity monitoring,
/// course management, announcements, center management,
/// real-time subscriptions, system administration controls,
/// and offline-first local storage with sync.
library backend_services;

// Supabase & Auth
export 'src/supabase_client.dart';
export 'src/auth_service.dart';

// Connectivity & Realtime
export 'src/connectivity_service.dart';
export 'src/realtime_service.dart';

// Business Logic Services
export 'src/course_service.dart';
export 'src/announcement_service.dart';
export 'src/session_service.dart';
export 'src/downloads_service.dart';
export 'src/center_service.dart';
export 'src/system_service.dart';
export 'src/media_service.dart';
export 'src/biometric_service.dart';

// Offline-First Storage
export 'src/offline_sync_service.dart';
export 'src/local/local_database.dart';
export 'src/local/lesson_repository.dart';
export 'src/local/quiz_repository.dart';
export 'src/local/question_repository.dart';
export 'src/local/progress_repository.dart';
export 'src/local/score_repository.dart';
export 'src/local/sync_queue_repository.dart';
export 'src/local/course_repository.dart';
export 'src/local/course_enrollment_repository.dart';
export 'src/local/center_subject_repository.dart';
export 'src/local/course_timeline_repository.dart';
export 'src/local/certificate_repository.dart';
