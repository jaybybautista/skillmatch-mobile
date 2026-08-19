import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/company_screen_header.dart';
import 'assessment_submission.dart';
import 'company_assessment.dart';

/// Reached from "View Submissions" on an Assessment Library card — lists
/// everyone who has completed that assessment, with a status selector to
/// mark each one Accepted or Rejected.
///
/// TODO: static placeholder data — see [AssessmentSubmission]. Marking a
/// status only updates local state, there's nothing to save it to yet.
class AssessmentSubmissionsScreen extends StatefulWidget {
  const AssessmentSubmissionsScreen({super.key, required this.assessment});

  final CompanyAssessment assessment;

  @override
  State<AssessmentSubmissionsScreen> createState() =>
      _AssessmentSubmissionsScreenState();
}

class _AssessmentSubmissionsScreenState
    extends State<AssessmentSubmissionsScreen> {
  final _submissions = placeholderSubmissions();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppGradients.companyHeaderEnd,
      body: Column(
        children: [
          CompanyScreenHeader(
            title: widget.assessment.title,
            subtitle:
                '${_submissions.length.toString().padLeft(2, '0')} Submissions',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  for (var i = 0; i < _submissions.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i == _submissions.length - 1 ? 0 : 16,
                      ),
                      child: _SubmissionCard(
                        submission: _submissions[i],
                        onStatusChanged: (status) =>
                            setState(() => _submissions[i].status = status),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.submission,
    required this.onStatusChanged,
  });

  final AssessmentSubmission submission;
  final void Function(SubmissionStatus status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
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
                radius: 24,
                backgroundColor: AppColors.chipBackground,
                child: Text(
                  submission.initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(submission.name, style: AppFonts.title(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      submission.email,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMPLETED',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      submission.completedDate,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SCORE',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${submission.score}/${submission.totalScore}',
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StatusSelector(
            status: submission.status,
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.status, required this.onChanged});

  final SubmissionStatus status;
  final void Function(SubmissionStatus status) onChanged;

  static const _accepted = Color(0xFF16A34A);
  static const _acceptedBackground = Color(0xFFE9F9EF);
  static const _rejected = Color(0xFFBE123C);
  static const _rejectedBackground = Color(0xFFFCEAEE);

  String get _label => switch (status) {
    SubmissionStatus.accepted => 'Accepted',
    SubmissionStatus.rejected => 'Rejected',
    SubmissionStatus.pending => 'Mark Status as',
  };

  Color get _foreground => switch (status) {
    SubmissionStatus.accepted => _accepted,
    SubmissionStatus.rejected => _rejected,
    SubmissionStatus.pending => AppColors.textMuted,
  };

  Color get _background => switch (status) {
    SubmissionStatus.accepted => _acceptedBackground,
    SubmissionStatus.rejected => _rejectedBackground,
    SubmissionStatus.pending => Colors.white,
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SubmissionStatus>(
      onSelected: onChanged,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: SubmissionStatus.accepted,
          child: Text(
            'Accepted',
            style: TextStyle(
              color: _accepted,
              fontWeight: status == SubmissionStatus.accepted
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
        PopupMenuItem(
          value: SubmissionStatus.rejected,
          child: Text(
            'Rejected',
            style: TextStyle(
              color: _rejected,
              fontWeight: status == SubmissionStatus.rejected
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == SubmissionStatus.pending
                ? AppColors.border
                : _foreground.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _label,
              style: TextStyle(
                color: _foreground,
                fontSize: 15,
                fontWeight: status == SubmissionStatus.pending
                    ? FontWeight.w500
                    : FontWeight.bold,
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: _foreground),
          ],
        ),
      ),
    );
  }
}
