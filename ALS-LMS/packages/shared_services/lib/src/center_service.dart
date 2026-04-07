import 'package:shared_models/shared_models.dart';
import 'supabase_client.dart';

class CenterService {
  Future<List<LearningCenter>> getCenters() async {
    try {
      final rows = await SupabaseConfig.client
          .from('learning_centers')
          .select()
          .order('name');
      return (rows as List)
          .map((r) => LearningCenter.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> createCenter({
    required String name,
    required String region,
    String? province,
    String? physicalAddress,
  }) async {
    await SupabaseConfig.client.from('learning_centers').insert({
      'name': name,
      'region': region,
      if (province != null) 'province': province,
      if (physicalAddress != null) 'physical_address': physicalAddress,
    });
  }

  Future<List<Map<String, dynamic>>> getCenterTeachers(String centerId) async {
    try {
      final rows = await SupabaseConfig.client
          .from('center_teachers')
          .select('*, profiles(*)')
          .eq('center_id', centerId)
          .eq('is_active', true);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> assignTeacher({
    required String centerId,
    required String teacherId,
  }) async {
    await SupabaseConfig.client.from('center_teachers').upsert(
      {
        'center_id': centerId,
        'teacher_id': teacherId,
        'is_active': true,
      },
      onConflict: 'center_id,teacher_id',
    );
  }

  Future<void> removeTeacher({
    required String centerId,
    required String teacherId,
  }) async {
    await SupabaseConfig.client
        .from('center_teachers')
        .update({'is_active': false})
        .eq('center_id', centerId)
        .eq('teacher_id', teacherId);
  }

  Future<List<Profile>> getAvailableTeachers() async {
    try {
      final rows = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('role', 'teacher')
          .eq('is_active', true)
          .order('full_name');
      return (rows as List)
          .map((r) => Profile.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteCenter(String id) async {
    await SupabaseConfig.client
        .from('learning_centers')
        .update({'is_active': false}).eq('id', id);
  }
}
