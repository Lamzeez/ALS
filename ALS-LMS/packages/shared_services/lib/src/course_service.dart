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
}
