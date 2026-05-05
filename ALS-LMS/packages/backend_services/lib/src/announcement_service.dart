import 'package:shared_core/shared_core.dart';
import 'supabase_client.dart';

class AnnouncementService {
  /// Returns Announcement models with nested course data for the student dashboard.
  Future<List<Announcement>> getStudentAnnouncements() async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) return [];
        final enrollments = await SupabaseConfig.client
            .from('course_enrollments')
            .select('course_id')
            .eq('student_id', uid)
            .eq('status', 'active');
        if (enrollments.isEmpty) return [];
        final courseIds =
            enrollments.map((e) => e['course_id'] as String).toList();
        final data = await SupabaseConfig.client
            .from('announcements')
            .select('*, courses(*)')
            .inFilter('course_id', courseIds)
            .order('created_at', ascending: false);
        return (data as List).map((e) => Announcement.fromJson(e)).toList();
      },
      operationName: 'getStudentAnnouncements',
    );
  }

  Future<List<Announcement>> getCourseAnnouncements(String courseId) async {
    return SupabaseConfig.withRetry(
      () async {
        final data = await SupabaseConfig.client
            .from('announcements')
            .select()
            .eq('course_id', courseId)
            .order('is_pinned', ascending: false)
            .order('created_at', ascending: false);
        return data.map<Announcement>((e) => Announcement.fromJson(e)).toList();
      },
      operationName: 'getCourseAnnouncements',
    );
  }

  Future<List<AnnouncementComment>> getComments(String announcementId) async {
    return SupabaseConfig.withRetry(
      () async {
        final data = await SupabaseConfig.client
            .from('announcement_comments')
            .select()
            .eq('announcement_id', announcementId)
            .order('created_at');
        return data
            .map<AnnouncementComment>((e) => AnnouncementComment.fromJson(e))
            .toList();
      },
      operationName: 'getComments',
    );
  }

  Future<void> addComment(
      {required String announcementId, required String content}) async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) {
          throw SupabaseApiException(
            'Not authenticated',
            operationName: 'addComment',
            isAuthError: true,
          );
        }
        await SupabaseConfig.client.from('announcement_comments').insert({
          'announcement_id': announcementId,
          'user_id': uid,
          'content': content,
        });
      },
      operationName: 'addComment',
    );
  }

  Future<void> createAnnouncement({
    required String courseId,
    required String title,
    required String content,
    bool isPinned = false,
    bool allowComments = true,
  }) async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) {
          throw SupabaseApiException(
            'Not authenticated',
            operationName: 'createAnnouncement',
            isAuthError: true,
          );
        }
        await SupabaseConfig.client.from('announcements').insert({
          'course_id': courseId,
          'teacher_id': uid,
          'title': title,
          'content': content,
          'is_pinned': isPinned,
          'allow_comments': allowComments,
        });
      },
      operationName: 'createAnnouncement',
    );
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    return SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        if (uid == null) {
          throw SupabaseApiException(
            'Not authenticated',
            operationName: 'deleteAnnouncement',
            isAuthError: true,
          );
        }
        await SupabaseConfig.client
            .from('announcements')
            .delete()
            .eq('id', announcementId);
      },
      operationName: 'deleteAnnouncement',
    );
  }
}

