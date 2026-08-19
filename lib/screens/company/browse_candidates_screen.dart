import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/company_application.dart';
import '../../services/company_service.dart';
import '../../widgets/company_screen_header.dart';
import '../../widgets/company_sidebar.dart';

/// The orderings the web candidates page offers.
enum _CandidateSort {
  matchScore('match_score', 'Best match'),
  name('name', 'Name'),
  assessment('assessment', 'Assessment');

  const _CandidateSort(this.key, this.label);
  final String key;
  final String label;
}

/// Browse Candidates — students matched against this company's postings,
/// backed by /api/company/candidates. Honours the same "Show profile to
/// companies" opt-out and the same AI match threshold as the website, and
/// bookmarks write the same `company_bookmarks` rows.
class BrowseCandidatesScreen extends StatefulWidget {
  const BrowseCandidatesScreen({super.key, this.service, this.bookmarksOnly = false});

  final CompanyService? service;

  /// When true this is the Bookmarks view rather than the full browse list.
  final bool bookmarksOnly;

  @override
  State<BrowseCandidatesScreen> createState() => _BrowseCandidatesScreenState();
}

class _BrowseCandidatesScreenState extends State<BrowseCandidatesScreen> {
  late final CompanyService _service = widget.service ?? CompanyService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  Object? _error;
  List<Candidate> _candidates = const [];
  _CandidateSort _sort = _CandidateSort.matchScore;

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
      final candidates = widget.bookmarksOnly
          ? await _service.fetchBookmarkedCandidates()
          : await _service.fetchCandidates(
              query: _searchController.text,
              sort: _sort.key,
            );
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
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

  Future<void> _toggleBookmark(Candidate candidate) async {
    // Flipped straight away so the star responds to the tap, then corrected
    // from the server's answer if they disagree.
    setState(() {
      _candidates = _candidates
          .map((c) => c.id == candidate.id ? c.copyWith(isBookmarked: !c.isBookmarked) : c)
          .toList();
    });

    try {
      final bookmarked = await _service.toggleCandidateBookmark(candidate.id);
      if (!mounted) return;

      // The Bookmarks view drops a candidate that was just un-bookmarked.
      if (widget.bookmarksOnly && !bookmarked) {
        setState(() => _candidates = _candidates.where((c) => c.id != candidate.id).toList());
        return;
      }

      setState(() {
        _candidates = _candidates
            .map((c) => c.id == candidate.id ? c.copyWith(isBookmarked: bookmarked) : c)
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // Put it back the way it was.
      setState(() {
        _candidates = _candidates
            .map((c) => c.id == candidate.id ? c.copyWith(isBookmarked: candidate.isBookmarked) : c)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CompanySidebar(
        current: widget.bookmarksOnly
            ? CompanySidebarItem.bookmarks
            : CompanySidebarItem.candidates,
      ),
      backgroundColor: AppColors.primaryDark,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CompanyScreenHeader(
            title: widget.bookmarksOnly ? 'Bookmarks' : 'Browse candidates',
            showMenuButton: true,
          ),
          Expanded(
            child: ColoredBox(
              color: AppColors.background,
              child: Column(
                children: [
                  if (!widget.bookmarksOnly) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search by name, course, or skill...',
                          prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        children: [
                          for (final sort in _CandidateSort.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(sort.label),
                                selected: _sort == sort,
                                onSelected: (_) {
                                  setState(() => _sort = sort);
                                  _load();
                                },
                                labelStyle: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight:
                                      _sort == sort ? FontWeight.bold : FontWeight.normal,
                                  color: _sort == sort ? Colors.white : AppColors.textDark,
                                ),
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.white,
                                showCheckmark: false,
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: RefreshIndicator(onRefresh: _load, child: _buildBody()),
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
                : 'Could not load candidates.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    if (_candidates.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 60, 32, 0),
            child: Column(
              children: [
                Icon(
                  widget.bookmarksOnly ? Icons.bookmark_border : Icons.groups_outlined,
                  size: 40,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 14),
                Text(
                  widget.bookmarksOnly ? 'No bookmarked candidates' : 'No candidates found',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.bookmarksOnly
                      ? 'Bookmark a candidate while browsing and they will be kept here.'
                      : 'Try a different search, or lower your match threshold in Settings '
                          'on the website.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: _candidates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final candidate = _candidates[index];
        return _CandidateCard(
          candidate: candidate,
          onBookmark: () => _toggleBookmark(candidate),
        );
      },
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.onBookmark});

  final Candidate candidate;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final student = candidate.summary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                backgroundImage:
                    student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                child: student.avatarUrl == null
                    ? Text(
                        student.initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (student.course != null) student.course!,
                        if (student.yearLevel != null) 'Year ${student.yearLevel}',
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                    if (student.campus != null)
                      Text(
                        student.campus!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  candidate.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: candidate.isBookmarked ? AppColors.primary : AppColors.textMuted,
                ),
                tooltip: candidate.isBookmarked ? 'Remove bookmark' : 'Bookmark',
                onPressed: onBookmark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MatchBadge(score: candidate.matchScore),
              if (candidate.assessmentScore != null) ...[
                const SizedBox(width: 8),
                _Pill(
                  label: 'Assessment ${candidate.assessmentScore}%',
                  color: const Color(0xFF3D6EF5),
                  background: const Color(0xFFE8EEFF),
                ),
              ],
              if (candidate.isOnOjt) ...[
                const SizedBox(width: 8),
                const _Pill(
                  label: 'On OJT',
                  color: Color(0xFF1A7F4B),
                  background: Color(0xFFEAFAF1),
                ),
              ],
            ],
          ),
          if (candidate.matchedSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Matched skills',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: AppColors.textMuted.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final skill in candidate.matchedSkills.take(6))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The match percentage, coloured by how strong it is.
class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (score) {
      >= 80 => (const Color(0xFF1A7F4B), const Color(0xFFEAFAF1)),
      >= 50 => (const Color(0xFFB87700), const Color(0xFFFFF4E5)),
      _ => (const Color(0xFF64748B), const Color(0xFFF1F5F9)),
    };

    return _Pill(label: '$score% match', color: color, background: background);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
