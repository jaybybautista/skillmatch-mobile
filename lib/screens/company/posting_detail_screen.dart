import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/error_message.dart';
import '../../models/company_assessment.dart';
import '../../services/company_service.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/matcha_launcher.dart';
import 'assessment_preview_screen.dart';
import 'assessment_library_screen.dart';
import 'company_posting.dart';
import 'create_post_screen.dart';
import 'posting_applicants_screen.dart';

/// One posting in full — the phone's version of the website's "Posting
/// Detail" page.
///
/// Reads GET /api/company/postings/{id}, which serialises the same
/// `internships` row, the same six status buckets, and the same linked
/// assessments the web page renders, so a number here matches the number
/// there. Edit, close/reopen and delete all go through the shared
/// CompanyPostingService.
class PostingDetailScreen extends StatefulWidget {
  const PostingDetailScreen({
    super.key,
    required this.postingId,
    this.initialPosting,
    this.service,
  });

  final int postingId;

  /// Shown while the full posting loads, so opening from the list doesn't
  /// flash an empty header.
  final CompanyPosting? initialPosting;

  final CompanyService? service;

  @override
  State<PostingDetailScreen> createState() => _PostingDetailScreenState();
}

class _PostingDetailScreenState extends State<PostingDetailScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();

  bool _isLoading = true;
  bool _isBusy = false;
  Object? _error;

  CompanyPosting? _posting;
  PostingStatusCounts _counts = const PostingStatusCounts();
  List<CompanyAssessment> _assessments = const [];

  /// True once anything on this screen changed the posting, so the list
  /// behind it knows to reload.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _posting = widget.initialPosting;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchPosting(widget.postingId);
      if (!mounted) return;
      setState(() {
        _posting = result.posting;
        _counts = result.counts;
        _assessments = result.assessments;
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

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit() async {
    final posting = _posting;
    if (posting == null) return;

    final saved = await Navigator.of(context).push<CompanyPosting>(
      MaterialPageRoute(builder: (_) => CreatePostScreen(posting: posting)),
    );
    if (saved == null || !mounted) return;

    _changed = true;
    await _load();
  }

  Future<void> _toggleStatus() async {
    final posting = _posting;
    if (posting == null || _isBusy) return;

    if (posting.isOpen) {
      // Closing stops the posting taking applications and hides it from
      // students, which is worth one tap of confirmation. Reopening is
      // harmless, so it happens straight away.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Close this posting?'),
          content: Text(
            '"${posting.title}" stops accepting applications and no longer '
            'shows up for students. You can reopen it any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Close posting'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isBusy = true);
    try {
      final updated = await _service.togglePostingStatus(posting.id);
      if (!mounted) return;
      _changed = true;
      setState(() {
        _posting = updated;
        _isBusy = false;
      });
      _notify(
        updated.isOpen
            ? '"${updated.title}" reopened.'
            : '"${updated.title}" closed.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _notify(
        messageForError(
          e,
          'Could not reach the server. Check your connection and try again.',
        ),
      );
    }
  }

  Future<void> _delete() async {
    final posting = _posting;
    if (posting == null || _isBusy) return;

    final applicants =
        _counts.pending +
        _counts.reviewing +
        _counts.shortlisted +
        _counts.hired +
        _counts.rejected +
        _counts.withdrawn;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove posting?'),
        content: Text(
          applicants > 0
              ? '"${posting.title}" has $applicants '
                    '${applicants == 1 ? 'applicant' : 'applicants'}. '
                    'Removing it also removes their applications.'
              : 'This removes "${posting.title}" for good.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    // Both resolved before the await: after the pop this State's context is
    // gone, but the app-level messenger the snack bar lands on is not.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.deletePosting(posting.id);
      if (!mounted) return;
      // The posting this screen is about no longer exists, so leave.
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(content: Text('"${posting.title}" has been removed.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      _notify(
        messageForError(
          e,
          'Could not reach the server. Check your connection and try again.',
        ),
      );
    }
  }

  void _openApplicants() {
    final posting = _posting;
    if (posting == null) return;

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PostingApplicantsScreen(
              posting: posting,
              service: widget.service,
            ),
          ),
        )
        // A status moved while we were away changes every count on this page.
        .then((_) {
          if (mounted) _load();
        });
  }

  @override
  Widget build(BuildContext context) {
    final posting = _posting;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Stack(
          children: [
            Column(
              children: [
                CompanyScreenHeader(
                  title: 'Posting Detail',
                  onBack: () => Navigator.of(context).pop(_changed),
                ),
                Expanded(
                  child: ColoredBox(
                    color: AppColors.background,
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: _buildBody(posting),
                    ),
                  ),
                ),
              ],
            ),
            const MatchaLauncher(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CompanyPosting? posting) {
    if (_isLoading && posting == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posting == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            _error == null
                ? 'Could not load this posting.'
                : messageForError(_error!, 'Could not load this posting.'),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
      children: [
        _headerCard(posting),
        const SizedBox(height: 14),
        _overviewCard(posting),
        const SizedBox(height: 14),
        _applicantsCard(),
        const SizedBox(height: 14),
        _listCard(
          icon: Icons.assignment_outlined,
          title: 'Responsibilities',
          child: posting.responsibilities.isEmpty
              ? const _EmptyLine('No responsibilities listed yet.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in posting.responsibilities)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 6, right: 10),
                              child: _Dot(),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  height: 1.45,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _listCard(
          icon: Icons.lightbulb_outline,
          title: 'Required skills',
          child: posting.skills.isEmpty
              ? const _EmptyLine('No skills listed yet.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final skill in posting.skills) _SkillChip(skill),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _assessmentsCard(),
      ],
    );
  }

  // ---- cards ----

  Widget _headerCard(CompanyPosting posting) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            posting.title,
            style: AppFonts.title(fontSize: 22, color: AppColors.textDark),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatusPill(isOpen: posting.isOpen),
              const SizedBox(width: 10),
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  posting.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          if (posting.postedAtHuman != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.work_outline,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Posted ${posting.postedAtHuman}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: AppColors.border),
          ),
          // The same three actions the web page puts under the title.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionButton(
                icon: Icons.edit_outlined,
                label: 'Edit posting',
                onTap: _isBusy ? null : _edit,
              ),
              _ActionButton(
                icon: posting.isOpen
                    ? Icons.block_outlined
                    : Icons.play_circle_outline,
                label: posting.isOpen ? 'Close posting' : 'Reopen posting',
                tint: posting.isOpen ? AppColors.danger : _openGreen,
                onTap: _isBusy ? null : _toggleStatus,
              ),
              _ActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                onTap: _isBusy ? null : _delete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewCard(CompanyPosting posting) {
    final applicants = posting.applicants;
    final slots = posting.openSlots;
    // The web fills this bar from accepted applications, not slots_filled:
    // an acceptance is what actually claims a slot.
    final filled = _counts.hired;
    final progress = slots <= 0 ? 0.0 : (filled / slots).clamp(0.0, 1.0);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(icon: Icons.pie_chart_outline, label: 'Overview'),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
            children: [
              _StatBox(
                value: applicants,
                label: 'Applicants',
                tint: AppColors.primary,
              ),
              _StatBox(value: slots, label: 'Open slots'),
              _StatBox(
                value: _counts.hired,
                label: 'Accepted',
                tint: _openGreen,
              ),
              _StatBox(
                value: _counts.shortlisted,
                label: 'Interview',
                tint: const Color(0xFFD97706),
              ),
              _StatBox(
                value: _counts.rejected,
                label: 'Rejected',
                tint: AppColors.danger,
              ),
              _StatBox(value: _assessments.length, label: 'Assessments'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Slots filled',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
              Text(
                '$filled / $slots',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.chipBackground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _applicantsCard() {
    final total = _posting?.applicants ?? 0;

    return _Card(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: total == 0 ? null : _openApplicants,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: _CardTitle(
                      icon: Icons.people_outline,
                      label: 'Applicants',
                    ),
                  ),
                  Text(
                    '$total total',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  if (total > 0) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ],
              ),
              if (total == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: _EmptyLine('No one has applied to this posting yet.'),
                )
              else ...[
                const SizedBox(height: 14),
                // The web's filter tabs, as read-only counts: tapping through
                // opens the applicant list where the filtering happens.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CountChip(label: 'All', count: total, isPrimary: true),
                    if (_counts.pending > 0)
                      _CountChip(label: 'Pending', count: _counts.pending),
                    if (_counts.reviewing > 0)
                      _CountChip(label: 'Reviewing', count: _counts.reviewing),
                    if (_counts.shortlisted > 0)
                      _CountChip(
                        label: 'Interview',
                        count: _counts.shortlisted,
                      ),
                    if (_counts.hired > 0)
                      _CountChip(label: 'Accepted', count: _counts.hired),
                    if (_counts.rejected > 0)
                      _CountChip(label: 'Rejected', count: _counts.rejected),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _assessmentsCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _CardTitle(
                  icon: Icons.description_outlined,
                  label: 'Assessments',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const AssessmentLibraryScreen(),
                      ),
                    )
                    .then((_) {
                      if (mounted) _load();
                    }),
                child: const Text('Manage'),
              ),
            ],
          ),
          if (_assessments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: _EmptyLine(
                'No assessments linked. Go to Assessments to create and link '
                'one.',
              ),
            )
          else
            for (final assessment in _assessments)
              _AssessmentRow(
                assessment: assessment,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AssessmentPreviewScreen(
                      assessmentId: assessment.id,
                      initialTitle: assessment.title,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _listCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(icon: icon, label: title),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ---- pieces ----

/// The green the postings list already uses for an open posting.
const _openGreen = Color(0xFF1A7F4B);

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppFonts.title(fontSize: 15.5, color: AppColors.textDark),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label, this.tint});

  final int value;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: AppFonts.title(
              fontSize: 21,
              color: tint ?? AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.textDark;

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFEAFAF1) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: isOpen ? _openGreen : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.chipBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    this.isPrimary = false,
  });

  final String label;
  final int count;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.primary : AppColors.chipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPrimary ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow({required this.assessment, required this.onTap});

  final CompanyAssessment assessment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final questions = assessment.questionCount;
    final limit = assessment.timeLimitMinutes;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assessment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$questions question${questions == 1 ? '' : 's'}'
                    '${limit != null ? ' • $limit min' : ''}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.textMuted, height: 1.4),
    );
  }
}
