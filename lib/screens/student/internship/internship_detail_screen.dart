import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/internship_detail.dart';
import '../../../services/internship_service.dart';
import '../reviews/reviews_section.dart';

/// Internship posting detail — mirrors the web's internship detail page
/// (resources/views/student/internships/show.blade.php): gradient banner
/// (the web app uses a gradient too, not a stock photo) with the company's
/// real logo, Work Description / Company / Reviews tabs, and a sticky Apply
/// Now button.
class InternshipDetailScreen extends StatefulWidget {
  const InternshipDetailScreen({
    super.key,
    required this.internshipId,
    this.canApply = true,
  });

  final int internshipId;

  /// False when the viewer isn't a student - a company looking at a posting
  /// from search, say. Applying and bookmarking both need a student row, so
  /// the controls are hidden rather than left there to fail.
  final bool canApply;

  @override
  State<InternshipDetailScreen> createState() => _InternshipDetailScreenState();
}

class _InternshipDetailScreenState extends State<InternshipDetailScreen>
    with SingleTickerProviderStateMixin {
  final _service = InternshipService();
  late Future<InternshipDetail> _future = _service.fetchDetail(
    widget.internshipId,
  );
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  )..addListener(_onTabChanged);

  bool? _bookmarkOverride;
  bool? _appliedOverride;
  bool _isApplying = false;

  void _onTabChanged() => setState(() {});

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleBookmark() async {
    try {
      final newState = await _service.toggleBookmark(widget.internshipId);
      if (mounted) setState(() => _bookmarkOverride = newState);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update bookmark. Please try again.'),
        ),
      );
    }
  }

  Future<void> _apply() async {
    setState(() => _isApplying = true);
    try {
      await _service.apply(widget.internshipId);
      if (!mounted) return;
      setState(() => _appliedOverride = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application submitted!')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not submit your application. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<InternshipDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || !snapshot.hasData) {
              final message = snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : 'Could not load this posting.';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => setState(
                          () => _future = _service.fetchDetail(
                            widget.internshipId,
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final detail = snapshot.data!;
            final isBookmarked = _bookmarkOverride ?? detail.isBookmarked;
            final isApplied = _appliedOverride ?? detail.isApplied;

            return Column(
              children: [
                _HeroHeader(
                  detail: detail,
                  isBookmarked: isBookmarked,
                  onBookmarkTap: _toggleBookmark,
                  showBookmark: widget.canApply,
                ),
                const SizedBox(height: 44),
                _InfoHeader(detail: detail),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Work Description'),
                    Tab(text: 'Company'),
                    Tab(text: 'Reviews'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _WorkDescriptionTab(detail: detail),
                      _CompanyTab(detail: detail),
                      ReviewsSection(
                        reviewableType: 'internship',
                        reviewableId: widget.internshipId,
                      ),
                    ],
                  ),
                ),
                if (widget.canApply)
                  _StickyFooter(
                    showWriteReview: _tabController.index == 2,
                    isApplied: isApplied,
                    isApplying: _isApplying,
                    hasSlots: detail.slotsAvailable > 0,
                    onApply: _apply,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.detail,
    required this.isBookmarked,
    required this.onBookmarkTap,
    this.showBookmark = true,
  });

  final bool showBookmark;

  final InternshipDetail detail;
  final bool isBookmarked;
  final VoidCallback onBookmarkTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleIconButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                if (showBookmark)
                  _CircleIconButton(
                    icon: isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    iconColor: isBookmarked
                        ? AppColors.primary
                        : AppColors.textDark,
                    onTap: onBookmarkTap,
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: -40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 84,
                height: 84,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: detail.companyLogoUrl != null
                      ? Image.network(
                          detail.companyLogoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _initials(),
                        )
                      : _initials(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials() {
    return Container(
      alignment: Alignment.center,
      color: AppColors.chipBackground,
      child: Text(
        detail.companyInitials,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 22,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: iconColor ?? AppColors.textDark),
      ),
    );
  }
}

class _InfoHeader extends StatelessWidget {
  const _InfoHeader({required this.detail});

  final InternshipDetail detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            detail.title,
            textAlign: TextAlign.center,
            style: AppFonts.title(fontSize: 20, color: AppColors.textDark),
          ),
          if (detail.location != null && detail.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detail.location!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Badge(
                text: detail.slotsAvailable > 0
                    ? '${detail.slotsAvailable} slots left'
                    : 'No slots left',
                background: const Color(0xFFFFF4E5),
                foreground: const Color(0xFFE56B00),
              ),
              if (detail.matchScore != null)
                _Badge(
                  text: '${detail.matchScore}% Match',
                  background: AppColors.primary,
                  foreground: Colors.white,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SectionBox extends StatelessWidget {
  const _SectionBox({
    required this.title,
    required this.child,
    this.background = Colors.white,
  });

  final String title;
  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFonts.title(fontSize: 15, color: AppColors.textDark),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WorkDescriptionTab extends StatelessWidget {
  const _WorkDescriptionTab({required this.detail});

  final InternshipDetail detail;

  @override
  Widget build(BuildContext context) {
    final responsibilities = detail.responsibilities;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _SectionBox(
          title: 'Responsibilities',
          child: responsibilities != null && responsibilities.isNotEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in responsibilities)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '•  ',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              : Text(
                  detail.description.isEmpty
                      ? 'No description provided.'
                      : detail.description,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        _SectionBox(
          title: 'Skills Needed',
          background: AppColors.background,
          child: detail.skills.isEmpty
              ? const Text(
                  'Not specified',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final skill in detail.skills)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          skill,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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

class _CompanyTab extends StatelessWidget {
  const _CompanyTab({required this.detail});

  final InternshipDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _SectionBox(
          title: 'About the Company',
          child: Text(
            (detail.companyAbout == null || detail.companyAbout!.isEmpty)
                ? 'No description available for this company.'
                : detail.companyAbout!,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _StickyFooter extends StatelessWidget {
  const _StickyFooter({
    required this.showWriteReview,
    required this.isApplied,
    required this.isApplying,
    required this.hasSlots,
    required this.onApply,
  });

  final bool showWriteReview;
  final bool isApplied;
  final bool isApplying;
  final bool hasSlots;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: showWriteReview
            ? ElevatedButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Writing reviews is coming soon.'),
                  ),
                ),
                child: const Text('Write Review'),
              )
            : ElevatedButton(
                onPressed: (isApplied || !hasSlots || isApplying)
                    ? null
                    : onApply,
                style: (isApplied || !hasSlots)
                    ? ElevatedButton.styleFrom(
                        backgroundColor: AppColors.border,
                        foregroundColor: AppColors.textMuted,
                      )
                    : null,
                child: isApplying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isApplied
                            ? 'Already Applied'
                            : (hasSlots ? 'Apply Now' : 'No Slots Left'),
                      ),
              ),
      ),
    );
  }
}
