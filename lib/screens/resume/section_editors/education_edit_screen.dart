import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/resume.dart';
import '../../../services/resume_service.dart';
import '../../../widgets/autosave_text_field.dart';

class EducationEditScreen extends StatefulWidget {
  const EducationEditScreen({super.key, required this.section});

  final ResumeSection section;

  @override
  State<EducationEditScreen> createState() => _EducationEditScreenState();
}

class _EducationEditScreenState extends State<EducationEditScreen> {
  final _service = ResumeService();
  late final List<ResumeEducationEntry> _entries = List.of(widget.section.education);
  bool _isAdding = false;

  void _showError(Object e) {
    final message = e is ApiException ? e.message : 'Something went wrong. Please try again.';
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addEntry() async {
    setState(() => _isAdding = true);
    try {
      final entry = await _service.addEducation(widget.section.id);
      if (mounted) setState(() => _entries.add(entry));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteEntry(ResumeEducationEntry entry) async {
    try {
      await _service.deleteEducation(entry.id);
      if (mounted) setState(() => _entries.removeWhere((e) => e.id == entry.id));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _save(ResumeEducationEntry entry, {String? degree, String? schoolName, String? startDate, String? endDate}) async {
    try {
      await _service.updateEducation(entry.id, degree: degree, schoolName: schoolName, startDate: startDate, endDate: endDate);
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Education', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          _isAdding
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                )
              : IconButton(icon: const Icon(Icons.add), onPressed: _addEntry),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Text('Tap + to add your education background.', style: TextStyle(color: AppColors.textMuted)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final entry in _entries) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      key: ValueKey(entry.id),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () => _deleteEntry(entry),
                            child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                          ),
                        ),
                        AutosaveTextField(
                          label: 'Degree / Major',
                          initialValue: entry.degree,
                          hint: 'e.g., Bachelor of Science in Information Technology',
                          onChanged: (v) => _save(entry, degree: v),
                        ),
                        const SizedBox(height: 12),
                        AutosaveTextField(
                          label: 'School Name',
                          initialValue: entry.schoolName,
                          hint: 'e.g., Pangasinan State University',
                          onChanged: (v) => _save(entry, schoolName: v),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AutosaveTextField(
                                label: 'Start Date',
                                initialValue: entry.startDate,
                                onChanged: (v) => _save(entry, startDate: v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AutosaveTextField(
                                label: 'End Date',
                                initialValue: entry.endDate,
                                onChanged: (v) => _save(entry, endDate: v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}
