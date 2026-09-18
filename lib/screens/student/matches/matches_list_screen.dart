import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../models/internship.dart';
import '../../../models/match_details.dart';
import '../../../services/internship_service.dart';
import '../../../widgets/paged_internship_list.dart';
import 'internship_search_screen.dart' show InternshipFilterButton;

/// Full "Top Matches For You" list — real internship postings from
/// Api\InternshipController::index(), ranked by the same match score shown
/// on the web dashboard.
class MatchesListScreen extends StatefulWidget {
  const MatchesListScreen({super.key, this.service});

  /// Injectable for tests; defaults to the real service.
  final InternshipService? service;

  @override
  State<MatchesListScreen> createState() => _MatchesListScreenState();
}

class _MatchesListScreenState extends State<MatchesListScreen> {
  late final InternshipService _internshipService =
      widget.service ?? InternshipService();
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  /// Same three orderings as the web's internships page.
  InternshipFilter _filter = InternshipFilter.topMatches;

  /// One page at a time: the list asks for the next page as the student
  /// scrolls. Kept in a field so it only changes on a new search/ordering
  /// (the list starts over whenever it changes).
  late Future<InternshipPage<Internship>> Function(int page) _loader = _makeLoader();
  int _refreshToken = 0;

  Future<InternshipPage<Internship>> Function(int page) _makeLoader() {
    final query = _searchController.text.trim();
    final filter = _filter;
    return (page) => _internshipService.fetchAllPage(
          query: query,
          filter: filter,
          page: page,
          perPage: 10,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _loader = _makeLoader());
    });
  }

  /// The server does the sorting, so switching ordering re-queries.
  void _onFilterChanged(InternshipFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _loader = _makeLoader();
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
              child: Row(
                children: [
                  _HeaderIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Top Matches For You',
                      style: AppFonts.title(fontSize: 22, color: Colors.white),
                    ),
                  ),
                  InternshipFilterButton(
                    selected: _filter,
                    onChanged: _onFilterChanged,
                    onDark: true,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search internships...',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.textMuted,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      PagedInternshipList(
                        controller: _scroll,
                        loader: _loader,
                        refreshToken: _refreshToken,
                        emptyHint: _searchController.text.trim().isEmpty
                            ? 'Check back once new postings are published.'
                            : 'Try a different keyword.',
                        // Only present on the proximity ordering, which is
                        // the only time it's what's being sorted on.
                        showDistance: _filter == InternshipFilter.proximity,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primaryDark, size: 20),
      ),
    );
  }
}
