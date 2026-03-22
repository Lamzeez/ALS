import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import 'package:uuid/uuid.dart';
import '../../shared/viewmodels/auth_viewmodel.dart';
import '../viewmodels/session_viewmodel.dart';

class TeacherSessionCreateView extends StatefulWidget {
  const TeacherSessionCreateView({super.key});

  @override
  State<TeacherSessionCreateView> createState() => _TeacherSessionCreateViewState();
}

class _TeacherSessionCreateViewState extends State<TeacherSessionCreateView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int _durationMinutes = 60;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authVm = context.read<AuthViewModel>();
    final sessionVm = context.read<SessionViewModel>();

    if (authVm.currentUser == null) return;

    final scheduledAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final session = SessionModel(
      id: const Uuid().v4(),
      teacherId: authVm.currentUser!.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      scheduledAt: scheduledAt,
      durationMinutes: _durationMinutes,
      isCompleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await sessionVm.createSession(session);
    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session scheduled successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Session')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Session Title',
                hintText: 'e.g., Filipino Language Workshop',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What will be covered in this session?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Date'),
              subtitle: Text(
                '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: _pickTime,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              value: _durationMinutes,
              decoration: const InputDecoration(
                labelText: 'Duration',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 30, child: Text('30 minutes')),
                DropdownMenuItem(value: 60, child: Text('1 hour')),
                DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                DropdownMenuItem(value: 120, child: Text('2 hours')),
              ],
              onChanged: (val) => setState(() => _durationMinutes = val!),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Schedule Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
