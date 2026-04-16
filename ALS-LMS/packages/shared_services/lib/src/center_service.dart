import 'package:shared_models/shared_models.dart';
import 'supabase_client.dart';

class CenterService {
  /// 🏛️ Get list of all active ALS Learning Centers
  Future<List<LearningCenter>> getCenters() async {
    return SupabaseConfig.withRetry(
      () async {
        final rows = await SupabaseConfig.client
            .from('learning_centers')
            .select()
            .eq('is_active', true)
            .order('name');
            
        return (rows as List)
            .map((r) => LearningCenter.fromJson(r as Map<String, dynamic>))
            .toList();
      },
      operationName: 'getCenters',
    );
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

  Future<void> deleteCenter(String id) async {
    await SupabaseConfig.client
        .from('learning_centers')
        .update({'is_active': false})
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getCenterTeachers(String centerId) async {
    try {
      final rows = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('als_center_id', centerId)
          .eq('role', 'teacher');
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Profile>> getAvailableTeachers() async {
    final rows = await SupabaseConfig.client
        .from('profiles')
        .select()
        .eq('role', 'teacher')
        .eq('is_active', true);
    return (rows as List).map((r) => Profile.fromJson(r)).toList();
  }

  Future<void> assignTeacher({
    required String centerId,
    required String teacherId,
  }) async {
    await SupabaseConfig.client
        .from('profiles')
        .update({'als_center_id': centerId})
        .eq('id', teacherId);
  }

  Future<void> removeTeacher({
    required String centerId,
    required String teacherId,
  }) async {
    await SupabaseConfig.client
        .from('profiles')
        .update({'als_center_id': null})
        .eq('id', teacherId);
  }
}
