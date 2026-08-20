import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/company_navigation.dart';
import '../../core/error_message.dart';
import '../../models/company_profile.dart';
import '../../models/review.dart';
import '../../services/company_service.dart';
import '../../services/review_service.dart';
import '../../widgets/matcha_launcher.dart';
import '../../widgets/company_bottom_nav.dart';
import '../../widgets/company_sidebar.dart';
import '../student/profile/image_viewer_screen.dart';
import '../student/reviews/review_replies_screen.dart';
import 'company_settings_screen.dart';
import 'edit_company_profile_screen.dart';

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
  const CompanyProfileScreen({super.key, this.service, this.reviewService});

  final CompanyService? service;

  /// Only injected by tests; the screen makes its own otherwise.
  final ReviewService? reviewService;

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();
  late final ReviewService _reviews = widget.reviewService ?? ReviewService();

  bool _isLoading = true;
  Object? _error;
  CompanyProfile? _profile;
  List<Review> _reviewList = [];
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
      final reviews =
          results[1] as ({List<Review> reviews, ReviewSummary summary});
      setState(() {
        _profile = results[0] as CompanyProfile;
        _reviewList = List<Review>.of(reviews.reviews);
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

  /// Opens the edit form, the same fields the website's "Edit profile" mode
  /// exposes. It hands back the saved profile, so nothing is refetched just
  /// to show what was typed a moment ago.
  Future<void> _edit() async {
    final profile = _profile;
    if (profile == null) return;

    final saved = await Navigator.of(context).push<CompanyProfile>(
      MaterialPageRoute(
        builder: (_) =>
            EditCompanyProfileScreen(profile: profile, service: widget.service),
      ),
    );

    if (saved != null && mounted) setState(() => _profile = saved);
  }

  /// Tapping the logo opens it full-screen, where it can also be replaced -
  /// the same two-in-one the student profile photo has.
  Future<void> _openLogo() async {
    final url = _profile?.logoUrl;
    if (url == null) {
      await _replaceImage(isLogo: true);
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ImageViewer(
          imageUrl: url,
          heroTag: 'company-logo',
          title: 'Company logo',
          onChange: () => _replaceImage(isLogo: true),
        ),
      ),
    );

    if (changed == true && mounted) await _load();
  }

  Future<void> _openCover() async {
    final url = _profile?.coverUrl;
    if (url == null) {
      await _replaceImage(isLogo: false);
      return;
    }

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ImageViewer(
          imageUrl: url,
          heroTag: 'company-cover',
          title: 'Cover photo',
          onChange: () => _replaceImage(isLogo: false),
        ),
      ),
    );

    if (changed == true && mounted) await _load();
  }

  /// Picks an image and uploads it as the logo or the cover photo, returning
  /// whether anything actually changed.
  ///
  /// Both write exactly what the website writes: the logo lands on
  /// `companies.logo` *and* `users.profile_picture` (which is what the avatar
  /// reads), the cover on `users.cover_photo`.
  Future<bool> _replaceImage({required bool isLogo}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );

    final path = result?.files.singleOrNull?.path;
    if (path == null || !mounted) return false;

    final label = isLogo ? 'logo' : 'cover photo';
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Uploading $label…'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      if (isLogo) {
        await _service.updateLogo(path);
      } else {
        await _service.updateCover(path);
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${label[0].toUpperCase()}${label.substring(1)} updated.',
            ),
          ),
        );
      if (mounted) await _load();
      return true;
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              messageForError(e, 'Could not upload that $label. Try again.'),
            ),
          ),
        );
      return false;
    }
  }

  /// Opens the review's thread, where a reply can be written — the same
  /// screen the student side uses, backed by the same `reviews` rows, so a
  /// company's answer shows up on the website's review list too.
  Future<void> _openReplies(Review review) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewRepliesScreen(rootReviewId: review.id),
      ),
    );
    // A reply may have been added while we were away, so the counts on the
    // cards are refreshed rather than left stale.
    if (mounted) await _load();
  }

  /// Likes or unlikes, updating the card immediately and putting it back if
  /// the request fails.
  Future<void> _toggleLike(Review review) async {
    final index = _indexOfReview(review.id);
    if (index == -1) return;

    final wasLiked = review.hasLiked;
    setState(() {
      _reviewList[index] = review.copyWith(
        hasLiked: !wasLiked,
        likeCount: review.likeCount + (wasLiked ? -1 : 1),
      );
    });

    try {
      final result = await _reviews.toggleLike(review.id);
      if (!mounted) return;
      setState(() {
        _reviewList[index] = _reviewList[index].copyWith(
          hasLiked: result.liked,
          likeCount: result.likeCount,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reviewList[index] = review);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageForError(e, 'Could not save that. Try again.')),
        ),
      );
    }
  }

  int _indexOfReview(int reviewId) =>
      _reviewList.indexWhere((r) => r.id == reviewId);

  /// Shown in place of a value the company hasn't filled in yet, rather than
  /// an empty gap that reads as a rendering bug.
  static const _notSet = 'Not set yet';

  /// Up to two letters from the company name, for when there's no logo.
  static String _initialsFor(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '—';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return (words.first.characters.first + words[1].characters.first)
        .toUpperCase();
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
          title: const Text(
            'Company Profile',
            style: TextStyle(color: Colors.white),
          ),
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
      // Every top-level company screen carries the bar, so navigation
      // doesn't change shape depending on how you arrived. This screen is
      // not one of its four tabs, hence no highlight.
      bottomNavigationBar: CompanyBottomNav(
        currentIndex: -1,
        onSelect: (i) => handleCompanyNavTap(context, i),
      ),
      drawer: const CompanySidebar(current: CompanySidebarItem.profile),
      // Navy so a top overscroll bounce keeps showing header colour.
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Navy band: header row plus the gap the logo pokes into. Not
                // wrapped in SafeArea as a whole — only the row is — so the band
                // still paints behind the status bar.
                _CoverBand(
                  coverUrl: profile.coverUrl,
                  onTap: _openCover,
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
          // Same launcher the web keeps on every page.
          const MatchaLauncher(),
        ],
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
          icon: Icons.edit_outlined,
          tooltip: 'Edit profile',
          onTap: _edit,
        ),
        const SizedBox(width: 10),
        _HeaderIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Settings',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CompanySettingsScreen()),
          ),
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
                      ? 'No summary yet. Tap the pencil above to add one, so '
                            'students know what an internship with you is like.'
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
                    _LabelValueRow(
                      label: 'Company Name',
                      value: profile.companyName,
                    ),
                    const SizedBox(height: 14),
                    _LabelValueRow(
                      label: 'Industry',
                      value: profile.industry ?? _notSet,
                    ),
                    const SizedBox(height: 14),
                    _LabelValueRow(
                      label: 'Address',
                      value: profile.address ?? _notSet,
                    ),
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
                    _LabelValueRow(
                      label: 'Website URL',
                      value: profile.website ?? _notSet,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('At a Glance'),
              const SizedBox(height: 10),
              _Card(
                child: Row(
                  children: [
                    _StatCell(
                      label: 'POSTINGS',
                      value: profile.stats.internshipCount,
                    ),
                    _StatCell(
                      label: 'OPEN SLOTS',
                      value: profile.stats.openSlots,
                    ),
                    _StatCell(
                      label: 'APPLICANTS',
                      value: profile.stats.applicantCount,
                    ),
                    _StatCell(
                      label: 'PLACED',
                      value: profile.stats.placementCount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Reviews & Feedback'),
              const SizedBox(height: 10),
              _RatingSummaryCard(summary: _reviewSummary),
              const SizedBox(height: 12),
              if (_reviewList.isEmpty)
                const _Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'No reviews yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                for (var i = 0; i < _reviewList.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == _reviewList.length - 1 ? 0 : 12,
                    ),
                    child: _ReviewCard(
                      review: _reviewList[i],
                      onOpenReplies: () => _openReplies(_reviewList[i]),
                      onToggleLike: () => _toggleLike(_reviewList[i]),
                    ),
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
              GestureDetector(
                onTap: _openLogo,
                child: Hero(
                  tag: 'company-logo',
                  child: _CompanyLogo(
                    logoUrl: profile.logoUrl,
                    initials: _initialsFor(profile.companyName),
                  ),
                ),
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
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final String? tooltip;

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
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

/// The band behind the header: the company's cover photo when it has one,
/// the flat navy otherwise. Tapping it opens the photo, where it can be
/// replaced.
class _CoverBand extends StatelessWidget {
  const _CoverBand({required this.child, required this.onTap, this.coverUrl});

  final Widget child;
  final VoidCallback onTap;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final url = coverUrl;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: url == null
                ? const ColoredBox(color: AppColors.primaryDark)
                : Hero(
                    tag: 'company-cover',
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      // An unreachable cover falls back to the navy rather
                      // than a broken-image glyph behind the header.
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: AppColors.primaryDark),
                    ),
                  ),
          ),
          if (url != null)
            // Keeps the white header text readable over any photo.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Full-screen view of the logo or cover, with a "Change photo" button.
///
/// The student side's [ImageViewerScreen] does the same job but uploads
/// through the student endpoint, so this reuses its look with the company's
/// own upload passed in.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({
    required this.imageUrl,
    required this.heroTag,
    required this.title,
    required this.onChange,
  });

  final String imageUrl;
  final String heroTag;
  final String title;
  final Future<bool> Function() onChange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: AppFonts.title(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Could not load this photo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: OutlinedButton.icon(
            onPressed: () async {
              final changed = await onChange();
              if (changed && context.mounted) Navigator.of(context).pop(true);
            },
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Change photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
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
  const _ReviewCard({
    required this.review,
    required this.onOpenReplies,
    required this.onToggleLike,
  });

  final Review review;
  final VoidCallback onOpenReplies;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = review.authorAvatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return InkWell(
      onTap: onOpenReplies,
      borderRadius: BorderRadius.circular(14),
      child: _Card(
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
            const SizedBox(height: 6),
            Row(
              children: [
                // Both are real controls now: the like writes a reaction, and
                // the reply count opens the thread where an answer is written.
                _ReviewAction(
                  icon: review.hasLiked
                      ? Icons.thumb_up
                      : Icons.thumb_up_outlined,
                  label: '${review.likeCount}',
                  isActive: review.hasLiked,
                  onTap: onToggleLike,
                ),
                const SizedBox(width: 8),
                _ReviewAction(
                  icon: Icons.mode_comment_outlined,
                  label: review.replyCount == 0
                      ? 'Reply'
                      : '${review.replyCount} ${review.replyCount == 1 ? 'reply' : 'replies'}',
                  onTap: onOpenReplies,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable control under a review — the like toggle and the reply
/// affordance share this so they read as a pair.
class _ReviewAction extends StatelessWidget {
  const _ReviewAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
