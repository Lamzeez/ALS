import 'package:flutter/material.dart';
import 'package:backend_services/backend_services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_core/shared_core.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

class SubjectManagementPage extends StatefulWidget {
  final String alsCenterId;
  const SubjectManagementPage({super.key, required this.alsCenterId});

  @override
  State<SubjectManagementPage> createState() => _SubjectManagementPageState();
}

class _SubjectManagementPageState extends State<SubjectManagementPage> {
  final _courseService = CourseService();
  List<CenterSubject> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final subjects = await _courseService.getCenterSubjects(widget.alsCenterId);
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load subjects: $e'), backgroundColor: AlsColors.error),
        );
      }
    }
  }

  void _showAddSubjectDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String selectedGrade = 'Junior High School';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AlsColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.auto_stories_rounded, color: AlsColors.primary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Add Core Academic Subject',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Define a new subject category for your center. Teachers can create courses under this subject.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 32),
                    
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subject Name',
                        hintText: 'e.g. Mathematics',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                      validator: (v) => Validators.validateRequired(v, 'Subject Name'),
                    ),
                    const SizedBox(height: 20),
                    
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subject Code',
                        hintText: 'e.g. MATH',
                        prefixIcon: Icon(Icons.code_rounded),
                      ),
                      validator: (v) => Validators.validateRequired(v, 'Subject Code'),
                    ),
                    const SizedBox(height: 20),
                    
                    DropdownButtonFormField<String>(
                      value: selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level',
                        prefixIcon: Icon(Icons.layers_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Elementary', child: Text('Elementary')),
                        DropdownMenuItem(value: 'Junior High School', child: Text('Junior High School')),
                        DropdownMenuItem(value: 'Senior High School', child: Text('Senior High School')),
                      ],
                      onChanged: (v) => setDialogState(() => selectedGrade = v!),
                    ),
                    const SizedBox(height: 40),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            
                            setDialogState(() => isSaving = true);
                            try {
                              final subject = CenterSubject(
                                id: const Uuid().v4(),
                                alsCenterId: widget.alsCenterId,
                                subjectName: nameCtrl.text.trim(),
                                subjectCode: codeCtrl.text.trim().toUpperCase(),
                                gradeLevel: selectedGrade,
                              );
                              await _courseService.saveCenterSubject(subject);
                              if (context.mounted) {
                                Navigator.pop(context);
                                _loadSubjects();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Subject added successfully!'), backgroundColor: AlsColors.success),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: AlsColors.error),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AlsColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Add Subject', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSubject(CenterSubject subject) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text('This will remove "${subject.subjectName}" from your offered subjects. Existing courses might be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AlsColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final updated = CenterSubject(
          id: subject.id,
          alsCenterId: subject.alsCenterId,
          subjectName: subject.subjectName,
          subjectCode: subject.subjectCode,
          gradeLevel: subject.gradeLevel,
          isActive: false,
        );
        await _courseService.saveCenterSubject(updated);
        _loadSubjects();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AlsColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offered Subjects', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Authorization for specific curriculum areas.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddSubjectDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add New Subject'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AlsColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _isLoading
            ? const Center(child: Padding(
                padding: EdgeInsets.all(64.0),
                child: CircularProgressIndicator(),
              ))
            : _subjects.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.8,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _subjects.length,
                    itemBuilder: (context, index) {
                      final s = _subjects[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AlsColors.divider),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AlsColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  s.subjectCode.substring(0, min(2, s.subjectCode.length)), 
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AlsColors.primary, fontSize: 18)
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(s.gradeLevel ?? 'All Levels', style: TextStyle(fontSize: 12, color: AlsColors.textSecondary)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AlsColors.textHint),
                                onPressed: () => _deleteSubject(s),
                                tooltip: 'Remove Subject',
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(80),
        child: Column(
          children: [
            Icon(Icons.auto_stories_rounded, size: 64, color: AlsColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            const Text(
              'No subjects authorized yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add subjects that your center is authorized to offer to students.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
