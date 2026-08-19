import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/company_application.dart';
import '../../models/company_assessment.dart';
import '../../services/company_service.dart';
import '../../widgets/company_screen_header.dart';

/// Picks one of the company's assessments to hand to an applicant.
///
/// Assigning goes through the shared CompanyAssessmentService, so it does
/// exactly what the website's assign action does: opens a fresh attempt
/// window (which is what lets a company give someone a second go at the same
/// paper), moves a still-pending application to Under review, and notifies
/// the student.
class AssignAssessmentScreen extends StatefulWidget {
  const AssignAssessmentScreen({
    super.key,
    required this.application,
    this.service,
  });

  final CompanyApplication application;
  final CompanyService? service;

  @override
  State<AssignAssessmentScreen> createState() => _AssignAssessmentScreenState();
}

class _AssignAssessmentScreenState extends State<AssignAssessmentScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();

  bool _isLoading = true;
  bool _isAssigning = false;
  Object? _error;
  List<CompanyAssessment> _assessments = const [];
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.application.assignedAssessmentId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final assessments = await _service.fetchAssignableAssessments();
      if (!mounted) return;
      setState(() {
        _assessments = assessments;
        // Preselect whatever is already assigned, otherwise the first one, so
        // the primary button is never disabled for want of a tap.
        _selectedId ??= assessments.isEmpty ? null : assessments.first.id;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _assign() async {
    final selectedId = _selectedId;
    if (selectedId == null) return;

    setState(() => _isAssigning = true);
    try {
      await _service.assignAssessment(
        applicationId: widget.application.id,
        assessmentId: selectedId,
      );
      if (!mounted) return;
      final title = _assessments.firstWhere((a) => a.id == selectedId).title;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$title" sent to ${widget.application.student.name}.'),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isAssigning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final alreadyAssigned = widget.application.assignedAssessmentId != null;

    return Scaffold(
      backgroundColor: AppGradients.companyHeaderEnd,
      body: Column(
        children: [
          CompanyScreenHeader(
            title: 'Assign Assessment',
            subtitle: widget.application.student.name,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: _buildBody(alreadyAssigned),
            ),
          ),
          if (!_isLoading && _error == null && _assessments.isNotEmpty)
            _AssignFooter(
              onAssign: _isAssigning || _selectedId == null ? null : _assign,
              isAssigning: _isAssigning,
              label: _selectedId != null && _selectedId == widget.application.assignedAssessmentId
                  // Sending the same paper again is a reassignment, and the
                  // student is told as much — so the button says so too.
                  ? 'Reassign'
                  : 'Assign Test',
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool alreadyAssigned) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            _error is ApiException
                ? (_error as ApiException).message
                : 'Could not load your assessments.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    if (_assessments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(32, 60, 32, 0),
        child: Column(
          children: [
            Icon(Icons.quiz_outlined, size: 40, color: AppColors.textMuted),
            SizedBox(height: 14),
            Text(
              'No assessments to assign',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Create one in the Assessment Library first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        _ApplicantSummaryCard(application: widget.application),
        if (alreadyAssigned) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningBackground,
              border: Border.all(color: AppColors.warningBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Already has "${widget.application.assignedAssessmentTitle ?? 'an assessment'}". '
                    'Assigning again lets them answer it afresh.',
                    style: const TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        Text('Assessments', style: AppFonts.title(fontSize: 18)),
        const SizedBox(height: 12),
        for (var i = 0; i < _assessments.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == _assessments.length - 1 ? 0 : 12),
            child: _SelectableAssessmentCard(
              assessment: _assessments[i],
              selected: _assessments[i].id == _selectedId,
              onTap: () => setState(() => _selectedId = _assessments[i].id),
            ),
          ),
      ],
    );
  }
}

class _ApplicantSummaryCard extends StatelessWidget {
  const _ApplicantSummaryCard({required this.application});

  final CompanyApplication application;

  @override
  Widget build(BuildContext context) {
    final student = application.student;
    final avatarUrl = student.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.chipBackground,
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        student.initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.title(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      application.internshipTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                    ),
                    if (student.course != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        student.course!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectableAssessmentCard extends StatelessWidget {
  const _SelectableAssessmentCard({
    required this.assessment,
    required this.selected,
    required this.onTap,
  });

  final CompanyAssessment assessment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.chipBackground : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(assessment.title, style: AppFonts.title(fontSize: 17))),
                  if (selected)
                    const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
                ],
              ),
              if (assessment.internshipTitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  'For ${assessment.internshipTitle}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ],
              if (assessment.description != null && assessment.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  assessment.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.quiz_outlined, size: 17, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${assessment.questionCount} '
                    'Question${assessment.questionCount == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  if (assessment.timeLimitMinutes != null) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time_rounded, size: 17, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      '${assessment.timeLimitMinutes} Mins',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ],
              ),
              // A draft has no questions saved yet, so assigning it would hand
              // the student an empty paper.
              if (assessment.isDraft) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.warning),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Still a draft — add questions before assigning it.',
                        style: TextStyle(color: AppColors.warning, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignFooter extends StatelessWidget {
  const _AssignFooter({
    required this.onAssign,
    required this.isAssigning,
    required this.label,
  });

  final VoidCallback? onAssign;
  final bool isAssigning;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: onAssign,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isAssigning
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(label),
        ),
      ),
    );
  }
}
