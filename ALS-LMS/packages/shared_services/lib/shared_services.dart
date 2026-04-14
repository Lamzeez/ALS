/// Shared services for the ALS-LMS system.
///
/// Provides authentication, Supabase client management,
/// data synchronization, connectivity monitoring,
/// course management, announcements, center management,
/// real-time subscriptions, and system administration controls.
library shared_services;

export 'src/supabase_client.dart';
export 'src/auth_service.dart';
export 'src/connectivity_service.dart';
export 'src/course_service.dart';
export 'src/announcement_service.dart';
export 'src/center_service.dart';
export 'src/system_service.dart';
export 'src/media_service.dart';
export 'src/biometric_service.dart';
export 'src/realtime_service.dart'; // 🔴 NEW: Real-time subscriptions
