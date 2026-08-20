import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/error_message.dart';
import '../../models/company_application.dart';
import '../../services/company_service.dart';
import '../../widgets/company_screen_header.dart';
import '../student/profile/student_public_profile_screen.dart';

/// One candidate in full — the phone's version of the website's candidate
/// page.
///
/// Shows the match against this company's postings (what they have and what
/// they're missing), their latest assessment, and their background, with the
/// same bookmark toggle the list offers. "View full profile" opens the
/// student's own profile, which is what the web's page links to.
class CandidateDetailScreen extends StatefulWidget {
  const CandidateDetailScreen({
    super.key,
    required this.studentId,
    this.initialName,
    this.service,
  });

  final int studentId;

  /// Shown in the header while the record loads, so the screen doesn't open
  /// on an anonymous "Candidate".
  final String? initialName;

  final CompanyService? service;

  @override
  State<CandidateDetailScreen> createState() => _CandidateDetailScreenState();
}

class _CandidateDetailScreenState extends State<CandidateDetailScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();

  bool _isLoading = true;
  Object? _error;
  CandidateDetail? _detail;

  /// True when the bookmark was changed here, so the list behind can refresh
  /// rather than showing a stale bookmark icon.
  bool _bookmarkChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _service.fetchCandidate(widget.studentId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  Future<void> _toggleBookmark() async {
    final detail = _detail;
    if (detail == null) return;

    final wasBookmarked = detail.candidate.isBookmarked;

    // Flipped straight away and put back if the request fails, so the star
    // never lags behind the tap.
    setState(() {
      _detail = CandidateDetail(
        candidate: detail.candidate.copyWith(isBookmarked: !wasBookmarked),
        missingSkills: detail.missingSkills,
        education: detail.education,
        certifications: detail.certifications,
        experiences: detail.experiences,
      );
    });

    try {
      final bookmarked = await _service.toggleCandidateBookmark(
        widget.studentId,
      );
      if (!mounted) return;
      _bookmarkChanged = true;
      setState(() {
        _detail = CandidateDetail(
          candidate: detail.candidate.copyWith(isBookmarked: bookmarked),
          missingSkills: detail.missingSkills,
          education: detail.education,
          certifications: detail.certifications,
          experiences: detail.experiences,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bookmarked ? 'Added to bookmarks.' : 'Removed from bookmarks.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _detail = detail);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            messageForError(
              e,
              'Could not save that. Check your connection and try again.',
            ),
          ),
        ),
      );
    }
  }

  void _openFullProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentPublicProfileScreen(studentId: widget.studentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _detail?.candidate;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_bookmarkChanged);
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompanyScreenHeader(
              title:
                  candidate?.summary.name ?? widget.initialName ?? 'Candidate',
              subtitle: candidate?.summary.course,
              onBack: () => Navigator.of(context).pop(_bookmarkChanged),
              trailing: candidate == null
                  ? null
                  : IconButton(
                      onPressed: _toggleBookmark,
                      icon: Icon(
                        candidate.isBookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: Colors.white,
                      ),
                      tooltip: candidate.isBookmarked
                          ? 'Remove bookmark'
                          : 'Bookmark',
                    ),
            ),
            Expanded(
              child: ColoredBox(
                color: AppColors.background,
                child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _detail == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(
            messageForError(
              _error ?? Exception(),
              'Could not load this candidate. Check your connection and try again.',
            ),
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

    final detail = _detail!;
    final candidate = detail.candidate;
    final summary = candidate.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Card(
          title: 'Match',
          icon: Icons.bolt_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${candidate.matchScore}%',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Best match across your postings',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (candidate.isOnOjt)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'On OJT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: candidate.matchScore / 100,
                  minHeight: 7,
                  backgroundColor: AppColors.background,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
              if (candidate.matchedSkills.isNotEmpty) ...[
                const SizedBox(height: 14),
                const _Subheading('Skills they have'),
                _Chips(candidate.matchedSkills, tone: _ChipTone.matched),
              ],
              // The other half of the match: what the postings ask for that
              // this candidate doesn't list.
              if (detail.missingSkills.isNotEmpty) ...[
                const SizedBox(height: 12),
                const _Subheading('Skills they are missing'),
                _Chips(detail.missingSkills, tone: _ChipTone.missing),
              ],
            ],
          ),
        ),

        _Card(
          title: 'Student',
          icon: Icons.person_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('Email', summary.email),
              _InfoRow('Course', summary.course),
              _InfoRow(
                'Year level',
                summary.yearLevel == null ? null : 'Year ${summary.yearLevel}',
              ),
              _InfoRow('Campus', summary.campus),
              _InfoRow(
                'Latest assessment',
                candidate.assessmentScore == null
                    ? null
                    : '${candidate.assessmentScore} points',
                isLast: true,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _openFullProfile,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View full profile'),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ),
            ],
          ),
        ),

        if (summary.skills.isNotEmpty)
          _Card(
            title: 'All skills',
            icon: Icons.lightbulb_outline,
            child: _Chips(summary.skills, tone: _ChipTone.plain),
          ),

        if (detail.education.isNotEmpty)
          _Card(
            title: 'Education',
            icon: Icons.school_outlined,
            child: _CredentialList(items: detail.education),
          ),

        if (detail.experiences.isNotEmpty)
          _Card(
            title: 'Experience',
            icon: Icons.work_history_outlined,
            child: _CredentialList(items: detail.experiences),
          ),

        if (detail.certifications.isNotEmpty)
          _Card(
            title: 'Certifications',
            icon: Icons.verified_outlined,
            child: _CredentialList(items: detail.certifications),
          ),
      ],
    );
  }
}

class _CredentialList extends StatelessWidget {
  const _CredentialList({required this.items});

  final List<CandidateCredential> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: i == items.length - 1
                  ? null
                  : const Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items[i].title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                if (items[i].subtitle.isNotEmpty)
                  Text(
                    items[i].subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (items[i].detail != null && items[i].detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    items[i].detail!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

enum _ChipTone { matched, missing, plain }

class _Chips extends StatelessWidget {
  const _Chips(this.items, {required this.tone});

  final List<String> items;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, text) = switch (tone) {
      _ChipTone.matched => (const Color(0xFFEAFAF1), const Color(0xFF1A7F4B)),
      _ChipTone.missing => (const Color(0xFFFFF1F1), AppColors.danger),
      _ChipTone.plain => (AppColors.chipBackground, AppColors.primary),
    };

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Subheading extends StatelessWidget {
  const _Subheading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// A label/value pair that renders nothing when the value is missing.
class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.isLast = false});

  final String label;
  final String? value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
