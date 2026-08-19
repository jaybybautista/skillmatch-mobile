import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'company_review.dart';

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
/// own placeholder data since there is no company-profile/company-reviews
/// backend yet.
class CompanyProfileScreen extends StatelessWidget {
  const CompanyProfileScreen({super.key});

  static const companyName = 'Creatix Studio';
  static const industry = 'Information Technology';

  void _comingSoon(BuildContext context, String what) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            _sheet(context),
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

  Widget _sheet(BuildContext context) {
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
              const _Card(
                child: Text(
                  'Creatix Studio partners with universities to give students hands-on product, design, and '
                  'engineering experience. We run small, mentor-led teams so every intern ships real work — '
                  'not busywork — before they graduate.',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Company Details'),
              const SizedBox(height: 10),
              const _Card(
                child: Column(
                  children: [
                    _LabelValueRow(label: 'Company Name', value: companyName),
                    SizedBox(height: 14),
                    _LabelValueRow(
                      label: 'Address',
                      value: 'Zone 6, Capandanan, Santa Maria, Pangasinan',
                    ),
                    SizedBox(height: 14),
                    _LabelValueRow(
                      label: 'Website URL',
                      value: 'https://samplelang.com',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Reviews & Feedback'),
              const SizedBox(height: 10),
              const _RatingSummaryCard(summary: placeholderReviewSummary),
              const SizedBox(height: 12),
              for (var i = 0; i < placeholderCompanyReviews.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == placeholderCompanyReviews.length - 1 ? 0 : 12,
                  ),
                  child: _ReviewCard(review: placeholderCompanyReviews[i]),
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
              const _CompanyLogo(),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.title(),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        industry,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
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

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo();

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
        child: const ColoredBox(
          color: AppColors.chipBackground,
          child: Center(
            child: Text(
              'CS',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
          ),
        ),
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

  final CompanyReviewSummary summary;

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
                'Based on ${summary.total} reviews',
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

  final CompanyReview review;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.chipBackground,
                child: Text(
                  review.initials,
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
                        review.reviewerName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      ' · ${review.timeAgo}',
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
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= review.rating ? Icons.star : Icons.star_border,
                  size: 14,
                  color: _starColor,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.tag,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            review.body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
