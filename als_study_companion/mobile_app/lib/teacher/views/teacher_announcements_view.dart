import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/viewmodels/auth_viewmodel.dart';
import '../viewmodels/announcement_viewmodel.dart';
import 'teacher_announcement_create_view.dart';

/// View for creating and managing announcements.
class TeacherAnnouncementsView extends StatefulWidget {
  const TeacherAnnouncementsView({super.key});

  @override
  State<TeacherAnnouncementsView> createState() => _TeacherAnnouncementsViewState();
}

class _TeacherAnnouncementsViewState extends State<TeacherAnnouncementsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      if (auth.currentUser != null) {
        context
            .read<AnnouncementViewModel>()
            .loadAnnouncements(authorId: auth.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TeacherAnnouncementCreateView(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Consumer<AnnouncementViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.announcements.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No announcements yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create an announcement',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final auth = context.read<AuthViewModel>();
              if (auth.currentUser != null) {
                await vm.loadAnnouncements(authorId: auth.currentUser!.id);
              }
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vm.announcements.length,
              itemBuilder: (context, index) {
                final announcement = vm.announcements[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      announcement.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(announcement.content),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'To: ${announcement.targetRole}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '${announcement.createdAt.year}-${announcement.createdAt.month}-${announcement.createdAt.day}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => vm.deleteAnnouncement(announcement.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
