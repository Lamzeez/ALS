import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_core/shared_core.dart';

/// SQLite database helper — singleton for offline-first data storage.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.databaseName);

    return await openDatabase(
      path,
      version: DbConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableUsers} (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        profile_picture_url TEXT,
        als_center_id TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        first_name TEXT,
        last_name TEXT,
        student_id_number TEXT,
        date_of_birth TEXT,
        age INTEGER,
        phone_number TEXT,
        occupation TEXT,
        last_school_attended TEXT,
        last_year_attended TEXT,
        email_verified INTEGER DEFAULT 0,
        teacher_verified INTEGER DEFAULT 0
      )
    ''');

    // Students table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableStudents} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        teacher_id TEXT,
        als_center_id TEXT,
        learner_reference_number TEXT NOT NULL,
        grade_level TEXT NOT NULL,
        enrollment_date TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES ${DbConstants.tableUsers}(id)
      )
    ''');

    // Teachers table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableTeachers} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        als_center_id TEXT,
        employee_id TEXT NOT NULL,
        specialization TEXT NOT NULL,
        assigned_student_ids TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES ${DbConstants.tableUsers}(id)
      )
    ''');

    // Lessons table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableLessons} (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        subject TEXT NOT NULL,
        grade_level TEXT NOT NULL,
        video_url TEXT,
        study_guide_url TEXT,
        thumbnail_url TEXT,
        teacher_id TEXT NOT NULL,
        duration_minutes INTEGER DEFAULT 0,
        order_index INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        is_published INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Quizzes table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableQuizzes} (
        id TEXT PRIMARY KEY,
        lesson_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        time_limit_minutes INTEGER DEFAULT 30,
        passing_score INTEGER DEFAULT 75,
        total_questions INTEGER DEFAULT 0,
        teacher_id TEXT NOT NULL,
        sync_status TEXT DEFAULT 'synced',
        is_published INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES ${DbConstants.tableLessons}(id)
      )
    ''');

    // Questions table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableQuestions} (
        id TEXT PRIMARY KEY,
        quiz_id TEXT NOT NULL,
        question_text TEXT NOT NULL,
        options TEXT NOT NULL,
        correct_option_index INTEGER NOT NULL,
        explanation TEXT,
        order_index INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (quiz_id) REFERENCES ${DbConstants.tableQuizzes}(id)
      )
    ''');

    // Student Progress table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableProgress} (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        quiz_id TEXT,
        progress_percent REAL DEFAULT 0.0,
        quiz_score INTEGER,
        time_spent_minutes INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        last_accessed_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Sessions table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableSessions} (
        id TEXT PRIMARY KEY,
        teacher_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        lesson_id TEXT,
        scheduled_at TEXT NOT NULL,
        duration_minutes INTEGER DEFAULT 60,
        student_ids TEXT,
        is_completed INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Downloads table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableDownloads} (
        id TEXT PRIMARY KEY,
        lesson_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        local_file_path TEXT,
        download_progress REAL DEFAULT 0.0,
        status TEXT DEFAULT 'notDownloaded',
        file_size_bytes INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Announcements table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableAnnouncements} (
        id TEXT PRIMARY KEY,
        author_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        target_role TEXT,
        als_center_id TEXT,
        is_active INTEGER DEFAULT 1,
        sync_status TEXT DEFAULT 'synced',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ALS Centers table
    await db.execute('''
      CREATE TABLE ${DbConstants.tableAlsCenters} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT NOT NULL,
        region TEXT NOT NULL,
        contact_number TEXT,
        head_teacher_id TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final cols = [
        'firstName TEXT',
        'lastName TEXT',
        'studentIdNumber TEXT',
        'dateOfBirth TEXT',
        'age INTEGER',
        'phoneNumber TEXT',
        'occupation TEXT',
        'lastSchoolAttended TEXT',
        'lastYearAttended TEXT',
      ];
      for (final col in cols) {
        await db.execute(
          'ALTER TABLE ${DbConstants.tableUsers} ADD COLUMN $col',
        );
      }
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE ${DbConstants.tableUsers} ADD COLUMN emailVerified INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE ${DbConstants.tableUsers} ADD COLUMN teacherVerified INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      // Migration to snake_case for all columns in users table
      // SQLite doesn't support RENAME COLUMN for older versions easily, 
      // so we handle it by recreating the table or adding columns.
      // Since it's a dev build, we'll try a simpler approach or just wipe and recreate if needed.
      // A robust way is to rename columns one by one if supported (SQLite 3.25.0+)
      try {
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN fullName TO full_name');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN profilePictureUrl TO profile_picture_url');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN alsCenterId TO als_center_id');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN isActive TO is_active');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN createdAt TO created_at');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN updatedAt TO updated_at');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN firstName TO first_name');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN lastName TO last_name');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN studentIdNumber TO student_id_number');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN dateOfBirth TO date_of_birth');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN phoneNumber TO phone_number');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN lastSchoolAttended TO last_school_attended');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN lastYearAttended TO last_year_attended');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN emailVerified TO email_verified');
        await db.execute('ALTER TABLE ${DbConstants.tableUsers} RENAME COLUMN teacherVerified TO teacher_verified');
      } catch (e) {
        // If RENAME COLUMN fails, user might need to reinstall or we can do a more complex migration.
        // For development, we can drop and recreate if it's acceptable.
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
          'ALTER TABLE ${DbConstants.tableAlsCenters} ADD COLUMN contact_number TEXT',
        );
        await db.execute(
          'ALTER TABLE ${DbConstants.tableAlsCenters} ADD COLUMN head_teacher_id TEXT',
        );
      } catch (e) {
        // If they already exist or table doesn't exist, ignore
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE ${DbConstants.tableSessions} ADD COLUMN sync_status TEXT DEFAULT \'synced\'',
        );
        await db.execute(
          'ALTER TABLE ${DbConstants.tableAnnouncements} ADD COLUMN sync_status TEXT DEFAULT \'synced\'',
        );
      } catch (e) {
        // ignore if already exists
      }
    }
  }

  // Generic CRUD operations

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    
    // Convert boolean values to integers (1/0) for SQLite compatibility
    final processedData = Map<String, dynamic>.from(data);
    processedData.forEach((key, value) {
      if (value is bool) {
        processedData[key] = value ? 1 : 0;
      }
    });
    
    return await db.insert(
      table,
      processedData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    return await db.query(table);
  }

  Future<List<Map<String, dynamic>>> queryWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> queryById(String table, String id) async {
    final db = await database;
    final results = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> update(String table, Map<String, dynamic> data, String id) async {
    final db = await database;
    return await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, String id) async {
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAll(String table) async {
    final db = await database;
    return await db.delete(table);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
