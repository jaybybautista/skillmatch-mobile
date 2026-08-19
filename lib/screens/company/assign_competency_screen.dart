import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/company_screen_header.dart';
import 'company_assessment.dart';
import 'posting_applicant.dart';

/// Reached from "Assign Assessment" on an applicant card — picks one
/// assessment from the library to assign to that candidate.
///
/// TODO: not wired to the backend yet — there is no company-assessments
/// assignment endpoint, so "Assign Test" just confirms and returns.
class AssignCompetencyScreen extends StatefulWidget {
  const AssignCompetencyScreen({super.key, required this.applicant});

  final PostingApplicant applicant;

  @override
  State<AssignCompetencyScreen> createState() => _AssignCompetencyScreenState();
}

class _AssignCompetencyScreenState extends State<AssignCompetencyScreen> {
  var _selectedIndex = 0;

  void _assign() {
    final assessment = placeholderCompanyAssessments[_selectedIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Assigning "${assessment.title}" to ${widget.applicant.name} is coming soon.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppGradients.companyHeaderEnd,
      body: Column(
        children: [
          CompanyScreenHeader(
            title: 'Assign Competency',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  _ApplicantSummaryCard(applicant: widget.applicant),
                  const SizedBox(height: 24),
                  Text('Assessments', style: AppFonts.title(fontSize: 18)),
                  const SizedBox(height: 12),
                  for (var i = 0; i < placeholderCompanyAssessments.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == placeholderCompanyAssessments.length - 1
                            ? 0
                            : 12,
                      ),
                      child: _SelectableAssessmentCard(
                        assessment: placeholderCompanyAssessments[i],
                        selected: i == _selectedIndex,
                        onTap: () => setState(() => _selectedIndex = i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          _StickyAssignFooter(onAssign: _assign),
        ],
      ),
    );
  }
}

class _ApplicantSummaryCard extends StatelessWidget {
  const _ApplicantSummaryCard({required this.applicant});

  final PostingApplicant applicant;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.chipBackground,
                child: Text(
                  applicant.initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(applicant.name, style: AppFonts.title(fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(
                    applicant.location,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in applicant.skills)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    skill.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
              Text(assessment.title, style: AppFonts.title(fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                assessment.description,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.quiz_outlined,
                    size: 17,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${assessment.questionCount} Questions',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 17,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${assessment.timeLimitMinutes} Mins',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyAssignFooter extends StatelessWidget {
  const _StickyAssignFooter({required this.onAssign});

  final VoidCallback onAssign;

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Assign Test'),
        ),
      ),
    );
  }
}
