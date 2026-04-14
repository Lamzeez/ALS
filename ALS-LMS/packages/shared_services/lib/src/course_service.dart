import 'dart:developer' as developer;
import 'package:shared_models/shared_models.dart';
import 'supabase_client.dart';

class CourseService {
  /// 🎯 Get courses enrolled by current student with proper type safety
  Future<List<CourseEnrollment>> getEnrolledCourses() async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) {
          throw SupabaseApiException(
            'User not authenticated',
            operationName: 'getEnrolledCourses',
            isAuthError: true,
          );
        }

        final rows = await SupabaseConfig.client
            .from('course_enrollments')
            .select('*, courses(*)')
            .eq('student_id', uid)
            .eq('status', 'active');

        return (rows as List)
            .map((r) => CourseEnrollment.fromJson(r as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getEnrolledCourses',
    );
  }

  /// 📌 Enroll student by PIN with proper validation and error handling
  Future<void> enrollByPin(String pin) async {
    await SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) {
          throw SupabaseApiException(
            'User not authenticated',
            operationName: 'enrollByPin',
            isAuthError: true,
          );
        }

        if (pin.trim().isEmpty) {
          throw SupabaseApiException('PIN cannot be empty');
        }

        // Check if course exists and is published
        final courses = await SupabaseConfig.client
            .from('courses')
            .select('id, title')
            .eq('pin_code', pin.trim())
            .eq('is_published', true);

        if (courses.isEmpty) {
          throw SupabaseApiException(
              'Invalid PIN. No published course found with this PIN.');
        }

        final course = courses.first;
        final courseId = course['id'] as String;

        // Check if already enrolled
        final existingEnrollment = await SupabaseConfig.client
            .from('course_enrollments')
            .select('id')
            .eq('student_id', uid)
            .eq('course_id', courseId)
            .maybeSingle();

        if (existingEnrollment != null) {
          throw SupabaseApiException(
              'You are already enrolled in "${course['title']}"');
        }

        // Create enrollment
        await SupabaseConfig.client.from('course_enrollments').insert({
          'student_id': uid,
          'course_id': courseId,
          'enrolled_via': 'pin',
          'status': 'active',
          'enrolled_at': DateTime.now().toIso8601String(),
        });

        developer.log(
            'Student enrolled successfully in course: ${course['title']}',
            name: 'CourseService');
      },
      operationName: 'enrollByPin',
    );
  }

  /// 📚 Get courses created by current teacher
  Future<List<Course>> getTeacherCourses() async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) {
          throw SupabaseApiException(
            'Teacher not authenticated',
            operationName: 'getTeacherCourses',
            isAuthError: true,
          );
        }

        final rows = await SupabaseConfig.client
            .from('courses')
            .select('*')
            .eq('teacher_id', uid)
            .eq('is_published', true)
            .order('created_at', ascending: false);

        return (rows as List)
            .map((r) => Course.fromJson(r as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getTeacherCourses',
    );
  }

  /// 👥 Get students enrolled in a specific course with their profiles
  Future<List<Profile>> getCourseStudents(String courseId) async {
    return SupabaseConfig.withRetry(
      () async {
        if (courseId.trim().isEmpty) {
          throw SupabaseApiException('Course ID cannot be empty');
        }

        final rows = await SupabaseConfig.client
            .from('course_enrollments')
            .select('*, profiles(*)')
            .eq('course_id', courseId)
            .eq('status', 'active')
            .order('enrolled_at', ascending: false);

        return (rows as List)
            .where((r) => r['profiles'] != null)
            .map((r) => Profile.fromJson(r['profiles'] as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getCourseStudents',
    );
  }

  // ── Learning Flow Methods ──

  /// 📋 Get modules for a course with proper validation
  Future<List<Module>> getModules(String courseId) async {
    return SupabaseConfig.withRetry(
      () async {
        if (courseId.trim().isEmpty) {
          throw SupabaseApiException('Course ID cannot be empty');
        }

        final rows = await SupabaseConfig.client
            .from('modules')
            .select('*')
            .eq('course_id', courseId)
            .order('order_index');

        return (rows as List)
            .map((r) => Module.fromJson(r as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getModules',
    );
  }

  /// 📝 Get lessons for a module
  Future<List<Lesson>> getLessons(String moduleId) async {
    return SupabaseConfig.withRetry(
      () async {
        if (moduleId.trim().isEmpty) {
          throw SupabaseApiException('Module ID cannot be empty');
        }

        final rows = await SupabaseConfig.client
            .from('lessons')
            .select('*')
            .eq('module_id', moduleId)
            .order('order_index');

        return (rows as List)
            .map((r) => Lesson.fromJson(r as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getLessons',
    );
  }

  /// 🎥 Get media files for a lesson
  Future<List<LessonMedia>> getLessonMedia(String lessonId) async {
    return SupabaseConfig.withRetry(
      () async {
        if (lessonId.trim().isEmpty) {
          throw SupabaseApiException('Lesson ID cannot be empty');
        }

        final rows = await SupabaseConfig.client
            .from('lesson_media')
            .select('*')
            .eq('lesson_id', lessonId)
            .order('order_index');

        return (rows as List)
            .map((r) => LessonMedia.fromJson(r as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getLessonMedia',
    );
  }

  /// ❓ Get quiz for a lesson
  Future<Quiz?> getQuizForLesson(String lessonId) async {
    return SupabaseConfig.withRetry(
      () async {
        if (lessonId.trim().isEmpty) {
          throw SupabaseApiException('Lesson ID cannot be empty');
        }

        final result = await SupabaseConfig.client
            .from('quizzes')
            .select('*')
            .eq('lesson_id', lessonId)
            .eq('is_published', true)
            .maybeSingle();

        return result != null ? Quiz.fromJson(result) : null;
      },
      operationName: 'getQuizForLesson',
    );
  }

  Future<Quiz?> getQuizForModule(String moduleId) async {
    return SupabaseConfig.withRetry(
      () async {
        if (moduleId.trim().isEmpty) {
          throw SupabaseApiException('Module ID cannot be empty');
        }
        final result = await SupabaseConfig.client
            .from('quizzes')
            .select()
            .eq('module_id', moduleId)
            .eq('is_published', true)
            .maybeSingle();

        return result != null ? Quiz.fromJson(result) : null;
      },
      operationName: 'getQuizForModule',
    );
  }

  Future<List<QuizQuestion>> getQuizQuestions(String quizId) async {
    final rows = await SupabaseConfig.client
        .from('quiz_questions')
        .select()
        .eq('quiz_id', quizId)
        .order('order_index');

    return (rows as List)
        .map((r) => QuizQuestion.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitQuizScore({
    required String quizId,
    required double score,
    required double maxScore,
    required int attemptNum,
    required Map<String, dynamic> answers,
    required int timeTakenSecs,
  }) async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) {
          throw SupabaseApiException(
            'Not authenticated',
            operationName: 'submitQuizScore',
            isAuthError: true,
          );
        }
        await SupabaseConfig.client.from('scores').insert({
          'student_id': uid,
          'quiz_id': quizId,
          'score': score,
          'max_score': maxScore,
          'attempt_num': attemptNum,
          'answers_json': answers,
          'time_taken_secs': timeTakenSecs,
        });
      },
      operationName: 'submitQuizScore',
    );
  }

  Future<List<ModuleProgress>> getModuleProgress(String courseId) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await SupabaseConfig.client
        .from('module_progress')
        .select('*, modules(title, order_index)')
        .eq('student_id', uid)
        .eq('course_id', courseId);

    return (rows as List)
        .map((r) => ModuleProgress.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertModuleProgress({
    required String moduleId,
    required String courseId,
    required String status,
    double? masteryScore,
    int? lessonsViewed,
    int? totalLessons,
  }) async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) {
          throw SupabaseApiException(
            'Not authenticated',
            operationName: 'upsertModuleProgress',
            isAuthError: true,
          );
        }
        final data = <String, dynamic>{
          'student_id': uid,
          'module_id': moduleId,
          'course_id': courseId,
          'status': status,
        };
        if (masteryScore != null) data['mastery_score'] = masteryScore;
        if (lessonsViewed != null) data['lessons_viewed'] = lessonsViewed;
        if (totalLessons != null) data['total_lessons'] = totalLessons;
        if (status == 'in_progress' || status == 'available') {
          data['started_at'] = DateTime.now().toIso8601String();
        }
        if (status == 'completed' || status == 'mastered') {
          data['completed_at'] = DateTime.now().toIso8601String();
        }
        await SupabaseConfig.client
            .from('module_progress')
            .upsert(data, onConflict: 'student_id,module_id');
      },
      operationName: 'upsertModuleProgress',
    );
  }

  Future<List<Score>> getScoresForQuiz(String quizId) async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) return [];
        final rows = await SupabaseConfig.client
            .from('scores')
            .select()
            .eq('student_id', uid)
            .eq('quiz_id', quizId)
            .order('attempt_num');

        return (rows as List)
            .map((r) => Score.fromJson(r as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getScoresForQuiz',
    );
  }

  // ── Admin/Teacher Course Management ──

  Future<Map<String, dynamic>> createCourse({
    required String title,
    required String description,
    required String strand,
    required String teacherId,
    String? pinCode,
  }) async {
    final result = await SupabaseConfig.client
        .from('courses')
        .insert({
          'title': title,
          'description': description,
          'strand': strand,
          'teacher_id': teacherId,
          'pin_code': pinCode,
          'is_published': true,
        })
        .select()
        .single();
    return result;
  }

  Future<Map<String, dynamic>> createModule({
    required String courseId,
    required String title,
    String? description,
    required int orderIndex,
  }) async {
    final result = await SupabaseConfig.client
        .from('modules')
        .insert({
          'course_id': courseId,
          'title': title,
          'description': description,
          'order_index': orderIndex,
          'is_published': true,
        })
        .select()
        .single();
    return result;
  }

  Future<Map<String, dynamic>> createLesson({
    required String moduleId,
    required String title,
    String? contentJson,
    String? contentType,
    required int orderIndex,
  }) async {
    final result = await SupabaseConfig.client
        .from('lessons')
        .insert({
          'module_id': moduleId,
          'title': title,
          'content_json': contentJson != null ? {'text': contentJson} : null,
          'content_type': contentType ?? 'text',
          'order_index': orderIndex,
          'is_published': true,
        })
        .select()
        .single();
    return result;
  }
}
