import 'package:shared_models/shared_models.dart';
import 'supabase_client.dart';
import 'dart:developer' as developer;

class CenterService {
  /// 🏛️ Get list of all active ALS Learning Centers
  Future<List<LearningCenter>> getCenters() async {
    try {
      final client = SupabaseConfig.safeClient;
      if (client == null) return _getStaticCenters();

      return await SupabaseConfig.withRetry(
        () async {
          final rows = await client
              .from('als_centers')
              .select()
              .eq('is_active', true)
              .order('name');
              
          final centers = (rows as List)
              .map((r) => LearningCenter.fromJson(r as Map<String, dynamic>))
              .toList();

          if (centers.isEmpty) return _getStaticCenters();
          return centers;
        },
        operationName: 'getCenters',
      );
    } catch (e) {
      developer.log('Error fetching centers, using static fallback: $e', name: 'CenterService');
      return _getStaticCenters();
    }
  }

  /// Provides default centers if DB is empty or offline
  List<LearningCenter> _getStaticCenters() {
    return [
      const LearningCenter(
        id: 'ncr-south-001',
        name: 'Manila South ALS Center',
        region: 'NCR',
        physicalAddress: 'Manila City',
      ),
      const LearningCenter(
        id: 'ncr-north-002',
        name: 'Quezon City North ALS Center',
        region: 'NCR',
        physicalAddress: 'Quezon City',
      ),
      const LearningCenter(
        id: 'reg3-cent-001',
        name: 'Bulacan Central ALS Center',
        region: 'Region III',
        physicalAddress: 'Malolos, Bulacan',
      ),
    ];
  }

  Future<void> createCenter({
    required String name,
    required String region,
    String? province,
    String? physicalAddress,
  }) async {
    final client = SupabaseConfig.safeClient;
    if (client == null) return;

    await client.from('als_centers').insert({
      'name': name,
      'region': region,
      if (province != null) 'province': province,
      if (physicalAddress != null) 'physical_address': physicalAddress,
    });
  }

  Future<void> deleteCenter(String id) async {
    final client = SupabaseConfig.safeClient;
    if (client == null) return;

    await client
        .from('als_centers')
        .update({'is_active': false})
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getCenterTeachers(String centerId) async {
    try {
      final client = SupabaseConfig.safeClient;
      if (client == null) return [];

      final rows = await client
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
    final client = SupabaseConfig.safeClient;
    if (client == null) return [];

    final rows = await client
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
    final client = SupabaseConfig.safeClient;
    if (client == null) return;

    await client
        .from('profiles')
        .update({'als_center_id': centerId})
        .eq('id', teacherId);
  }

  Future<void> removeTeacher({
    required String centerId,
    required String teacherId,
  }) async {
    final client = SupabaseConfig.safeClient;
    if (client == null) return;

    await client
        .from('profiles')
        .update({'als_center_id': null})
        .eq('id', teacherId);
  }
}
