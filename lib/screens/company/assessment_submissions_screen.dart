import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/assessment_submission.dart';
import '../../models/company_assessment.dart';
import '../../services/company_assessment_service.dart';
import '../../widgets/company_screen_header.dart';

/// Reached from "View Submissions" on an Assessment Library card — everyone
/// who has completed that assessment, with the score they got.
///
/// Read-only, like the website's Records → Assessments table: the score was
/// computed by the shared AssessmentService when the student submitted, and
/// what happens to a candidate next is decided on their application, not on
/// the attempt.
class AssessmentSubmissionsScreen extends StatefulWidget {
  const AssessmentSubmissionsScreen({
    super.key,
    required this.assessment,
    this.service,
  });

  final CompanyAssessment assessment;
  final CompanyAssessmentService? service;

  @override
  State<AssessmentSubmissionsScreen> createState() =>
      _AssessmentSubmissionsScreenState();
}

class _AssessmentSubmissionsScreenState
    extends State<AssessmentSubmissionsScreen> {
  late final CompanyAssessmentService _service =
      widget.service ?? CompanyAssessmentService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  Object? _error;
  List<AssessmentSubmission> _submissions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final submissions = await _service.fetchSubmissions(
        widget.assessment.id,
        query: _searchController.text,
      );
      if (!mounted) return;
      setState(() {
        _submissions = submissions;
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    final count = _isLoading ? null : _submissions.length;

    return Scaffold(
      backgroundColor: AppGradients.companyHeaderEnd,
      body: Column(
        children: [
          CompanyScreenHeader(
            title: widget.assessment.title,
            subtitle: count == null
                ? 'Submissions'
                : '${count.toString().padLeft(2, '0')} '
                      'Submission${count == 1 ? '' : 's'}',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search by name or email...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: _buildBody(),
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

  Widget _buildBody() {
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
                : 'Could not load these submissions.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    if (_submissions.isEmpty) {
      final isSearching = _searchController.text.trim().isNotEmpty;

      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
            child: Column(
              children: [
                const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 40,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 14),
                Text(
                  isSearching
                      ? 'No matching submissions'
                      : 'No submissions yet',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isSearching
                      ? 'No one by that name has completed this assessment.'
                      : 'Results appear here once a candidate completes this assessment.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: _submissions.length,
      itemBuilder: (_, index) => Padding(
        padding: EdgeInsets.only(
          bottom: index == _submissions.length - 1 ? 0 : 16,
        ),
        child: _SubmissionCard(submission: _submissions[index]),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.submission});

  final AssessmentSubmission submission;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = submission.avatarUrl;
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
                radius: 24,
                backgroundColor: AppColors.chipBackground,
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                child: hasAvatar
                    ? null
                    : Text(
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
                    Text(
                      submission.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.title(fontSize: 16),
                    ),
                    if (submission.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        submission.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _VerdictPill(submission: submission),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'COMPLETED',
                  value: submission.submittedAtLabel,
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'SCORE',
                  value: '${submission.score} / ${submission.totalPoints}',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'PERCENTAGE',
                  value: '${submission.percentage}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: submission.percentage / 100,
              minHeight: 6,
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation<Color>(
                submission.passed ? const Color(0xFF1A7F4B) : AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Passed / Failed, or "Timed out" — which never passes however well the
/// answered questions scored, the same rule the student's result screen
/// applies.
class _VerdictPill extends StatelessWidget {
  const _VerdictPill({required this.submission});

  final AssessmentSubmission submission;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = submission.timedOut
        ? ('Timed out', AppColors.warningBackground, AppColors.warning)
        : submission.passed
        ? ('Passed', const Color(0xFFEAFAF1), const Color(0xFF1A7F4B))
        : ('Failed', const Color(0xFFFFF1F1), AppColors.danger);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: foreground,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
