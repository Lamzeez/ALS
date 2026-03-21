/// SQLite database table and column name constants.
class DbConstants {
  DbConstants._();

  static const String databaseName = 'als_study_companion.db';
  static const int databaseVersion = 6;

  // Table names
  static const String tableUsers = 'users';
  static const String tableStudents = 'students';
  static const String tableTeachers = 'teachers';
  static const String tableLessons = 'lessons';
  static const String tableQuizzes = 'quizzes';
  static const String tableQuestions = 'questions';
  static const String tableProgress = 'student_progress';
  static const String tableSessions = 'sessions';
  static const String tableDownloads = 'downloads';
  static const String tableAnnouncements = 'announcements';
  static const String tableAlsCenters = 'centers';
}
