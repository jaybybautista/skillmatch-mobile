import 'package:flutter/material.dart';

import '../../../../core/api_client.dart';
import '../../../../core/app_theme.dart';
import '../../../../models/resume.dart';
import '../../../../services/resume_service.dart';
import '../../../../widgets/ai_help_button.dart';
import '../../../../widgets/autosave_text_field.dart';

class ProjectsEditScreen extends StatefulWidget {
  const ProjectsEditScreen({super.key, required this.section});

  final ResumeSection section;

  @override
  State<ProjectsEditScreen> createState() => _ProjectsEditScreenState();
}

class _ProjectsEditScreenState extends State<ProjectsEditScreen> {
  final _service = ResumeService();
  late final List<ResumeProjectEntry> _entries = List.of(widget.section.projects);
  final Map<int, GlobalKey<AutosaveTextFieldState>> _descriptionKeys = {};
  final Map<int, String> _titles = {};
  bool _isAdding = false;

  GlobalKey<AutosaveTextFieldState> _descriptionKeyFor(int entryId) =>
      _descriptionKeys.putIfAbsent(entryId, () => GlobalKey<AutosaveTextFieldState>());

  void _showError(Object e) {
    final message = e is ApiException ? e.message : 'Something went wrong. Please try again.';
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addEntry() async {
    setState(() => _isAdding = true);
    try {
      final entry = await _service.addProject(widget.section.id);
      if (mounted) setState(() => _entries.add(entry));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteEntry(ResumeProjectEntry entry) async {
    try {
      await _service.deleteProject(entry.id);
      if (mounted) setState(() => _entries.removeWhere((e) => e.id == entry.id));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _save(ResumeProjectEntry entry, {String? title, String? description}) async {
    try {
      await _service.updateProject(entry.id, title: title, description: description);
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
        title: Text('Projects', style: AppFonts.title(color: Colors.white)),
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
              child: Text('Tap + to add your first project.', style: TextStyle(color: AppColors.textMuted)),
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
                          label: 'Project Title',
                          initialValue: entry.title,
                          hint: 'e.g., Web Development Portfolio',
                          onChanged: (v) {
                            _titles[entry.id] = v;
                            _save(entry, title: v);
                          },
                        ),
                        const SizedBox(height: 12),
                        AutosaveTextField(
                          key: _descriptionKeyFor(entry.id),
                          label: 'Project Description',
                          initialValue: entry.description,
                          maxLines: 4,
                          hint: 'Describe your role, impact, and key features...',
                          onChanged: (v) => _save(entry, description: v),
                          trailing: AiHelpButton(
                            fieldLabel: 'Project Description',
                            getText: () => _descriptionKeyFor(entry.id).currentState?.currentText ?? entry.description ?? '',
                            aiContext: {'project_title': _titles[entry.id] ?? entry.title ?? ''},
                            onAccept: (suggestion) => _descriptionKeyFor(entry.id).currentState?.setText(suggestion),
                          ),
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
