import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import 'package:uuid/uuid.dart';
import '../../shared/viewmodels/auth_viewmodel.dart';
import '../viewmodels/announcement_viewmodel.dart';

class TeacherAnnouncementCreateView extends StatefulWidget {
  const TeacherAnnouncementCreateView({super.key});

  @override
  State<TeacherAnnouncementCreateView> createState() => _TeacherAnnouncementCreateViewState();
}

class _TeacherAnnouncementCreateViewState extends State<TeacherAnnouncementCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _targetRole = 'all';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authVm = context.read<AuthViewModel>();
    final announceVm = context.read<AnnouncementViewModel>();

    if (authVm.currentUser == null) return;

    final announcement = AnnouncementModel(
      id: const Uuid().v4(),
      authorId: authVm.currentUser!.id,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      targetRole: _targetRole,
      alsCenterId: authVm.currentUser!.alsCenterId,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await announceVm.createAnnouncement(announcement);
    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement posted successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Announcement')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Upcoming Holiday or Exam Schedule',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Write the announcement message here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 6,
              validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter content' : null,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _targetRole,
              decoration: const InputDecoration(
                labelText: 'Send To',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Learners')),
                DropdownMenuItem(value: 'student', child: Text('Students Only')),
                DropdownMenuItem(value: 'teacher', child: Text('Other Teachers')),
              ],
              onChanged: (val) => setState(() => _targetRole = val!),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Post Announcement'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
