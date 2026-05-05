import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_core/shared_core.dart';

/// Database helper for managing local SQLite storage.
/// Handles creation, migrations, and provides access to the database instance.
class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(DbConstants.dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: DbConstants.dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Basic migration: drop and recreate for development
      // In production, use ALTER TABLE or proper migration scripts
      await _dropAllTables(db);
      await _createDB(db, newVersion);
    }
  }

  Future<void> _dropAllTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableCertificates}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableCourseTimeline}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableCourseEnrollments}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableCourses}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableCenterSubjects}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableLessonMedia}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableScores}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableModuleProgress}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableDownloads}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableQuestions}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableQuizzes}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableLessons}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableModules}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableCenterTeachers}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableAlsCenters}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableCohorts}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableDistricts}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableUsers}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.tableSyncQueue}');
  }

  Future<void> _createDB(Database db, int version) async {
    // Core Tables
    await db.execute(Profile.createTableSQL);
    await db.execute(LearningCenter.createTableSQL);
    await db.execute(CenterSubject.createTableSQL);
    
    // Curriculum
    await db.execute(Course.createTableSQL);
    await db.execute(CourseEnrollment.createTableSQL);
    await db.execute(CourseTimeline.createTableSQL);
    await db.execute(Module.createTableSQL);
    await db.execute(Lesson.createTableSQL);
    
    // Assessments & Progress
    await db.execute(Quiz.createTableSQL);
    await db.execute(QuizQuestion.createTableSQL);
    await db.execute(ModuleProgress.createTableSQL);
    await db.execute(Score.createTableSQL);
    await db.execute(Certificate.createTableSQL);

    // Sync & Utils
    await db.execute('''
      CREATE TABLE ${DbConstants.tableSyncQueue} (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        table_name TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableDownloads} (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        downloaded_at TEXT NOT NULL,
        file_size_bytes INTEGER DEFAULT 0,
        FOREIGN KEY (student_id) REFERENCES users(id),
        FOREIGN KEY (lesson_id) REFERENCES lessons(id)
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX idx_courses_center ON courses(als_center_id)');
    await db.execute('CREATE INDEX idx_lessons_course ON lessons(course_id)');
    await db.execute('CREATE INDEX idx_quizzes_lesson ON quizzes(lesson_id)');
    await db.execute('CREATE INDEX idx_questions_quiz ON questions(quiz_id)');
    await db.execute('CREATE INDEX idx_progress_student ON module_progress(student_id)');
    await db.execute('CREATE INDEX idx_scores_student ON scores(student_id)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  /// Clear all local data (for testing or reset)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('scores');
    await db.delete('progress');
    await db.delete('downloads');
    await db.delete('sync_queue');
    await db.delete('questions');
    await db.delete('quizzes');
    await db.delete('lessons');
  }
}
