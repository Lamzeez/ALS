import 'dart:developer' as developer;
import 'package:shared_core/shared_core.dart';
import 'supabase_client.dart';

class SystemService {
  /// Checks if the system kill switch is activated.
  ///
  /// ⚠️ CRITICAL: In case of error, defaults to LOCKED (fail-safe)
  /// This prevents the app from bypassing security checks during network/DB issues.
  Future<bool> isSystemLocked() async {
    try {
      final data = await SupabaseConfig.client
          .from('system_settings')
          .select('value')
          .eq('key', 'kill_switch')
          .maybeSingle();

      if (data == null) {
        developer.log('Kill switch setting not found in database',
            name: 'SystemService', level: 900);
        return false; // Default: system not locked if setting doesn't exist
      }

      final value = data['value'];
      if (value is! Map<String, dynamic>) {
        developer.log('Invalid kill switch value format: $value',
            name: 'SystemService', level: 900);
        return true; // Fail-safe: lock system if invalid format
      }

      return value['active'] == true;
    } catch (e, stackTrace) {
      // 🔥 CRITICAL: Fail-safe - lock system on any error to prevent security bypass
      developer.log(
          'Kill switch check failed - defaulting to LOCKED for security',
          error: e,
          stackTrace: stackTrace,
          name: 'SystemService',
          level: 1000);
      return true; // Fail-safe: assume system is locked
    }
  }

  Future<String> getSystemMessage() async {
    try {
      final data = await SupabaseConfig.client
          .from('system_settings')
          .select('value')
          .eq('key', 'maintenance_mode')
          .maybeSingle();

      if (data == null) {
        developer.log('Maintenance mode setting not found',
            name: 'SystemService');
        return '';
      }

      final value = data['value'];
      if (value is! Map<String, dynamic>) {
        developer.log('Invalid maintenance mode format: $value',
            name: 'SystemService', level: 900);
        return 'System maintenance in progress. Please try again later.';
      }

      return value['message'] as String? ?? '';
    } catch (e, stackTrace) {
      developer.log('Failed to get system message',
          error: e, stackTrace: stackTrace, name: 'SystemService', level: 900);
      return 'Unable to load system status. Please check your connection.';
    }
  }

  Future<List<SystemSetting>> getSettings() async {
    try {
      final rows = await SupabaseConfig.client.from('system_settings').select();
      return (rows as List)
          .map((r) => SystemSetting.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      developer.log('Failed to load system settings',
          error: e, stackTrace: stackTrace, name: 'SystemService', level: 900);
      throw Exception('Unable to load system settings: ${e.toString()}');
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
    } catch (e, stackTrace) {
      developer.log('Failed to load activity logs',
          error: e, stackTrace: stackTrace, name: 'SystemService', level: 900);
      throw Exception('Unable to load activity logs: ${e.toString()}');
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
    } catch (e, stackTrace) {
      developer.log(
        'get_global_analytics RPC failed — function may not exist in database',
        error: e,
        stackTrace: stackTrace,
        name: 'SystemService',
        level: 900,
      );
      return {'_error': true};
    }
  }
}

