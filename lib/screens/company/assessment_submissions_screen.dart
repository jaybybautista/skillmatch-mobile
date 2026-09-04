import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/assessment_submission.dart';
import '../../models/company_assessment.dart';
import '../../services/company_assessment_service.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/retake_open_tag.dart';
import 'assessment_answer_sheet_screen.dart';

/// Reached from "View Submissions" on an Assessment Library card — everyone
/// who has completed that assessment, with the score they got.
///
/// The score itself is fixed, computed by the shared AssessmentService when
/// the student submitted. The one action a card offers is Retake, which
/// reassigns the same paper to the application it came through, opening a
/// fresh attempt window without touching the score already on record.
class AssessmentSubmissionsScreen extends StatefulWidget {
  const AssessmentSubmissionsScreen({
    super.key,
    required this.assessment,
    this.internshipId,
    this.service,
  });

  final CompanyAssessment assessment;

  /// Opens showing only the applicants who took this paper for one posting.
  ///
  /// Set when the screen is reached from a posting's block in the library:
  /// the question being asked there is "how did *these* applicants do", not
  /// "how has this paper done everywhere". Null shows everyone.
  final int? internshipId;

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
  List<SubmissionPosting> _postings = const [];
  int _unattributed = 0;
  SubmissionTiming _timing = const SubmissionTiming();

  late int? _internshipId = widget.internshipId;

  /// The filter is only worth showing when the paper is used in more than
  /// one place, or when some attempts cannot be placed at all.
  bool get _canFilter => _postings.length > 1 || _unattributed > 0;

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
      final result = await _service.fetchSubmissions(
        widget.assessment.id,
        query: _searchController.text,
        internshipId: _internshipId,
      );
      if (!mounted) return;
      setState(() {
        _submissions = result.submissions;
        // The totals come back whole even when the list is filtered, so the
        // options can say how many are behind each without asking again.
        _postings = result.postings;
        _unattributed = result.unattributedCount;
        _timing = result.timing;
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

  void _filterBy(int? internshipId) {
    if (_internshipId == internshipId) return;
    setState(() => _internshipId = internshipId);
    _load();
  }

  /// What the header says this list is: the whole paper, or one posting.
  String? get _scopeLabel => _internshipId == null
      ? null
      : _postings
            .where((p) => p.id == _internshipId)
            .map((p) => p.title)
            .firstOrNull;

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
                          'Submission${count == 1 ? '' : 's'}'
                      '${_scopeLabel != null ? ' \u00b7 $_scopeLabel' : ''}',
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
                  if (_canFilter) _postingFilter(),
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

  /// One row of choices: everyone, then each posting with its own total.
  ///
  /// A paper shared between postings is one set of questions asked of
  /// different people, and "how did the applicants for *this* posting do" is
  /// a different question from "how has this paper done overall".
  Widget _postingFilter() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _FilterChip(
            label: 'All postings',
            count: _postings.fold<int>(0, (sum, p) => sum + p.submissionCount) +
                _unattributed,
            selected: _internshipId == null,
            onTap: () => _filterBy(null),
          ),
          for (final posting in _postings)
            _FilterChip(
              label: posting.title,
              count: posting.submissionCount,
              selected: _internshipId == posting.id,
              onTap: () => _filterBy(posting.id),
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
      final scope = _scopeLabel;

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
                      : scope != null
                      // Not "nobody has taken this paper" — nobody has taken
                      // it *here*, which for a shared paper is a different
                      // and much more useful thing to be told.
                      ? 'No one has completed this assessment for $scope yet. '
                            'Other postings using it may still have results.'
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
      // Yung buod ng tagal, nauuna bago yung listahan.
      itemCount: _submissions.length + (_timing.hasData ? 1 : 0),
      itemBuilder: (_, index) {
        if (_timing.hasData) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _TimingStrip(timing: _timing),
            );
          }
          index -= 1;
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == _submissions.length - 1 ? 0 : 16,
          ),
          child: _SubmissionCard(
            submission: _submissions[index],
            onTap: () => _openAnswerSheet(_submissions[index]),
            onRetake: _submissions[index].applicationId == null
                ? null
                : () => _retake(_submissions[index]),
          ),
        );
      },
    );
  }

  void _openAnswerSheet(AssessmentSubmission submission) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssessmentAnswerSheetScreen(
          assessmentId: widget.assessment.id,
          resultId: submission.id,
          studentName: submission.name,
        ),
      ),
    ).then((changed) {
      // Pag may binagong puntos, kailangang bagong-basa yung listahan.
      if (changed == true) _load();
    });
  }

  /// Re-runs the same reassignment the application's own Assign/Reassign
  /// action makes, on whichever application this attempt came through — the
  /// score already on record stays exactly as it is.
  Future<void> _retake(AssessmentSubmission submission) async {
    final applicationId = submission.applicationId;
    if (applicationId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retake this assessment?'),
        content: Text(
          'Let ${submission.name} retake "${widget.assessment.title}"? '
          'Their current score is kept, and this opens a fresh attempt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retake'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.retake(
        applicationId: applicationId,
        assessmentId: widget.assessment.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${submission.name} can now retake this assessment.'),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not open a retake.',
          ),
        ),
      );
    }
  }
}

/// Average, fastest and slowest, above the list. Only the attempts that
/// actually have a recorded duration are counted.
class _TimingStrip extends StatelessWidget {
  const _TimingStrip({required this.timing});

  final SubmissionTiming timing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: 'AVERAGE',
              value: SubmissionTiming.format(timing.averageSeconds),
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'FASTEST',
              value: SubmissionTiming.format(timing.fastestSeconds),
            ),
          ),
          Expanded(
            child: _Stat(
              label: 'SLOWEST',
              value: SubmissionTiming.format(timing.slowestSeconds),
            ),
          ),
        ],
      ),
    );
  }
}

/// One choice in the posting filter, carrying its own total so you can see
/// where the results are without tapping through every option.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 8),
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.submission,
    this.onTap,
    this.onRetake,
  });

  final AssessmentSubmission submission;

  /// Tapping opens the answer sheet, the same page the website's
  /// "View answers" link goes to.
  final VoidCallback? onTap;

  /// Null when the server could not tell which application this attempt
  /// came through — with nowhere safe to send it, there is no button.
  final VoidCallback? onRetake;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = submission.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _VerdictPill(submission: submission),
                  // Nananatili ito hangga't di pa siya sumasagot ulit, kaya
                  // makikita mo pa rin na may binigay kang bagong pagkakataon
                  // kahit matagal na mula nang pindutin mo.
                  if (submission.retakeOpen) ...[
                    const SizedBox(height: 6),
                    const RetakeOpenTag(),
                  ],
                ],
              ),
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
              Expanded(
                child: _Stat(
                  label: 'TIME SPENT',
                  value: submission.durationLabel ?? 'Not recorded',
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
          if (onRetake != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onRetake,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Retake'),
              ),
            ),
          ],
        ],
      ),
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
