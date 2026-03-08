import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import '../viewmodels/user_management_viewmodel.dart';

/// User management page for admins — search, filter, approve teachers,
/// toggle active/inactive, change roles, bulk CSV import, audit log.
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<UserManagementViewModel>();
      vm.loadUsers();
      vm.loadAuditLogs();
      vm.addListener(_onVmChanged);
    });
  }

  void _onVmChanged() {
    final vm = context.read<UserManagementViewModel>();
    final error = vm.errorMessage;
    final success = vm.successMessage;
    if (error == null && success == null) return;
    vm.clearMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red[700],
          ),
        );
      } else if (success != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    context.read<UserManagementViewModel>().removeListener(_onVmChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserManagementViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Audit Log'),
          ],
        ),
        actions: [
          if (vm.pendingTeachers > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                avatar: const Icon(Icons.warning_amber, size: 18),
                label: Text('${vm.pendingTeachers} pending'),
                backgroundColor: Colors.orange[100],
              ),
            ),
          FilledButton.icon(
            onPressed: () => _showBulkImportDialog(context),
            icon: const Icon(Icons.upload_file),
            label: const Text('CSV Import'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUsersTab(context, vm), _buildAuditLogTab(vm)],
      ),
    );
  }

  Widget _buildUsersTab(BuildContext context, UserManagementViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Summary cards
          Row(
            children: [
              _StatCard(
                label: 'Total',
                value: vm.totalUsers.toString(),
                icon: Icons.people,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Students',
                value: vm.totalStudents.toString(),
                icon: Icons.school,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Teachers',
                value: vm.totalTeachers.toString(),
                icon: Icons.person,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Pending Approval',
                value: vm.pendingTeachers.toString(),
                icon: Icons.hourglass_top,
                color: vm.pendingTeachers > 0 ? Colors.orange : null,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or ID...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: vm.search,
                ),
              ),
              const SizedBox(width: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'student', label: Text('Students')),
                  ButtonSegment(value: 'teacher', label: Text('Teachers')),
                  ButtonSegment(value: 'admin', label: Text('Admins')),
                ],
                selected: {vm.filterRole?.name ?? 'all'},
                onSelectionChanged: (selected) {
                  final val = selected.first;
                  vm.filterByRole(
                    val == 'all' ? null : UserRole.fromString(val),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Users data table
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.users.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : Card(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Verified')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: vm.users.map((u) => _buildRow(u)).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(UserModel user) {
    return DataRow(
      cells: [
        DataCell(Text(user.fullName)),
        DataCell(Text(user.email)),
        DataCell(
          Chip(
            label: Text(user.role.displayName),
            backgroundColor: _roleColor(user.role),
          ),
        ),
        DataCell(
          Switch(
            value: user.isActive,
            onChanged: (v) => context
                .read<UserManagementViewModel>()
                .toggleUserActive(user.id, v),
          ),
        ),
        DataCell(_buildVerificationBadges(user)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user.role == UserRole.teacher && !user.teacherVerified)
                IconButton(
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  tooltip: 'Approve Teacher',
                  onPressed: () => context
                      .read<UserManagementViewModel>()
                      .approveTeacher(user.id),
                ),
              if (user.role == UserRole.teacher && user.teacherVerified)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.orange),
                  tooltip: 'Revoke Approval',
                  onPressed: () => context
                      .read<UserManagementViewModel>()
                      .revokeTeacher(user.id),
                ),
              PopupMenuButton<String>(
                onSelected: (action) => _handleAction(action, user),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'change_role',
                    child: Text('Change Role'),
                  ),
                  PopupMenuItem(
                    value: user.isActive ? 'disable' : 'enable',
                    child: Text(
                      user.isActive ? 'Disable Account' : 'Enable Account',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete User',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationBadges(UserModel user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: user.emailVerified ? 'Email verified' : 'Email not verified',
          child: Icon(
            user.emailVerified ? Icons.mark_email_read : Icons.email_outlined,
            size: 18,
            color: user.emailVerified ? Colors.green : Colors.grey,
          ),
        ),
        if (user.role == UserRole.teacher) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: user.teacherVerified ? 'Approved' : 'Pending approval',
            child: Icon(
              user.teacherVerified ? Icons.verified_user : Icons.hourglass_top,
              size: 18,
              color: user.teacherVerified ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ],
    );
  }

  void _handleAction(String action, UserModel user) {
    final vm = context.read<UserManagementViewModel>();
    switch (action) {
      case 'change_role':
        _showRoleChangeDialog(user);
        break;
      case 'disable':
        vm.toggleUserActive(user.id, false);
        break;
      case 'enable':
        vm.toggleUserActive(user.id, true);
        break;
      case 'delete':
        _confirmDelete(user);
        break;
    }
  }

  void _showRoleChangeDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRole.values.map((role) {
            return RadioListTile<UserRole>(
              title: Text(role.displayName),
              value: role,
              // ignore: deprecated_member_use
              groupValue: user.role,
              // ignore: deprecated_member_use
              onChanged: (r) {
                if (r != null) {
                  context.read<UserManagementViewModel>().changeRole(
                    user.id,
                    r,
                  );
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmDelete(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<UserManagementViewModel>().deleteUser(user.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBulkImportDialog(BuildContext context) {
    final csvController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Import (CSV)'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste CSV data. Headers: email, first_name, last_name, role, '
                'phone_number, student_id_number',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: csvController,
                maxLines: 10,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      'email,first_name,last_name,role\njohn@email.com,John,Doe,student',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final lines = csvController.text.trim().split('\n');
              if (lines.length < 2) return;
              final headers = lines.first
                  .split(',')
                  .map((h) => h.trim())
                  .toList();
              final rows = <Map<String, String>>[];
              for (int i = 1; i < lines.length; i++) {
                final values = lines[i].split(',');
                if (values.length != headers.length) continue;
                final map = <String, String>{};
                for (int j = 0; j < headers.length; j++) {
                  map[headers[j]] = values[j].trim();
                }
                rows.add(map);
              }
              Navigator.pop(ctx);
              final vm = context.read<UserManagementViewModel>();
              final count = await vm.bulkImportUsers(rows);
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$count users imported')));
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogTab(UserManagementViewModel vm) {
    if (vm.auditLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No audit logs yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: vm.auditLogs.length,
      itemBuilder: (_, i) {
        final log = vm.auditLogs[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text(log['action']?.toString() ?? ''),
            subtitle: Text(log['detail']?.toString() ?? ''),
            trailing: Text(
              log['created_at']?.toString().substring(0, 16) ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Colors.blue[100]!;
      case UserRole.teacher:
        return Colors.green[100]!;
      case UserRole.admin:
        return Colors.purple[100]!;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color ?? Colors.grey[600]),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
