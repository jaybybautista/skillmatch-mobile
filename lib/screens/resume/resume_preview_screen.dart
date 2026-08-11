import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/resume.dart';
import '../../models/student_profile.dart';
import '../../services/profile_service.dart';
import '../../services/resume_display.dart';
import '../../services/resume_pdf_builder.dart';
import '../../services/resume_service.dart';

/// Read-only rendered resume — mirrors the web's
/// student.resume-builder.preview page layout (name/role/contact header,
/// then each section rendered the same way: summary text, entry lists with
/// title/sub/period, and a two-column technical/soft skills pill layout).
class ResumePreviewScreen extends StatefulWidget {
  const ResumePreviewScreen({super.key, required this.resumeId});

  final int resumeId;

  @override
  State<ResumePreviewScreen> createState() => _ResumePreviewScreenState();
}

class _ResumePreviewScreenState extends State<ResumePreviewScreen> {
  late final Future<(Resume, StudentProfile?)> _future = _load();
  bool _isDownloading = false;

  Future<(Resume, StudentProfile?)> _load() async {
    final resume = await ResumeService().fetchResume(widget.resumeId);
    StudentProfile? profile;
    try {
      profile = await ProfileService().fetchStudentProfile();
    } catch (_) {
      // Falls back to whatever basic_info the resume itself has.
    }
    return (resume, profile);
  }

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    try {
      final (resume, profile) = await _future;
      final bytes = await buildResumePdf(resume, profile);
      final fileName = '${resume.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim()}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName.isEmpty ? 'Resume.pdf' : fileName);
    } catch (e, stack) {
      debugPrint('Resume PDF download failed: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not generate the PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.ios_share_outlined),
            tooltip: 'Download',
            onPressed: _isDownloading ? null : _download,
          ),
        ],
      ),
      body: FutureBuilder<(Resume, StudentProfile?)>(
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
              ],
            );
          }

          final (resume, profile) = snapshot.data!;
          final header = computeResumeHeader(resume, profile);
          final sections = nonBasicInfoSections(resume);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    header.fullName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                  if (header.course != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      header.course!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted, letterSpacing: 1, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (header.addressLine.isNotEmpty) header.addressLine,
                      if (header.phone != null && header.phone!.isNotEmpty) header.phone!,
                      if (header.email != null && header.email!.isNotEmpty) header.email!,
                    ].join('  |  '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  for (final section in sections) _PreviewSection(section: section),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.section});

  final ResumeSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 5),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 1.5))),
            child: Text(
              section.title.toUpperCase(),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1),
            ),
          ),
          const SizedBox(height: 10),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (section.type) {
      case 'professional_summary':
        return _textOrEmpty(section.content, 'No summary added yet.');

      case 'experience':
        return _entries(
          section.experiences.isEmpty,
          'No experience added yet.',
          section.experiences.map(
            (e) => _Entry(
              title: e.jobTitle ?? '',
              subtitle: [e.company, e.address].where((s) => s != null && s.isNotEmpty).join(' — '),
              period: '${e.periodStart ?? ''} – ${e.periodEnd ?? ''}',
              description: e.responsibilities,
            ),
          ),
        );

      case 'achievements':
        return _entries(
          section.achievements.isEmpty,
          'No achievements added yet.',
          section.achievements.map(
            (a) => _Entry(
              title: a.title ?? '',
              subtitle: [a.category, a.location].where((s) => s != null && s.isNotEmpty).join(' — '),
              period: a.dateText ?? '',
            ),
          ),
        );

      case 'projects':
        return _entries(
          section.projects.isEmpty,
          'No projects added yet.',
          section.projects.map((p) => _Entry(title: p.title ?? '', description: p.description)),
        );

      case 'education':
        return _entries(
          section.education.isEmpty,
          'No education added yet.',
          section.education.map(
            (e) => _Entry(
              title: e.schoolName ?? '',
              subtitle: e.degree ?? '',
              period: '${e.startDate ?? ''} – ${e.endDate ?? ''}',
            ),
          ),
        );

      case 'skills':
        if (section.technicalSkills.isEmpty && section.softSkills.isEmpty) {
          return _empty('No skills added yet.');
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _SkillColumn(label: 'Technical Skills', skills: section.technicalSkills)),
            const SizedBox(width: 16),
            Expanded(child: _SkillColumn(label: 'Soft Skills', skills: section.softSkills)),
          ],
        );

      case 'custom':
        if (section.content == null || section.content!.isEmpty) return _empty('Nothing added yet.');
        if (section.inputType == 'bullet_points') {
          final lines = section.content!.split('\n').where((l) => l.trim().isNotEmpty);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('•  ${line.trim()}', style: const TextStyle(fontSize: 12.5, height: 1.5)),
                ),
            ],
          );
        }
        return Text(section.content!, style: const TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF2A2A3E)));

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _textOrEmpty(String? text, String emptyLabel) {
    if (text == null || text.isEmpty) return _empty(emptyLabel);
    return Text(text, style: const TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF2A2A3E)));
  }

  Widget _empty(String label) => Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic));

  Widget _entries(bool isEmpty, String emptyLabel, Iterable<_Entry> entries) {
    if (isEmpty) return _empty(emptyLabel);
    return Column(children: entries.toList());
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.title, this.subtitle, this.period, this.description});

  final String title;
  final String? subtitle;
  final String? period;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          ],
          if (period != null && period!.trim().isNotEmpty && period != ' – ') ...[
            const SizedBox(height: 1),
            Text(period!, style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontStyle: FontStyle.italic)),
          ],
          if (description != null && description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(description!, style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF2A2A3E))),
          ],
        ],
      ),
    );
  }
}

class _SkillColumn extends StatelessWidget {
  const _SkillColumn({required this.label, required this.skills});

  final String label;
  final List<ResumeSkillEntry> skills;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.4),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final skill in skills)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(4)),
                child: Text(skill.skillName, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ],
    );
  }
}
