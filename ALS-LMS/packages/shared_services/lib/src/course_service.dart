import 'supabase_client.dart';

class CourseService {
  Future<List<Map<String, dynamic>>> getEnrolledCourses() async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return [];
    return await SupabaseConfig.client
        .from('course_enrollments')
        .select('*, courses(*)')
        .eq('student_id', uid)
        .eq('status', 'active');
  }

  Future<void> enrollByPin(String pin) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final courses = await SupabaseConfig.client
        .from('courses')
        .select('id')
        .eq('pin_code', pin)
        .eq('is_published', true);
    if (courses.isEmpty) throw Exception('Invalid PIN. No course found.');
    final courseId = courses.first['id'] as String;
    await SupabaseConfig.client.from('course_enrollments').insert({
      'student_id': uid,
      'course_id': courseId,
      'enrolled_via': 'pin',
      'status': 'active',
    });
  }

  Future<List<Map<String, dynamic>>> getTeacherCourses() async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return [];
    return await SupabaseConfig.client
        .from('courses')
        .select('*')
        .eq('teacher_id', uid)
        .eq('is_published', true);
  }

  Future<List<Map<String, dynamic>>> getCourseStudents(String courseId) async {
    return await SupabaseConfig.client
        .from('course_enrollments')
        .select('*, profiles(*)')
        .eq('course_id', courseId)
        .eq('status', 'active');
  }

  // ── Learning Flow Methods ──

  Future<List<Map<String, dynamic>>> getModules(String courseId) async {
    return await SupabaseConfig.client
        .from('modules')
        .select()
        .eq('course_id', courseId)
        .order('order_index');
  }

  Future<List<Map<String, dynamic>>> getLessons(String moduleId) async {
    return await SupabaseConfig.client
        .from('lessons')
        .select()
        .eq('module_id', moduleId)
        .order('order_index');
  }

  Future<List<Map<String, dynamic>>> getLessonMedia(String lessonId) async {
    return await SupabaseConfig.client
        .from('lesson_media')
        .select()
        .eq('lesson_id', lessonId)
        .order('order_index');
  }

  Future<Map<String, dynamic>?> getQuizForLesson(String lessonId) async {
    final result = await SupabaseConfig.client
        .from('quizzes')
        .select()
        .eq('lesson_id', lessonId)
        .eq('is_published', true)
        .limit(1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getQuizForModule(String moduleId) async {
    final result = await SupabaseConfig.client
        .from('quizzes')
        .select()
        .eq('module_id', moduleId)
        .eq('is_published', true)
        .limit(1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getQuizQuestions(String quizId) async {
    return await SupabaseConfig.client
        .from('quiz_questions')
        .select()
        .eq('quiz_id', quizId)
        .order('order_index');
  }

  Future<void> submitQuizScore({
    required String quizId,
    required double score,
    required double maxScore,
    required int attemptNum,
    required Map<String, dynamic> answers,
    required int timeTakenSecs,
  }) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await SupabaseConfig.client.from('scores').insert({
      'student_id': uid,
      'quiz_id': quizId,
      'score': score,
      'max_score': maxScore,
      'attempt_num': attemptNum,
      'answers_json': answers,
      'time_taken_secs': timeTakenSecs,
    });
  }

  Future<List<Map<String, dynamic>>> getModuleProgress(String courseId) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return [];
    return await SupabaseConfig.client
        .from('module_progress')
        .select('*, modules(title, order_index)')
        .eq('student_id', uid)
        .eq('course_id', courseId);
  }

  Future<void> upsertModuleProgress({
    required String moduleId,
    required String courseId,
    required String status,
    double? masteryScore,
    int? lessonsViewed,
    int? totalLessons,
  }) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
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
  }

  Future<List<Map<String, dynamic>>> getScoresForQuiz(String quizId) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return [];
    return await SupabaseConfig.client
        .from('scores')
        .select()
        .eq('student_id', uid)
        .eq('quiz_id', quizId)
        .order('attempt_num');
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
