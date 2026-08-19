import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/empty_results.dart';
import 'company_posting.dart';
import 'posting_applicant.dart';

enum _ApplicantView {
  allApplicants('All Applicants'),
  topMatches('Top Matches');

  const _ApplicantView(this.label);

  final String label;
}

/// Shown when a company taps one of its postings — lists everyone who
/// applied, either as a plain roster ("All Applicants") or ranked by AI
/// match score with a "why this match" explanation ("Top Matches"),
/// switchable via the filter icon in the header.
///
/// TODO: static placeholder data — see [PostingApplicant].
class PostingApplicantsScreen extends StatefulWidget {
  const PostingApplicantsScreen({super.key, required this.posting});

  final CompanyPosting posting;

  @override
  State<PostingApplicantsScreen> createState() =>
      _PostingApplicantsScreenState();
}

class _PostingApplicantsScreenState extends State<PostingApplicantsScreen> {
  var _view = _ApplicantView.topMatches;
  final _searchController = TextEditingController();
  final _applicants = placeholderApplicants();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// This roster is still placeholder data, so there is no real application
  /// to assign against. Assigning for real lives on the Applications screen,
  /// which is backed by the same `applications` rows the website manages.
  void _assignAssessment(PostingApplicant applicant) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Assign an assessment from the Applications screen.'),
      ),
    );
  }

  List<PostingApplicant> get _visibleApplicants {
    final query = _searchController.text.trim().toLowerCase();
    final results = query.isEmpty
        ? List<PostingApplicant>.of(_applicants)
        : _applicants
              .where((a) => a.name.toLowerCase().contains(query))
              .toList();
    if (_view == _ApplicantView.topMatches) {
      results.sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final applicants = _visibleApplicants;
    return Scaffold(
      backgroundColor: AppGradients.companyHeaderEnd,
      body: Column(
        children: [
          CompanyScreenHeader(
            title: widget.posting.title,
            subtitle: _view == _ApplicantView.topMatches
                ? 'Top Matches For You'
                : 'Applicants (${widget.posting.applicants})',
            onBack: () => Navigator.of(context).maybePop(),
            trailing: PopupMenuButton<_ApplicantView>(
              icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
              onSelected: (view) => setState(() => _view = view),
              itemBuilder: (context) => [
                for (final view in _ApplicantView.values)
                  PopupMenuItem(
                    value: view,
                    child: Text(
                      view.label,
                      style: TextStyle(
                        fontWeight: view == _view
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: view == _view
                            ? AppColors.primary
                            : AppColors.textDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                children: [
                  _SearchField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (applicants.isEmpty)
                    const EmptyResults(
                      title: 'No applicants found',
                      hint: 'Try a different search.',
                      icon: Icons.people_outline,
                    )
                  else
                    for (var i = 0; i < applicants.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == applicants.length - 1 ? 0 : 16,
                        ),
                        child: _ApplicantCard(
                          applicant: applicants[i],
                          showMatch: _view == _ApplicantView.topMatches,
                          onAssign: () => _assignAssessment(applicants[i]),
                          onToggleBookmark: () => setState(
                            () => applicants[i].bookmarked =
                                !applicants[i].bookmarked,
                          ),
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: AppColors.textDark, fontSize: 15),
              decoration: const InputDecoration(
                isDense: true,
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: 'Search internships...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.search, color: AppColors.primary, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({
    required this.applicant,
    required this.showMatch,
    required this.onAssign,
    required this.onToggleBookmark,
  });

  final PostingApplicant applicant;
  final bool showMatch;
  final VoidCallback onAssign;
  final VoidCallback onToggleBookmark;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.chipBackground,
                child: Text(
                  applicant.initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(applicant.name, style: AppFonts.title(fontSize: 16)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          applicant.location,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (showMatch) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMidBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${applicant.matchPercent}% Match',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final skill in applicant.skills)
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
                    skill.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (showMatch) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FB),
                borderRadius: BorderRadius.circular(10),
                border: const Border(
                  left: BorderSide(color: AppColors.blueLeft, width: 3),
                ),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Why this match? ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.normal,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextSpan(text: applicant.matchReason),
                  ],
                ),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAssign,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Assign Assessment'),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: onToggleBookmark,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    applicant.bookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: applicant.bookmarked
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
