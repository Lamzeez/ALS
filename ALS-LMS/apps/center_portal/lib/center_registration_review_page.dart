import 'package:flutter/material.dart';
import 'package:backend_services/backend_services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_core/shared_core.dart';

class CenterRegistrationReviewPage extends StatefulWidget {
  const CenterRegistrationReviewPage({super.key});

  @override
  State<CenterRegistrationReviewPage> createState() => _CenterRegistrationReviewPageState();
}

class _CenterRegistrationReviewPageState extends State<CenterRegistrationReviewPage> {
  final _centerService = CenterService();
  List<AlsCenterRegistration> _registrations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegistrations();
  }

  Future<void> _loadRegistrations() async {
    setState(() => _isLoading = true);
    try {
      final regs = await _centerService.getCenterRegistrations(status: 'pending');
      setState(() {
        _registrations = regs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load registrations: $e')),
        );
      }
    }
  }

  Future<void> _approve(AlsCenterRegistration reg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve ALS Center?'),
        content: Text('This will create the center "${reg.centerName}" and an admin account for ${reg.adminEmail}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _centerService.approveCenter(reg.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Center approved and admin account created.'), backgroundColor: AlsColors.success),
        );
        _loadRegistrations();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e'), backgroundColor: AlsColors.error),
        );
      }
    }
  }

  Future<void> _reject(AlsCenterRegistration reg) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Registration?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason for rejection'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AlsColors.error),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _centerService.rejectCenter(reg.id, reasonController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration rejected.')));
        _loadRegistrations();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e'), backgroundColor: AlsColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pending Center Registrations', style: Theme.of(context).textTheme.titleMedium),
            ElevatedButton.icon(
              onPressed: _loadRegistrations,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _registrations.isEmpty
            ? const Center(child: Padding(
                padding: EdgeInsets.all(64),
                child: Text('No pending registration requests.'),
              ))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _registrations.length,
                itemBuilder: (context, index) {
                  final reg = _registrations[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reg.centerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('${reg.region} • ${reg.address}', style: TextStyle(color: AlsColors.textSecondary, fontSize: 13)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(reg.adminFullName, style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.email, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(reg.adminEmail, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            onPressed: () => _approve(reg),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve'),
                            style: FilledButton.styleFrom(backgroundColor: AlsColors.success),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _reject(reg),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(foregroundColor: AlsColors.error, side: BorderSide(color: AlsColors.error)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }
}
