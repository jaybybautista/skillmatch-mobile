import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/company_profile.dart';
import '../../models/review.dart';
import '../../services/company_service.dart';
import '../../widgets/company_sidebar.dart';

const _starColor = Color(0xFFF5A623);

/// The whole page is one scroll view, so the navy header scrolls away with
/// the content instead of staying pinned. The logo overflows the top of the
/// white sheet by `_logoOverlap` (Clip.none) to straddle the boundary — no
/// scroll listener needed, since header, logo and list all move together.
const _logoSize = 92.0;
const _logoOverlap = 42.0;
const _blueGap = 48.0;

/// The company's own profile — reached from the person icon in
/// [CompanyHomeScreen]'s header. Mirrors the student side's
/// `ProfileScreen`/`ReviewsSection` visual language (navy header, white
/// rounded sheet, rounded-square hero logo straddling the boundary, plain
/// bold section titles above bordered white cards, the same star-rating
/// breakdown bars) rather than reinventing the look, but with the company's
/// own data, read from GET /api/company/profile — the same `companies` row
/// the website's company profile page shows.
///
/// The reviews below are the real thing too: GET /api/company/profile/reviews
/// returns Company::allReviews() — feedback left on the company plus feedback
/// left on any of its postings, merged newest-first — which is exactly what
/// the web profile page renders.
class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key, this.service});

  final CompanyService? service;

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();

  bool _isLoading = true;
  Object? _error;
  CompanyProfile? _profile;
  List<Review> _reviews = const [];
  ReviewSummary _reviewSummary = ReviewSummary.empty();

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
      // Fetched together so the profile and its feedback appear in one paint
      // rather than the reviews popping in a moment later.
      //
      // Future.wait rather than two awaits in a row: awaiting them one after
      // the other leaves the second future's error unobserved if the first
      // one fails, which surfaces later as an unhandled async error rather
      // than in the catch below.
      final results = await Future.wait<Object>([
        _service.fetchProfile(),
        _service.fetchProfileReviews(),
      ]);
      if (!mounted) return;
      final reviews = results[1] as ({List<Review> reviews, ReviewSummary summary});
      setState(() {
        _profile = results[0] as CompanyProfile;
        _reviews = reviews.reviews;
        _reviewSummary = reviews.summary;
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

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  /// Shown in place of a value the company hasn't filled in yet, rather than
  /// an empty gap that reads as a rendering bug.
  static const _notSet = 'Not set yet';

  /// Up to two letters from the company name, for when there's no logo.
  static String _initialsFor(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '—';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return (words.first.characters.first + words[1].characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: const Text('Company Profile', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error is ApiException
                      ? (_error as ApiException).message
                      : 'Could not load your company profile.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    final profile = _profile!;

    return Scaffold(
      drawer: const CompanySidebar(current: CompanySidebarItem.profile),
      // Navy so a top overscroll bounce keeps showing header colour.
      backgroundColor: AppColors.primaryDark,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Navy band: header row plus the gap the logo pokes into. Not
            // wrapped in SafeArea as a whole — only the row is — so the band
            // still paints behind the status bar.
            ColoredBox(
              color: AppColors.primaryDark,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                      child: _header(context),
                    ),
                    const SizedBox(height: _blueGap),
                  ],
                ),
              ),
            ),
            _sheet(context, profile),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        _HeaderIconButton(
          icon: Icons.chevron_left,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Profile',
            style: AppFonts.title(fontSize: 22, color: Colors.white),
          ),
        ),
        _HeaderIconButton(
          icon: Icons.settings_outlined,
          onTap: () => _comingSoon(context, 'Settings'),
        ),
      ],
    );
  }

  Widget _sheet(BuildContext context, CompanyProfile profile) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          // Keeps the sheet reaching the bottom of the screen even when the
          // content is short, so no navy leaks below the last card.
          constraints: BoxConstraints(
            minHeight: MediaQuery.sizeOf(context).height,
          ),
          padding: const EdgeInsets.fromLTRB(
            20,
            _logoSize - _logoOverlap + 22,
            20,
            40,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Professional Summary'),
              const SizedBox(height: 10),
              _Card(
                child: Text(
                  (profile.description ?? '').trim().isEmpty
                      ? 'No summary yet. Add one on the website so students '
                          'know what an internship with you is like.'
                      : profile.description!,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Company Details'),
              const SizedBox(height: 10),
              _Card(
                child: Column(
                  children: [
                    _LabelValueRow(label: 'Company Name', value: profile.companyName),
                    const SizedBox(height: 14),
                    _LabelValueRow(label: 'Industry', value: profile.industry ?? _notSet),
                    const SizedBox(height: 14),
                    _LabelValueRow(label: 'Address', value: profile.address ?? _notSet),
                    const SizedBox(height: 14),
                    _LabelValueRow(
                      label: 'Contact Email',
                      value: profile.contactEmail ?? _notSet,
                    ),
                    const SizedBox(height: 14),
                    _LabelValueRow(
                      label: 'Contact Number',
                      value: profile.contactNumber ?? _notSet,
                    ),
                    const SizedBox(height: 14),
                    _LabelValueRow(label: 'Website URL', value: profile.website ?? _notSet),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('At a Glance'),
              const SizedBox(height: 10),
              _Card(
                child: Row(
                  children: [
                    _StatCell(label: 'POSTINGS', value: profile.stats.internshipCount),
                    _StatCell(label: 'OPEN SLOTS', value: profile.stats.openSlots),
                    _StatCell(label: 'APPLICANTS', value: profile.stats.applicantCount),
                    _StatCell(label: 'PLACED', value: profile.stats.placementCount),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Reviews & Feedback'),
              const SizedBox(height: 10),
              _RatingSummaryCard(summary: _reviewSummary),
              const SizedBox(height: 12),
              if (_reviews.isEmpty)
                const _Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'No reviews yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                for (var i = 0; i < _reviews.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == _reviews.length - 1 ? 0 : 12),
                    child: _ReviewCard(review: _reviews[i]),
                  ),
            ],
          ),
        ),
        Positioned(
          top: -_logoOverlap,
          left: 20,
          right: 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CompanyLogo(
                logoUrl: profile.logoUrl,
                initials: _initialsFor(profile.companyName),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.title(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.industry ?? 'Industry not set',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      if (!profile.isVerified) ...[
                        const SizedBox(height: 6),
                        _VerificationChip(status: profile.verificationStatus),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(child: Icon(icon, color: Colors.white, size: 20)),
    );
  }
}

/// Matches the student avatar's metrics (20 outer / 17 inner radius, 3px
/// white ring, soft drop shadow); the clipped bottom-right corner is the one
/// deliberate difference, so a company reads as a company at a glance.
const _logoOuterRadius = BorderRadius.all(Radius.circular(20));

const _logoInnerRadius = BorderRadius.only(
  topLeft: Radius.circular(17),
  topRight: Radius.circular(17),
  bottomLeft: Radius.circular(17),
  bottomRight: Radius.circular(3),
);

/// The logo's stand-in when a company hasn't uploaded one.
class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.chipBackground,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
      ),
    );
  }
}

/// One figure in the "At a Glance" row.
class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value.toString(), style: AppFonts.title(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Says where an unapproved company stands, since it changes what they can do
/// — the website shows the same state on their profile.
class _VerificationChip extends StatelessWidget {
  const _VerificationChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isRejected ? const Color(0xFFFFF1F1) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isRejected ? 'Verification rejected' : 'Pending verification',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isRejected ? AppColors.danger : const Color(0xFFB87700),
        ),
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({this.logoUrl, this.initials = '—'});

  final String? logoUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _logoSize,
      height: _logoSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _logoOuterRadius,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _logoInnerRadius,
        child: logoUrl != null
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                // A broken or unreachable logo falls back to initials rather
                // than Flutter's grey broken-image glyph.
                errorBuilder: (_, _, _) => _InitialsBadge(initials: initials),
              )
            : _InitialsBadge(initials: initials),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppFonts.title(fontSize: 17));
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _LabelValueRow extends StatelessWidget {
  const _LabelValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 116,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingSummaryCard extends StatelessWidget {
  const _RatingSummaryCard({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                summary.average.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= summary.average.round()
                          ? Icons.star
                          : Icons.star_border,
                      size: 13,
                      color: _starColor,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Based on ${summary.total} review${summary.total == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: EdgeInsets.only(bottom: star == 1 ? 0 : 6),
                    child: Row(
                      children: [
                        Text(
                          '$star',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 6,
                              value: summary.total == 0
                                  ? 0
                                  : (summary.ratingCounts[star] ?? 0) /
                                        summary.total,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation(
                                _starColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 18,
                          child: Text(
                            '${summary.ratingCounts[star] ?? 0}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = review.authorAvatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.chipBackground,
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        review.authorInitial,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        review.authorName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      ' \u00b7 ${review.createdAtHuman}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // A reply carries no rating, so the stars only render for a review.
          if (review.rating != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= review.rating! ? Icons.star : Icons.star_border,
                    size: 14,
                    color: _starColor,
                  ),
              ],
            ),
          ],
          // "On internship: X" — only present when the feedback was left on a
          // posting rather than on the company itself.
          if (review.reviewableContext != null) ...[
            const SizedBox(height: 6),
            Text(
              review.reviewableContext!,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (review.title != null && review.title!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.title!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            review.content,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.thumb_up_outlined, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${review.likeCount}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.mode_comment_outlined, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${review.replyCount} ${review.replyCount == 1 ? 'reply' : 'replies'}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
