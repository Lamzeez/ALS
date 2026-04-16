import 'dart:developer' as developer;
import 'package:shared_models/shared_models.dart';
import 'supabase_client.dart';

class CourseService {
  /// 🎯 Get courses enrolled by current student
  Future<List<CourseEnrollment>> getEnrolledCourses() async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) throw Exception('Not authenticated');

        final rows = await SupabaseConfig.client
            .from('course_enrollments')
            .select('*, courses(*)')
            .eq('student_id', uid)
            .eq('status', 'active');

        return (rows as List).map((r) => CourseEnrollment.fromJson(r)).toList();
      },
      operationName: 'getEnrolledCourses',
    );
  }

  /// 📚 Get courses created by current teacher
  Future<List<Course>> getTeacherCourses() async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) throw Exception('Not authenticated');
        
        final rows = await SupabaseConfig.client
            .from('courses')
            .select('*')
            .eq('teacher_id', uid as Object) // Explicit cast for compiler
            .order('created_at', ascending: false);

        return (rows as List).map((r) => Course.fromJson(r)).toList();
      },
      operationName: 'getTeacherCourses',
    );
  }

  /// 📊 GET ANALYTICS: Summary for teacher
  Future<List<Map<String, dynamic>>> getCourseAnalytics(String courseId) async {
    return SupabaseConfig.withRetry(
      () async {
        final students = await SupabaseConfig.client
            .from('course_enrollments')
            .select('student_id, profiles(full_name, email, profile_picture_url, student_id_number)')
            .eq('course_id', courseId);

        final progress = await SupabaseConfig.client
            .from('module_progress')
            .select('student_id, status, mastery_score')
            .eq('course_id', courseId);

        List<Map<String, dynamic>> analytics = [];
        for (var s in students) {
          final studentId = s['student_id'];
          final profile = s['profiles'] as Map<String, dynamic>;
          final studentProgress = progress.where((p) => p['student_id'] == studentId).toList();
          
          double avgMastery = 0;
          int completed = 0;
          if (studentProgress.isNotEmpty) {
            avgMastery = studentProgress.fold<double>(0, (sum, p) => sum + (p['mastery_score'] ?? 0)) / studentProgress.length;
            completed = studentProgress.where((p) => p['status'] == 'completed' || p['status'] == 'mastered').length;
          }

          analytics.add({
            'profile': Profile.fromJson({...profile, 'id': studentId}),
            'avg_mastery': avgMastery,
            'modules_completed': completed,
            'total_modules': studentProgress.length,
          });
        }
        return analytics;
      },
      operationName: 'getCourseAnalytics',
    );
  }

  Future<List<Module>> getModules(String courseId) async {
    final rows = await SupabaseConfig.client.from('modules').select('*').eq('course_id', courseId).order('order_index');
    return (rows as List).map((r) => Module.fromJson(r)).toList();
  }

  Future<List<Lesson>> getLessons(String moduleId) async {
    final rows = await SupabaseConfig.client.from('lessons').select('*').eq('module_id', moduleId).order('order_index');
    return (rows as List).map((r) => Lesson.fromJson(r)).toList();
  }

  Future<Quiz?> getQuizForLesson(String lessonId) async {
    final result = await SupabaseConfig.client.from('quizzes').select('*').eq('lesson_id', lessonId).maybeSingle();
    return result != null ? Quiz.fromJson(result) : null;
  }

  /// ❓ Quiz logic for QuizScreen
  Future<List<QuizQuestion>> getQuizQuestions(String quizId) async {
    final rows = await SupabaseConfig.client.from('questions').select('*').eq('quiz_id', quizId).order('order_index');
    return (rows as List).map((r) => QuizQuestion.fromJson(r)).toList();
  }

  Future<List<Score>> getScoresForQuiz(String quizId) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    
    final rows = await SupabaseConfig.client
        .from('scores')
        .select('*')
        .eq('quiz_id', quizId)
        .eq('student_id', uid as Object); // Explicit cast
    return (rows as List).map((r) => Score.fromJson(r)).toList();
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
    
    await SupabaseConfig.client.from('module_progress').upsert({
      'student_id': uid,
      'module_id': moduleId,
      'course_id': courseId,
      'status': status,
      if (masteryScore != null) 'mastery_score': masteryScore,
      if (lessonsViewed != null) 'lessons_viewed': lessonsViewed,
      if (totalLessons != null) 'total_lessons': totalLessons,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'student_id,module_id');
  }

  /// 🛠️ Create a new course (Used by Teachers and Admins)
  Future<Course> createCourse({
    required String title,
    required String description,
    required dynamic strand,
    String? teacherId,
    String? pinCode,
  }) async {
    final uid = teacherId ?? SupabaseConfig.client.auth.currentUser?.id;
    final strandValue = strand is AlsStrand ? strand.toJson() : strand.toString();
    
    final result = await SupabaseConfig.client.from('courses').insert({
      'title': title,
      'description': description,
      'strand': strandValue,
      'teacher_id': uid,
      'pin_code': pinCode ?? (DateTime.now().millisecondsSinceEpoch % 1000000).toString().padLeft(6, '0'),
    }).select().single();
    
    return Course.fromJson(result);
  }

  Future<void> createModule({
    required String courseId,
    required String title,
    String? description,
    required int orderIndex,
  }) async {
    await SupabaseConfig.client.from('modules').insert({
      'course_id': courseId,
      'title': title,
      'description': description,
      'order_index': orderIndex,
    });
  }

  Future<void> createLesson({
    required String moduleId,
    required String title,
    String? contentJson,
    required String contentType,
    required int orderIndex,
  }) async {
    await SupabaseConfig.client.from('lessons').insert({
      'module_id': moduleId,
      'title': title,
      'content_json': contentJson != null ? {'text': contentJson} : null,
      'content_type': contentType,
      'order_index': orderIndex,
    });
  }

  Future<List<LessonMedia>> getLessonMedia(String lessonId) async {
    final rows = await SupabaseConfig.client.from('lesson_media').select('*').eq('lesson_id', lessonId);
    return (rows as List).map((r) => LessonMedia.fromJson(r)).toList();
  }

  Future<List<ModuleProgress>> getModuleProgress(String courseId) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return [];
    
    final rows = await SupabaseConfig.client
        .from('module_progress')
        .select('*')
        .eq('student_id', uid as Object) // Explicit cast
        .eq('course_id', courseId);
    return (rows as List).map((r) => ModuleProgress.fromJson(r)).toList();
  }

  Future<void> enrollByPin(String pin) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    final course = await SupabaseConfig.client.from('courses').select('id').eq('pin_code', pin).maybeSingle();
    if (course == null) throw Exception('Course not found');
    await SupabaseConfig.client.from('course_enrollments').upsert({'course_id': course['id'], 'student_id': uid, 'status': 'active'});
  }

  Future<List<Profile>> getCourseStudents(String courseId) async {
    final rows = await SupabaseConfig.client.from('course_enrollments').select('profiles(*)').eq('course_id', courseId);
    return (rows as List).map((r) => Profile.fromJson(r['profiles'])).toList();
  }
}
