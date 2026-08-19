import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/app_theme.dart';
import '../../../models/internship.dart';
import '../../../services/internship_service.dart';
import '../../../widgets/empty_results.dart';
import '../../../widgets/match_card.dart';

/// A search-first screen for internship postings, opened by tapping the search
/// bar on Home.
///
/// It queries the same `/internships?q=` endpoint the browse list uses, so a
/// posting found here is the same record the web search returns.
class InternshipSearchScreen extends StatefulWidget {
  const InternshipSearchScreen({super.key, this.service});

  /// Injectable for tests; defaults to the real service.
  final InternshipService? service;

  @override
  State<InternshipSearchScreen> createState() => _InternshipSearchScreenState();
}

/// The web's three orderings, as a dropdown hung off a top-bar button.
///
/// Shared by the search screen and the Top Matches list so both offer the same
/// choices from the same control, and neither spends a row of the screen on
/// filter chips.
class InternshipFilterButton extends StatelessWidget {
  const InternshipFilterButton({
    super.key,
    required this.selected,
    required this.onChanged,
    this.onDark = false,
  });

  final InternshipFilter selected;
  final ValueChanged<InternshipFilter> onChanged;

  /// True when the button sits on the dark header (Top Matches), where it is
  /// drawn as a white circle rather than a bare icon.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<InternshipFilter>(
      onSelected: onChanged,
      initialValue: selected,
      tooltip: 'Sort internships',
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      itemBuilder: (context) => [
        for (final filter in InternshipFilter.values)
          PopupMenuItem(
            value: filter,
            child: Row(
              children: [
                Icon(
                  filter == selected ? Icons.check : null,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                    fontWeight: filter == selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: onDark
          ? Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.tune, color: AppColors.primary, size: 20),
            )
          : const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.tune, color: AppColors.primary),
            ),
    );
  }
}

class _InternshipSearchScreenState extends State<InternshipSearchScreen> {
  late final InternshipService _service = widget.service ?? InternshipService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  Object? _error;
  List<Internship>? _results;

  /// Matches the web's default ordering on the internships page.
  InternshipFilter _filter = InternshipFilter.topMatches;

  /// The query the currently displayed [_results] belong to — used so a slow
  /// response for an old query can't overwrite a newer one.
  String _shownQuery = '';

  @override
  void initState() {
    super.initState();
    // The student tapped a search bar to get here, so the keyboard should
    // already be up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _results = null;
        _error = null;
        _isLoading = false;
        _shownQuery = '';
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value.trim()));
  }

  /// Changing the ordering re-queries, since the server does the sorting.
  void _onFilterChanged(InternshipFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);

    final query = _controller.text.trim();
    if (query.isNotEmpty) _search(query);
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _service.fetchAll(query: query, filter: _filter);
      if (!mounted || _controller.text.trim() != query) return;

      setState(() {
        _results = results;
        _shownQuery = query;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        actions: [
          InternshipFilterButton(selected: _filter, onChanged: _onFilterChanged),
        ],
        title: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              _debounce?.cancel();
              if (value.trim().isNotEmpty) _search(value.trim());
            },
            decoration: InputDecoration(
              hintText: 'Search internships...',
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                        _focusNode.requestFocus();
                      },
                    ),
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
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final message = _error is ApiException
          ? (_error as ApiException).message
          : 'Could not search internships.';

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
        children: [
          EmptyResults(
            icon: Icons.wifi_off,
            title: 'Search failed',
            hint: message,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => _search(_controller.text.trim()),
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    final results = _results;

    // Nothing typed yet — a blank canvas rather than a premature "no results".
    if (results == null) {
      return const EmptyResults(
        icon: Icons.search,
        title: 'Search internships',
        hint: 'Find postings by title, company, or skill.',
        padding: EdgeInsets.fromLTRB(32, 72, 32, 32),
      );
    }

    if (results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
        children: const [
          EmptyResults(
            title: 'No internships found',
            hint: 'Try a different keyword.',
            padding: EdgeInsets.zero,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: results.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          final count = results.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$count ${count == 1 ? 'result' : 'results'} for "$_shownQuery" · ${_filter.label}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          );
        }

        final internship = results[index - 1];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MatchCard(internship: internship),
            // Distance only comes back on the proximity filter, so this shows
            // exactly when it's the thing being sorted on.
            if (internship.distanceLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      internship.distanceLabel!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
