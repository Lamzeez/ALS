import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import '../viewmodels/center_management_viewmodel.dart';

/// ALS Center management page — list, add, edit, delete centers.
class CenterManagementPage extends StatefulWidget {
  const CenterManagementPage({super.key});

  @override
  State<CenterManagementPage> createState() => _CenterManagementPageState();
}

class _CenterManagementPageState extends State<CenterManagementPage> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CenterManagementViewModel>().loadCenters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CenterManagementViewModel>(
      builder: (context, vm, _) {
        final filtered = vm.centers.where((c) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return c.name.toLowerCase().contains(q) ||
              c.region.toLowerCase().contains(q) ||
              c.address.toLowerCase().contains(q);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('ALS Center Management'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => vm.loadCenters(),
              ),
              FilledButton.icon(
                onPressed: () => _showCenterDialog(context, vm),
                icon: const Icon(Icons.add),
                label: const Text('Add Center'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Stats + search row
                Row(
                  children: [
                    _StatChip(
                      label: 'Total',
                      value: '${vm.totalCenters}',
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Active',
                      value: '${vm.activeCenters}',
                      color: Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Inactive',
                      value: '${vm.totalCenters - vm.activeCenters}',
                      color: Colors.orange,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 300,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search centers...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Error banner
                if (vm.errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vm.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Content
                if (vm.isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  Expanded(
                    child: Card(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_city_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              vm.centers.isEmpty
                                  ? 'No ALS centers registered yet'
                                  : 'No centers match your search',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 18,
                              ),
                            ),
                            if (vm.centers.isEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Click "Add Center" to register the first ALS center.',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Card(
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Region')),
                            DataColumn(label: Text('Address')),
                            DataColumn(label: Text('Contact')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: filtered
                              .map(
                                (center) => DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        center.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(center.region)),
                                    DataCell(
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          center.address,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(center.contactNumber ?? '—'),
                                    ),
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          center.isActive
                                              ? 'Active'
                                              : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: center.isActive
                                                ? Colors.green[800]
                                                : Colors.grey[700],
                                          ),
                                        ),
                                        backgroundColor: center.isActive
                                            ? Colors.green[50]
                                            : Colors.grey[100],
                                        side: BorderSide(
                                          color: center.isActive
                                              ? Colors.green[200]!
                                              : Colors.grey[300]!,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 20,
                                            ),
                                            tooltip: 'Edit',
                                            onPressed: () =>
                                                _showCenterDialog(
                                              context,
                                              vm,
                                              center: center,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                            tooltip: 'Delete',
                                            onPressed: () =>
                                                _confirmDelete(
                                              context,
                                              vm,
                                              center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  Add / Edit dialog
  // ──────────────────────────────────────────────────────────────
  void _showCenterDialog(
    BuildContext context,
    CenterManagementViewModel vm, {
    AlsCenterModel? center,
  }) {
    final isEdit = center != null;
    final nameCtrl = TextEditingController(text: center?.name);
    final regionCtrl = TextEditingController(text: center?.region);
    final addressCtrl = TextEditingController(text: center?.address);
    final contactCtrl = TextEditingController(text: center?.contactNumber);
    bool isActive = center?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Center' : 'Add ALS Center'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Center Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Center name is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: regionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Region *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Region VII',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Region is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Address *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Address is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Active'),
                      subtitle: const Text('Inactive centers are hidden from users'),
                      value: isActive,
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final now = DateTime.now();
                final model = AlsCenterModel(
                  id: center?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  region: regionCtrl.text.trim(),
                  address: addressCtrl.text.trim(),
                  contactNumber: contactCtrl.text.trim().isEmpty
                      ? null
                      : contactCtrl.text.trim(),
                  isActive: isActive,
                  createdAt: center?.createdAt ?? now,
                  updatedAt: now,
                );
                final ok = isEdit
                    ? await vm.updateCenter(model)
                    : await vm.createCenter(model);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit
                            ? 'Center updated successfully'
                            : 'Center created successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  Delete confirmation
  // ──────────────────────────────────────────────────────────────
  void _confirmDelete(
    BuildContext context,
    CenterManagementViewModel vm,
    AlsCenterModel center,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Center'),
        content: Text(
          'Delete "${center.name}"?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await vm.deleteCenter(center.id);
              if (!context.mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Center deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  Supporting widgets
// ──────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

