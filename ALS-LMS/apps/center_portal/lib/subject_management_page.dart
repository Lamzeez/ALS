import 'package:flutter/material.dart';
import 'package:backend_services/backend_services.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_core/shared_core.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

class SubjectManagementView extends StatefulWidget {
  final String alsCenterId;
  final VoidCallback? onSubjectsChanged;

  const SubjectManagementView({
    super.key,
    required this.alsCenterId,
    this.onSubjectsChanged,
  });

  @override
  State<SubjectManagementView> createState() => _SubjectManagementViewState();
}

class _SubjectManagementViewState extends State<SubjectManagementView> {
  final _courseService = CourseService();
  List<CenterSubject> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubjects(notifyParent: false);
  }

  Future<void> _loadSubjects({bool notifyParent = true}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final subjects = await _courseService.getCenterSubjects(widget.alsCenterId);
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _isLoading = false;
        });
        if (notifyParent) {
          widget.onSubjectsChanged?.call();
        }
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
    showAddSubjectDialog(
      context: context,
      alsCenterId: widget.alsCenterId,
      onSuccess: () => _loadSubjects(notifyParent: true),
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
        _loadSubjects(notifyParent: true);
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offered Subjects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Authorization for specific curriculum areas.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddSubjectDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add New'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AlsColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _isLoading
            ? const Center(child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ))
            : _subjects.isEmpty
                ? _buildEmptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Use a Wrap for better responsiveness or a flexible Grid
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: _subjects.map((s) => _buildSubjectCard(s, constraints.maxWidth)).toList(),
                      );
                    },
                  ),
      ],
    );
  }

  Widget _buildSubjectCard(CenterSubject s, double maxWidth) {
    // Calculate width based on available space, min 250, max 350
    final cardWidth = (maxWidth - 32) / 2 > 280 ? (maxWidth - 32) / 2 : maxWidth;

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AlsColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AlsColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              s.subjectCode.substring(0, min(2, s.subjectCode.length)), 
              style: const TextStyle(fontWeight: FontWeight.bold, color: AlsColors.primary, fontSize: 16)
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(s.gradeLevel ?? 'All Levels', style: TextStyle(fontSize: 11, color: AlsColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AlsColors.textHint),
            onPressed: () => _deleteSubject(s),
            tooltip: 'Remove Subject',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.auto_stories_rounded, size: 48, color: AlsColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No subjects authorized yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add subjects that your center is authorized to offer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

void showAddSubjectDialog({
  required BuildContext context,
  required String alsCenterId,
  required VoidCallback onSuccess,
}) {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final courseService = CourseService();
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
                              alsCenterId: alsCenterId,
                              subjectName: nameCtrl.text.trim(),
                              subjectCode: codeCtrl.text.trim().toUpperCase(),
                              gradeLevel: selectedGrade,
                            );
                            await courseService.saveCenterSubject(subject);
                            if (context.mounted) {
                              Navigator.pop(context);
                              onSuccess();
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
