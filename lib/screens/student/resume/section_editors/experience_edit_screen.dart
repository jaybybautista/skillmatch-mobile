import 'package:flutter/material.dart';

import '../../../../core/api_client.dart';
import '../../../../core/app_theme.dart';
import '../../../../models/resume.dart';
import '../../../../services/resume_service.dart';
import '../../../../widgets/ai_help_button.dart';
import '../../../../widgets/autosave_text_field.dart';

class ExperienceEditScreen extends StatefulWidget {
  const ExperienceEditScreen({super.key, required this.section});

  final ResumeSection section;

  @override
  State<ExperienceEditScreen> createState() => _ExperienceEditScreenState();
}

class _ExperienceEditScreenState extends State<ExperienceEditScreen> {
  final _service = ResumeService();
  late final List<ResumeExperienceEntry> _entries = List.of(widget.section.experiences);
  bool _isAdding = false;

  void _showError(Object e) {
    final message = e is ApiException ? e.message : 'Something went wrong. Please try again.';
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addEntry() async {
    setState(() => _isAdding = true);
    try {
      final entry = await _service.addExperience(widget.section.id);
      if (mounted) setState(() => _entries.add(entry));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteEntry(ResumeExperienceEntry entry) async {
    try {
      await _service.deleteExperience(entry.id);
      if (mounted) setState(() => _entries.removeWhere((e) => e.id == entry.id));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _save(ResumeExperienceEntry entry, {
    String? jobTitle,
    String? company,
    String? address,
    String? responsibilities,
    String? periodStart,
    String? periodEnd,
  }) async {
    try {
      await _service.updateExperience(
        entry.id,
        jobTitle: jobTitle,
        company: company,
        address: address,
        responsibilities: responsibilities,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
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
        title: Text('Experience', style: AppFonts.title(color: Colors.white)),
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
              child: Text('Tap + to add your first work experience.', style: TextStyle(color: AppColors.textMuted)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final entry in _entries) ...[
                  _ExperienceCard(
                    key: ValueKey(entry.id),
                    entry: entry,
                    onDelete: () => _deleteEntry(entry),
                    onFieldChanged: (field, value) => _save(entry, jobTitle: field == 'job_title' ? value : null,
                        company: field == 'company' ? value : null,
                        address: field == 'address' ? value : null,
                        responsibilities: field == 'responsibilities' ? value : null,
                        periodStart: field == 'period_start' ? value : null,
                        periodEnd: field == 'period_end' ? value : null),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}

class _ExperienceCard extends StatefulWidget {
  const _ExperienceCard({super.key, required this.entry, required this.onDelete, required this.onFieldChanged});

  final ResumeExperienceEntry entry;
  final VoidCallback onDelete;
  final void Function(String field, String value) onFieldChanged;

  @override
  State<_ExperienceCard> createState() => _ExperienceCardState();
}

class _ExperienceCardState extends State<_ExperienceCard> {
  final _responsibilitiesKey = GlobalKey<AutosaveTextFieldState>();
  late String _jobTitle = widget.entry.jobTitle ?? '';
  late String _company = widget.entry.company ?? '';

  ResumeExperienceEntry get entry => widget.entry;
  VoidCallback get onDelete => widget.onDelete;
  void Function(String field, String value) get onFieldChanged => widget.onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(onTap: onDelete, child: const Icon(Icons.close, size: 18, color: AppColors.textMuted)),
          ),
          AutosaveTextField(
            label: 'Job Title',
            initialValue: entry.jobTitle,
            onChanged: (v) {
              _jobTitle = v;
              onFieldChanged('job_title', v);
            },
          ),
          const SizedBox(height: 12),
          AutosaveTextField(
            label: 'Company',
            initialValue: entry.company,
            onChanged: (v) {
              _company = v;
              onFieldChanged('company', v);
            },
          ),
          const SizedBox(height: 12),
          AutosaveTextField(
            label: 'Address',
            initialValue: entry.address,
            onChanged: (v) => onFieldChanged('address', v),
          ),
          const SizedBox(height: 12),
          AutosaveTextField(
            key: _responsibilitiesKey,
            label: 'Responsibilities',
            initialValue: entry.responsibilities,
            maxLines: 4,
            onChanged: (v) => onFieldChanged('responsibilities', v),
            trailing: AiHelpButton(
              fieldLabel: 'Job Responsibilities',
              getText: () => _responsibilitiesKey.currentState?.currentText ?? entry.responsibilities ?? '',
              aiContext: {'job_title': _jobTitle, 'company': _company},
              onAccept: (suggestion) => _responsibilitiesKey.currentState?.setText(suggestion),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AutosaveTextField(
                  label: 'Period From',
                  initialValue: entry.periodStart,
                  onChanged: (v) => onFieldChanged('period_start', v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AutosaveTextField(
                  label: 'Period To',
                  initialValue: entry.periodEnd,
                  hint: 'e.g. Present',
                  onChanged: (v) => onFieldChanged('period_end', v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
