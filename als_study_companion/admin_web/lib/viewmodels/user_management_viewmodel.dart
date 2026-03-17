import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ViewModel for managing users (students, teachers, admins).
class UserManagementViewModel extends ChangeNotifier {
  List<UserModel> _users = [];
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  UserRole? _filterRole;
  String _searchQuery = '';

  List<UserModel> get users => _getDisplayUsers();
  List<Map<String, dynamic>> get auditLogs => _auditLogs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  UserRole? get filterRole => _filterRole;
  String get searchQuery => _searchQuery;
  int get totalUsers => _users.length;
  int get totalStudents =>
      _users.where((u) => u.role == UserRole.student).length;
  int get totalTeachers =>
      _users.where((u) => u.role == UserRole.teacher).length;
  int get pendingTeachers => _users
      .where((u) => u.role == UserRole.teacher && !u.teacherVerified)
      .length;

  List<UserModel> _getDisplayUsers() {
    var result = _filterRole != null
        ? _users.where((u) => u.role == _filterRole).toList()
        : List<UserModel>.from(_users);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (u) =>
                u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                (u.studentIdNumber?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return result;
  }

  Future<void> loadUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await Supabase.instance.client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      final items = List<Map<String, dynamic>>.from(res as List);
      _users = items.map((m) => UserModel.fromMap(m)).toList();
    } catch (e) {
      _errorMessage = 'Failed to load users: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void filterByRole(UserRole? role) {
    _filterRole = role;
    notifyListeners();
  }

  Future<bool> toggleUserActive(String userId, bool isActive) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      final index = _users.indexWhere((u) => u.id == userId);
      if (index >= 0) {
        _users[index] = _users[index].copyWith(isActive: isActive);
      }
      await _logAudit(
        'toggle_active',
        userId,
        isActive ? 'Enabled' : 'Disabled',
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Approve a teacher account.
  Future<bool> approveTeacher(String userId) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'teacher_verified': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      final index = _users.indexWhere((u) => u.id == userId);
      if (index >= 0) {
        _users[index] = _users[index].copyWith(teacherVerified: true);
      }
      await _logAudit('approve_teacher', userId, 'Teacher approved');
      _successMessage = 'Teacher approved successfully';
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Revoke teacher approval.
  Future<bool> revokeTeacher(String userId) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'teacher_verified': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      final index = _users.indexWhere((u) => u.id == userId);
      if (index >= 0) {
        _users[index] = _users[index].copyWith(teacherVerified: false);
      }
      await _logAudit('revoke_teacher', userId, 'Teacher approval revoked');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Change user role.
  Future<bool> changeRole(String userId, UserRole newRole) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'role': newRole.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
      final index = _users.indexWhere((u) => u.id == userId);
      if (index >= 0) {
        _users[index] = _users[index].copyWith(role: newRole);
      }
      await _logAudit('change_role', userId, 'Role changed to ${newRole.name}');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Bulk import users from parsed CSV rows.
  Future<int> bulkImportUsers(List<Map<String, String>> rows) async {
    int imported = 0;
    for (final row in rows) {
      try {
        final now = DateTime.now();
        final userMap = {
          'id': row['id'] ?? now.microsecondsSinceEpoch.toString(),
          'email': row['email'],
          'full_name':
              row['full_name'] ?? '${row['first_name']} ${row['last_name']}',
          'role': row['role'] ?? 'student',
          'is_active': true,
          'email_verified': false,
          'teacher_verified': false,
          'first_name': row['first_name'],
          'last_name': row['last_name'],
          'phone_number': row['phone_number'],
          'student_id_number': row['student_id_number'],
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        await Supabase.instance.client.from('users').upsert(userMap);
        imported++;
      } catch (e) {
        debugPrint('Failed to import row: $e');
      }
    }
    await _logAudit('bulk_import', '', '$imported users imported');
    await loadUsers();
    return imported;
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await Supabase.instance.client.from('users').delete().eq('id', userId);
      _users.removeWhere((u) => u.id == userId);
      await _logAudit('delete_user', userId, 'User deleted');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Load audit logs from the audit_logs table (if exists).
  Future<void> loadAuditLogs() async {
    try {
      final res = await Supabase.instance.client
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      _auditLogs = List<Map<String, dynamic>>.from(res as List);
      notifyListeners();
    } catch (_) {
      // Table may not exist yet — ignore
    }
  }

  Future<void> _logAudit(String action, String targetId, String detail) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      await Supabase.instance.client.from('audit_logs').insert({
        'action': action,
        'target_id': targetId,
        'details': detail,
        'admin_id': user.id,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Table may not exist yet or no permission — silent
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
