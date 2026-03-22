import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/viewmodels/auth_viewmodel.dart';
import '../viewmodels/session_viewmodel.dart';
import 'teacher_session_create_view.dart';

/// View for teachers to schedule and manage learning sessions.
class TeacherSessionsView extends StatefulWidget {
  const TeacherSessionsView({super.key});

  @override
  State<TeacherSessionsView> createState() => _TeacherSessionsViewState();
}

class _TeacherSessionsViewState extends State<TeacherSessionsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthViewModel>();
      if (auth.currentUser != null) {
        context.read<SessionViewModel>().loadSessions(auth.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TeacherSessionCreateView()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Consumer<SessionViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sessions scheduled',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to schedule a session',
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
                await vm.loadSessions(auth.currentUser!.id);
              }
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vm.sessions.length,
              itemBuilder: (context, index) {
                final session = vm.sessions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      session.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(session.description ?? ''),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${session.scheduledAt.year}-${session.scheduledAt.month}-${session.scheduledAt.day} ${session.scheduledAt.hour}:${session.scheduledAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: session.isCompleted
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : IconButton(
                            icon: const Icon(Icons.done_outline),
                            onPressed: () => vm.completeSession(session.id),
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
