import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/resume.dart';
import '../../../services/resume_service.dart';
import '../../../widgets/primary_button.dart';
import 'add_section_screen.dart';
import 'resume_preview_screen.dart';
import 'section_editors/achievements_edit_screen.dart';
import 'section_editors/basic_info_edit_screen.dart';
import 'section_editors/education_edit_screen.dart';
import 'section_editors/experience_edit_screen.dart';
import 'section_editors/projects_edit_screen.dart';
import 'section_editors/skills_edit_screen.dart';
import 'section_editors/text_section_edit_screen.dart';

/// A resume's section list — GET /api/resumes/{id}, mirroring the web's
/// Resume Builder edit page.
class ResumeSectionsScreen extends StatefulWidget {
  const ResumeSectionsScreen({super.key, required this.resumeId});

  final int resumeId;

  @override
  State<ResumeSectionsScreen> createState() => _ResumeSectionsScreenState();
}

class _ResumeSectionsScreenState extends State<ResumeSectionsScreen> {
  final _service = ResumeService();
  late Future<Resume> _future = _service.fetchResume(widget.resumeId);

  Future<void> _refresh() async {
    final future = _service.fetchResume(widget.resumeId);
    setState(() => _future = future);
    await future;
  }

  Future<void> _openSection(ResumeSection section) async {
    Widget screen;
    switch (section.type) {
      case 'basic_info':
        screen = BasicInfoEditScreen(section: section);
      case 'experience':
        screen = ExperienceEditScreen(section: section);
      case 'achievements':
        screen = AchievementsEditScreen(section: section);
      case 'projects':
        screen = ProjectsEditScreen(section: section);
      case 'education':
        screen = EducationEditScreen(section: section);
      case 'skills':
        screen = SkillsEditScreen(section: section);
      default:
        screen = TextSectionEditScreen(section: section);
    }

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }

  Future<void> _addSection() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddSectionScreen(resumeId: widget.resumeId)),
    );
    if (added == true) _refresh();
  }

  void _openPreview() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResumePreviewScreen(resumeId: widget.resumeId)));
  }

  Future<void> _renameResume(String currentTitle) async {
    final controller = TextEditingController(text: currentTitle);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Rename Resume', style: AppFonts.title(fontSize: 18, color: AppColors.primary)),
              const SizedBox(height: 12),
              TextField(controller: controller, autofocus: true),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Save',
                onPressed: () async {
                  final title = controller.text.trim();
                  if (title.isEmpty) return;
                  Navigator.of(sheetContext).pop();
                  try {
                    await _service.renameResume(widget.resumeId, title);
                    _refresh();
                  } on ApiException catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteSection(ResumeSection section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove section?'),
        content: Text('"${section.title}" and everything in it will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteSection(section.id);
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: FutureBuilder<Resume>(
          future: _future,
          builder: (context, snapshot) => Text(
            snapshot.data?.title ?? 'Resume',
            style: AppFonts.title(color: Colors.white),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.remove_red_eye_outlined), tooltip: 'Preview', onPressed: _openPreview),
          FutureBuilder<Resume>(
            future: _future,
            builder: (context, snapshot) => IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Rename',
              onPressed: snapshot.data == null ? null : () => _renameResume(snapshot.data!.title),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Resume>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              final message =
                  snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Could not load this resume.';
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                children: [
                  Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  Center(child: TextButton(onPressed: _refresh, child: const Text('Retry'))),
                ],
              );
            }

            final resume = snapshot.data!;
            final sections = resume.sections.toList()..sort((a, b) => a.order.compareTo(b.order));

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addSection,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Section'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                for (final section in sections) ...[
                  _SectionRow(
                    section: section,
                    onTap: () => _openSection(section),
                    onDelete: () => _confirmDeleteSection(section),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section, required this.onTap, required this.onDelete});

  final ResumeSection section;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    if (section.description != null && section.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        section.description!,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'delete', child: Text('Remove section')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
