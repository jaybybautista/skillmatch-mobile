import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/internship.dart';
import '../../../services/internship_service.dart';
import '../../../widgets/empty_results.dart';
import '../../../widgets/match_card.dart';
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
  late final InternshipService _internshipService = widget.service ?? InternshipService();
  final _searchController = TextEditingController();

  late Future<List<Internship>> _internshipsFuture = _internshipService.fetchAll(filter: _filter);
  Timer? _debounce;

  /// Same three orderings as the web's internships page.
  InternshipFilter _filter = InternshipFilter.topMatches;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _internshipsFuture = _internshipService.fetchAll(query: value.trim(), filter: _filter);
      });
    });
  }

  /// The server does the sorting, so switching ordering re-queries.
  void _onFilterChanged(InternshipFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _internshipsFuture = _internshipService.fetchAll(
        query: _searchController.text.trim(),
        filter: filter,
      );
    });
  }

  Future<void> _refresh() async {
    final future = _internshipService.fetchAll(
      query: _searchController.text.trim(),
      filter: _filter,
    );
    setState(() => _internshipsFuture = future);
    await future;
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
                  _HeaderIconButton(icon: Icons.arrow_back, onTap: () => Navigator.of(context).pop()),
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
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search internships...',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<List<Internship>>(
                        future: _internshipsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError || !snapshot.hasData) {
                            final message = snapshot.error is ApiException
                                ? (snapshot.error as ApiException).message
                                : 'Could not load internships.';
                            return _InlineMessage(text: message, onRetry: _refresh);
                          }

                          final items = snapshot.data!;
                          if (items.isEmpty) {
                            return EmptyResults(
                              title: 'No internships found',
                              hint: _searchController.text.trim().isEmpty
                                  ? 'Check back once new postings are published.'
                                  : 'Try a different keyword.',
                            );
                          }

                          return Column(
                            children: [
                              for (final internship in items) ...[
                                MatchCard(internship: internship),
                                // Only present on the proximity ordering, which
                                // is the only time it's what's being sorted on.
                                if (internship.distanceLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6, left: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.place_outlined,
                                            size: 14, color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          internship.distanceLabel!,
                                          style: const TextStyle(
                                              fontSize: 12, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),
                              ],
                            ],
                          );
                        },
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

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text, this.onRetry});

  final String text;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
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
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.primaryDark, size: 20),
      ),
    );
  }
}
