import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/internship.dart';
import '../../models/person_search_result.dart';
import '../../services/internship_service.dart';
import '../../services/people_search_service.dart';
import '../../widgets/empty_results.dart';
import '../../widgets/match_card.dart';
import '../chatbot/chat_destinations.dart';

/// What this screen searches for — internships (the original, and default,
/// behavior) or one kind of account. Matches the web global search's type
/// filter, one tab per type instead of a dropdown.
enum _SearchScope {
  internship('Internships'),
  student('Students'),
  company('Companies'),
  coordinator('Coordinators');

  const _SearchScope(this.label);

  final String label;
}

/// A search-first screen opened by tapping the search bar on Home.
///
/// Internships query the same `/internships?q=` endpoint the browse list
/// uses. Students, companies and coordinators query the same people search
/// (and the same visibility rules) as the web's global search, so a person
/// found here is the same account the web search returns and taps through to
/// the same profile.
class InternshipSearchScreen extends StatefulWidget {
  const InternshipSearchScreen({super.key, this.service, this.peopleService});

  /// Injectable for tests; defaults to the real services.
  final InternshipService? service;
  final PeopleSearchService? peopleService;

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
  late final PeopleSearchService _peopleService = widget.peopleService ?? PeopleSearchService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  Object? _error;
  List<Internship>? _results;
  List<PersonSearchResult>? _peopleResults;

  /// Which tab is active. Internships is the original, and default, behavior.
  _SearchScope _scope = _SearchScope.internship;

  /// Matches the web's default ordering on the internships page.
  InternshipFilter _filter = InternshipFilter.topMatches;

  /// The query the currently displayed results belong to — used so a slow
  /// response for an old query, or a since-abandoned scope, can't overwrite
  /// what's on screen.
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
        _peopleResults = null;
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

  /// Switching tabs re-queries under the new scope rather than clearing the
  /// box, so refining "creatix" from Internships to Companies keeps the text
  /// the student already typed.
  void _onScopeChanged(_SearchScope scope) {
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      _results = null;
      _peopleResults = null;
      _error = null;
    });

    final query = _controller.text.trim();
    if (query.isNotEmpty) _search(query);
  }

  Future<void> _search(String query) async {
    // Captured so a response landing after the student switched tabs (or
    // typed something new) doesn't get applied to the wrong view.
    final scope = _scope;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    bool stillCurrent() => mounted && _scope == scope && _controller.text.trim() == query;

    try {
      if (scope == _SearchScope.internship) {
        final results = await _service.fetchAll(query: query, filter: _filter);
        if (!stillCurrent()) return;
        setState(() {
          _results = results;
          _shownQuery = query;
          _isLoading = false;
        });
        return;
      }

      final results = await _peopleService.search(query: query, type: _personTypeFor(scope));
      if (!stillCurrent()) return;
      setState(() {
        _peopleResults = results;
        _shownQuery = query;
        _isLoading = false;
      });
    } catch (e) {
      if (!stillCurrent()) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  PersonSearchType _personTypeFor(_SearchScope scope) => switch (scope) {
        _SearchScope.student => PersonSearchType.student,
        _SearchScope.company => PersonSearchType.company,
        _SearchScope.coordinator => PersonSearchType.coordinator,
        _SearchScope.internship => PersonSearchType.all,
      };

  void _openPerson(PersonSearchResult result) {
    if (result.screen == null) return;
    final destination = chatDestinationFor(result.screen!, result.screenParams);
    destination?.call(context);
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
          // The ordering menu only makes sense for internships — companies,
          // students and coordinators have no "Top Matches" / "Proximity".
          if (_scope == _SearchScope.internship)
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
              hintText: 'Search ${_scope.label.toLowerCase()}...',
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
      body: Column(
        children: [
          _ScopeTabs(selected: _scope, onSelected: _onScopeChanged),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_scope != _SearchScope.internship) {
      return _buildPeopleBody();
    }

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

  Widget _buildPeopleBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      final message = _error is ApiException
          ? (_error as ApiException).message
          : 'Could not search ${_scope.label.toLowerCase()}.';

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
        children: [
          EmptyResults(icon: Icons.wifi_off, title: 'Search failed', hint: message, padding: EdgeInsets.zero),
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

    final results = _peopleResults;

    if (results == null) {
      return EmptyResults(
        icon: Icons.search,
        title: 'Search ${_scope.label.toLowerCase()}',
        hint: _scope == _SearchScope.student
            ? 'Find students by name, course, or email.'
            : _scope == _SearchScope.company
                ? 'Find companies by name, industry, or city.'
                : 'Find coordinators by name, department, or campus.',
        padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
      );
    }

    if (results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
        children: [
          EmptyResults(
            title: 'No ${_scope.label.toLowerCase()} found',
            hint: 'Try a different keyword.',
            padding: EdgeInsets.zero,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      itemCount: results.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          final count = results.length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$count ${count == 1 ? 'result' : 'results'} for "$_shownQuery"',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          );
        }

        return _PersonResultTile(result: results[index - 1], onTap: _openPerson);
      },
    );
  }
}

class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({required this.selected, required this.onSelected});

  final _SearchScope selected;
  final ValueChanged<_SearchScope> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final scope in _SearchScope.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(scope.label),
                selected: scope == selected,
                onSelected: (_) => onSelected(scope),
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: scope == selected ? FontWeight.bold : FontWeight.normal,
                  color: scope == selected ? Colors.white : AppColors.textDark,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                showCheckmark: false,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonResultTile extends StatelessWidget {
  const _PersonResultTile({required this.result, required this.onTap});

  final PersonSearchResult result;
  final ValueChanged<PersonSearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: result.isNavigable ? () => onTap(result) : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.chipBackground,
                backgroundImage: result.avatarUrl != null ? NetworkImage(result.avatarUrl!) : null,
                child: result.avatarUrl == null
                    ? Text(
                        result.initials,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        if (result.badge != null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.chipBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              result.badge!,
                              style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      result.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                    if (result.meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          result.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
              if (result.isNavigable) const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
