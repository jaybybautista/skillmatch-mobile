import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/internship.dart';
import '../screens/student/internship/internship_detail_screen.dart';
import '../services/internship_service.dart';

class MatchCard extends StatefulWidget {
  const MatchCard({
    super.key,
    required this.internship,
    this.onBookmarkChanged,
    this.onReturned,
    this.onOpen,
    this.showBookmark = true,
  });

  /// Where a tap goes, when the caller needs somewhere other than the
  /// student's internship detail screen - a company searching its own
  /// postings, for instance, belongs on the posting page.
  final VoidCallback? onOpen;

  /// Bookmarking an internship is a student action, so the button is hidden
  /// for anyone else rather than left there to fail.
  final bool showBookmark;

  final Internship internship;

  /// Fires right after a successful toggle, with the new bookmarked state —
  /// e.g. the Bookmarks screen uses this to drop the card from its list the
  /// instant it's un-bookmarked, instead of requiring a manual refresh.
  final ValueChanged<bool>? onBookmarkChanged;

  /// Fires after returning from the internship detail screen (where the
  /// bookmark can also be toggled), so a caller like Bookmarks can re-sync.
  final VoidCallback? onReturned;

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  final _service = InternshipService();
  late bool _isBookmarked = widget.internship.isBookmarked;
  bool _isToggling = false;

  Future<void> _toggleBookmark() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    try {
      final newState = await _service.toggleBookmark(widget.internship.id);
      if (!mounted) return;
      setState(() => _isBookmarked = newState);
      widget.onBookmarkChanged?.call(newState);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update bookmark. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> _openDetail() async {
    final onOpen = widget.onOpen;
    if (onOpen != null) {
      onOpen();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            InternshipDetailScreen(internshipId: widget.internship.id),
      ),
    );
    widget.onReturned?.call();
  }

  @override
  Widget build(BuildContext context) {
    final internship = widget.internship;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openDetail,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CompanyLogo(internship: internship),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        internship.companyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (internship.location != null)
                        Text(
                          internship.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (internship.matchScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${internship.matchScore}% Match',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _toggleBookmark,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: _isToggling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textMuted,
                            ),
                          )
                        : Icon(
                            _isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: _isBookmarked
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(internship.title, style: AppFonts.title(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              internship.slotsAvailable > 0
                  ? '${internship.slotsAvailable} slots left'
                  : 'No slots left',
              style: TextStyle(
                color: internship.slotsAvailable > 0
                    ? AppColors.danger
                    : AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              internship.displayDescription,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (internship.skills.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in internship.skills.toSet().take(4))
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
                        tag.toUpperCase(),
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
          ],
        ),
      ),
    );
  }
}

class _CompanyLogo extends StatelessWidget {
  const _CompanyLogo({required this.internship});

  final Internship internship;

  @override
  Widget build(BuildContext context) {
    final logoUrl = internship.companyLogoUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: logoUrl != null
            ? Image.network(
                logoUrl,
                fit: BoxFit.cover,
                width: 48,
                height: 48,
                errorBuilder: (context, error, stackTrace) => _initials(),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              )
            : _initials(),
      ),
    );
  }

  Widget _initials() {
    return Text(
      internship.companyInitials,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }
}
