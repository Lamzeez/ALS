/// Database table names and configuration constants.
class DbConstants {
  // SQLite & Supabase Table Names
  static const String tableUsers = 'users';
  static const String tableDistricts = 'districts';
  static const String tableCohorts = 'cohorts';
  static const String tableAlsCenters = 'als_centers';
  static const String tableCenterTeachers = 'center_teachers';
  static const String tableCourses = 'courses';
  static const String tableCourseEnrollments = 'course_enrollments';
  static const String tableCenterSubjects = 'center_subjects';
  static const String tableCourseTimeline = 'course_timeline';
  static const String tableModules = 'modules';
  static const String tableLessons = 'lessons';
  static const String tableLessonMedia = 'lesson_media';
  static const String tableQuizzes = 'quizzes';
  static const String tableQuestions = 'questions';
  static const String tableModuleProgress = 'module_progress';
  static const String tableScores = 'scores';
  static const String tableAnnouncements = 'announcements';
  static const String tableAnnouncementComments = 'announcement_comments';
  static const String tableAttendance = 'attendance';
  static const String tableCertificates = 'certificates';
  static const String tableAlsCenterRegistrations = 'als_center_registrations';
  static const String tableSystemSettings = 'system_settings';
  static const String tableSyncQueue = 'sync_queue';
  static const String tableDownloads = 'downloads';

  // Database Configuration
  static const String dbName = 'als_study_companion.db';
  static const int dbVersion = 3;
}

class StorageConstants {
  static const String bucketLessonVideos = 'lesson-videos';
  static const String bucketLessonMaterials = 'lesson-materials';
  static const String bucketProfilePictures = 'profile-pictures';
  static const String bucketQrCodes = 'qr-codes';
}
