import 'package:shared_core/shared_core.dart';
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
        address: 'Manila City',
      ),
      const LearningCenter(
        id: 'ncr-north-002',
        name: 'Quezon City North ALS Center',
        region: 'NCR',
        address: 'Quezon City',
      ),
      const LearningCenter(
        id: 'reg3-cent-001',
        name: 'Bulacan Central ALS Center',
        region: 'Region III',
        address: 'Malolos, Bulacan',
      ),
    ];
  }

  Future<void> createCenter({
    required String name,
    required String region,
    String? province,
    String? address,
  }) async {
    final client = SupabaseConfig.safeClient;
    if (client == null) return;

    await client.from('als_centers').insert({
      'name': name,
      'region': region,
      if (province != null) 'province': province,
      if (address != null) 'address': address,
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

  /// 🏛️ Fetch a single center by ID
  Future<LearningCenter?> getCenter(String centerId) async {
    return SupabaseConfig.withRetry(
      () async {
        final row = await SupabaseConfig.client
            .from('als_centers')
            .select()
            .eq('id', centerId)
            .maybeSingle();
        if (row == null) return null;
        return LearningCenter.fromJson(row);
      },
      operationName: 'getCenter',
    );
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

  /// 📝 Get center registrations by status
  Future<List<AlsCenterRegistration>> getCenterRegistrations({String? status}) async {
    return SupabaseConfig.withRetry(
      () async {
        var query = SupabaseConfig.client.from('als_center_registrations').select('*');
        if (status != null) {
          query = query.eq('status', status);
        }
        final rows = await query.order('created_at', ascending: false);
        return (rows as List).map((r) => AlsCenterRegistration.fromJson(r)).toList();
      },
      operationName: 'getCenterRegistrations',
    );
  }

  /// ✅ Approve center registration (Calls Edge Function)
  Future<void> approveCenter(String registrationId) async {
    await SupabaseConfig.withRetry(
      () async {
        final client = SupabaseConfig.client;
        
        // Call the Edge Function
        final response = await client.functions.invoke(
          'approve-center',
          body: {'registration_id': registrationId},
        );

        if (response.status != 200) {
          throw Exception(response.data['error'] ?? 'Edge Function failed');
        }
      },
      operationName: 'approveCenter',
    );
  }

  /// ❌ Reject center registration
  Future<void> rejectCenter(String registrationId, String reason) async {
    await SupabaseConfig.withRetry(
      () async {
        final uid = SupabaseConfig.client.auth.currentUser?.id;
        await SupabaseConfig.client
            .from('als_center_registrations')
            .update({
              'status': CenterRegistrationStatus.rejected.toJson(),
              'rejection_reason': reason,
              'reviewed_by': uid,
              'reviewed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', registrationId);
      },
      operationName: 'rejectCenter',
    );
  }
}

