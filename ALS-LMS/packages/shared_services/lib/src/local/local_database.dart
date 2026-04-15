import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Database helper for managing local SQLite storage.
/// Handles creation, migrations, and provides access to the database instance.
class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('als_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Lessons table
    await db.execute('''
      CREATE TABLE lessons (
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        content TEXT,
        video_url TEXT,
        study_guide_url TEXT,
        thumbnail_url TEXT,
        duration_minutes INTEGER,
        order_index INTEGER DEFAULT 0,
        is_published INTEGER DEFAULT 0,
        downloaded_at TEXT,
        FOREIGN KEY (course_id) REFERENCES courses(id)
      )
    ''');

    // Quizzes table
    await db.execute('''
      CREATE TABLE quizzes (
        id TEXT PRIMARY KEY,
        lesson_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        time_limit_minutes INTEGER DEFAULT 30,
        passing_score INTEGER DEFAULT 75,
        is_published INTEGER DEFAULT 0,
        downloaded_at TEXT,
        FOREIGN KEY (lesson_id) REFERENCES lessons(id)
      )
    ''');

    // Questions table
    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        question_text TEXT NOT NULL,
        option_a TEXT NOT NULL,
        option_b TEXT NOT NULL,
        option_c TEXT NOT NULL,
        option_d TEXT NOT NULL,
        correct_option TEXT NOT NULL,
        explanation TEXT,
        order_index INTEGER DEFAULT 0,
        FOREIGN KEY (quiz_id) REFERENCES quizzes(id)
      )
    ''');

    // Progress table
    await db.execute('''
      CREATE TABLE progress (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        progress_percent REAL DEFAULT 0.0,
        time_spent_minutes INTEGER DEFAULT 0,
        is_completed INTEGER DEFAULT 0,
        completed_at TEXT,
        last_accessed_at TEXT,
        FOREIGN KEY (student_id) REFERENCES sync_queue(student_id),
        FOREIGN KEY (lesson_id) REFERENCES lessons(id)
      )
    ''');

    // Scores table
    await db.execute('''
      CREATE TABLE scores (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        quiz_id TEXT NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        completed_at TEXT NOT NULL,
        answers_json TEXT,
        FOREIGN KEY (student_id) REFERENCES sync_queue(student_id),
        FOREIGN KEY (quiz_id) REFERENCES quizzes(id)
      )
    ''');

    // Sync queue table (for offline operations)
    await db.execute('''
      CREATE TABLE sync_queue (
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

    // Downloads tracking table
    await db.execute('''
      CREATE TABLE downloads (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        downloaded_at TEXT NOT NULL,
        file_size_bytes INTEGER DEFAULT 0,
        FOREIGN KEY (student_id) REFERENCES sync_queue(student_id),
        FOREIGN KEY (lesson_id) REFERENCES lessons(id)
      )
    ''');

    // Create indexes for performance
    await db.execute(
        'CREATE INDEX idx_lessons_course ON lessons(course_id)');
    await db.execute(
        'CREATE INDEX idx_quizzes_lesson ON quizzes(lesson_id)');
    await db.execute(
        'CREATE INDEX idx_questions_quiz ON questions(quiz_id)');
    await db.execute(
        'CREATE INDEX idx_progress_student ON progress(student_id)');
    await db.execute(
        'CREATE INDEX idx_progress_lesson ON progress(lesson_id)');
    await db.execute(
        'CREATE INDEX idx_scores_student ON scores(student_id)');
    await db.execute(
        'CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
    await db.execute(
        'CREATE INDEX idx_downloads_student ON downloads(student_id)');
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
