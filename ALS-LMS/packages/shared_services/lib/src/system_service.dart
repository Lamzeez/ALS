import 'package:shared_models/shared_models.dart';
import 'supabase_client.dart';

class SystemService {
  Future<bool> isSystemLocked() async {
    try {
      final data = await SupabaseConfig.client
          .from('system_settings')
          .select('value')
          .eq('key', 'kill_switch')
          .maybeSingle();
      if (data == null) return false;
      return (data['value'] as Map<String, dynamic>)['active'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<String> getSystemMessage() async {
    try {
      final data = await SupabaseConfig.client
          .from('system_settings')
          .select('value')
          .eq('key', 'maintenance_mode')
          .maybeSingle();
      if (data == null) return '';
      return (data['value'] as Map<String, dynamic>)['message'] as String? ??
          '';
    } catch (_) {
      return '';
    }
  }

  Future<List<SystemSetting>> getSettings() async {
    try {
      final rows = await SupabaseConfig.client.from('system_settings').select();
      return (rows as List)
          .map((r) => SystemSetting.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ActivityLog>> getActivityLogs({int limit = 25}) async {
    try {
      final rows = await SupabaseConfig.client
          .from('activity_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => ActivityLog.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> activateKillSwitch({String? reason}) async {
    await SupabaseConfig.client.from('system_settings').upsert(
      {
        'key': 'kill_switch',
        'value': {
          'active': true,
          'reason': reason ?? '',
          'activated_at': DateTime.now().toIso8601String(),
        },
      },
      onConflict: 'key',
    );
  }

  Future<void> deactivateKillSwitch() async {
    await SupabaseConfig.client.from('system_settings').upsert(
      {
        'key': 'kill_switch',
        'value': {
          'active': false,
          'reason': '',
          'activated_at': null,
          'activated_by': null,
        },
      },
      onConflict: 'key',
    );
  }

  Future<void> enableMaintenance({String? message}) async {
    await SupabaseConfig.client.from('system_settings').upsert(
      {
        'key': 'maintenance_mode',
        'value': {
          'enabled': true,
          'message': message ?? 'System Under Maintenance',
          'updated_at': DateTime.now().toIso8601String(),
        },
      },
      onConflict: 'key',
    );
  }

  Future<void> disableMaintenance() async {
    await SupabaseConfig.client.from('system_settings').upsert(
      {
        'key': 'maintenance_mode',
        'value': {
          'enabled': false,
          'message': 'System Under Maintenance',
          'updated_at': DateTime.now().toIso8601String(),
        },
      },
      onConflict: 'key',
    );
  }

  Future<void> updateUserRole(
      {required String userId, required UserRole newRole}) async {
    await SupabaseConfig.client
        .from('profiles')
        .update({'role': newRole.toJson()}).eq('id', userId);
  }

  Future<void> toggleUserActive(String userId, bool active) async {
    await SupabaseConfig.client
        .from('profiles')
        .update({'is_active': active}).eq('id', userId);
  }

  Future<Map<String, dynamic>> getGlobalAnalytics() async {
    try {
      final result = await SupabaseConfig.client.rpc('get_global_analytics');
      return (result as Map<String, dynamic>?) ?? {};
    } catch (_) {
      return {};
    }
  }
}
