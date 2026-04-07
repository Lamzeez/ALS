import 'package:shared_models/shared_models.dart';
import 'supabase_client.dart';

class AnnouncementService {
  /// Returns raw maps with nested `courses(title)` for the dashboard.
  Future<List<Map<String, dynamic>>> getStudentAnnouncements() async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) return [];
    final enrollments = await SupabaseConfig.client
        .from('course_enrollments')
        .select('course_id')
        .eq('student_id', uid)
        .eq('status', 'active');
    if (enrollments.isEmpty) return [];
    final courseIds = enrollments.map((e) => e['course_id'] as String).toList();
    return await SupabaseConfig.client
        .from('announcements')
        .select('*, courses(title)')
        .inFilter('course_id', courseIds)
        .order('created_at', ascending: false);
  }

  Future<List<Announcement>> getCourseAnnouncements(String courseId) async {
    final data = await SupabaseConfig.client
        .from('announcements')
        .select()
        .eq('course_id', courseId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);
    return data.map<Announcement>((e) => Announcement.fromJson(e)).toList();
  }

  Future<List<AnnouncementComment>> getComments(String announcementId) async {
    final data = await SupabaseConfig.client
        .from('announcement_comments')
        .select()
        .eq('announcement_id', announcementId)
        .order('created_at');
    return data
        .map<AnnouncementComment>((e) => AnnouncementComment.fromJson(e))
        .toList();
  }

  Future<void> addComment(
      {required String announcementId, required String content}) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await SupabaseConfig.client.from('announcement_comments').insert({
      'announcement_id': announcementId,
      'user_id': uid,
      'content': content,
    });
  }

  Future<void> createAnnouncement({
    required String courseId,
    required String title,
    required String content,
    bool isPinned = false,
    bool allowComments = true,
  }) async {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await SupabaseConfig.client.from('announcements').insert({
      'course_id': courseId,
      'teacher_id': uid,
      'title': title,
      'content': content,
      'is_pinned': isPinned,
      'allow_comments': allowComments,
    });
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await SupabaseConfig.client
        .from('announcements')
        .delete()
        .eq('id', announcementId);
  }
}
