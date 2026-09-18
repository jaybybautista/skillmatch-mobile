import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../models/internship.dart';
import '../models/match_details.dart';
import 'empty_results.dart';
import 'match_card.dart';

/// A lazily loaded list of internship cards.
///
/// Lives inside a parent scroll view (the screen's `ListView`) and watches
/// that view's [controller]: when the student scrolls near the bottom the
/// next page is fetched and appended, with a small spinner row while it
/// loads. Changing [loader] (a new search or ordering) starts over from
/// page one. [refreshToken] forces a reload with the same loader (pull to
/// refresh).
class PagedInternshipList extends StatefulWidget {
  const PagedInternshipList({
    super.key,
    required this.controller,
    required this.loader,
    this.refreshToken = 0,
    this.emptyTitle = 'No internships found',
    this.emptyHint,
    this.errorText = 'Could not load internships.',
    this.showDistance = false,
    this.onOpen,
    this.showBookmark = true,
  });

  /// The scroll controller of the enclosing scroll view.
  final ScrollController controller;

  /// Fetches one page; page numbers start at 1.
  final Future<InternshipPage<Internship>> Function(int page) loader;
  final int refreshToken;
  final String emptyTitle;
  final String? emptyHint;
  final String errorText;

  /// Shows the distance line under a card (proximity ordering).
  final bool showDistance;
  final void Function(Internship internship)? onOpen;
  final bool showBookmark;

  @override
  State<PagedInternshipList> createState() => _PagedInternshipListState();
}

class _PagedInternshipListState extends State<PagedInternshipList> {
  final List<Internship> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _initial = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    _reset();
  }

  @override
  void didUpdateWidget(covariant PagedInternshipList old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    if (old.loader != widget.loader || old.refreshToken != widget.refreshToken) {
      _reset();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _reset() {
    _generation++;
    _items.clear();
    _page = 0;
    _hasMore = true;
    _error = null;
    _initial = true;
    _loading = false;
    _loadMore();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final position = widget.controller.position;
    if (position.pixels >= position.maxScrollExtent - 320) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await widget.loader(_page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _page = page.page;
        _hasMore = page.hasMore && page.items.isNotEmpty;
        _loading = false;
        _initial = false;
      });
      // A short first page may not fill the screen; keep going until it does
      // or the server runs out.
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _initial = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = widget.errorText;
        _loading = false;
        _initial = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initial && _loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty && _error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
            TextButton(onPressed: _reset, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return EmptyResults(
        title: widget.emptyTitle,
        hint: widget.emptyHint ?? 'Check back once new postings are published.',
      );
    }

    return Column(
      children: [
        for (final internship in _items) ...[
          MatchCard(
            internship: internship,
            onOpen: widget.onOpen == null ? null : () => widget.onOpen!(internship),
            showBookmark: widget.showBookmark,
          ),
          if (widget.showDistance && internship.distanceLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(internship.distanceLabel!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                TextButton(onPressed: _loadMore, child: const Text('Load more')),
              ],
            ),
          )
        else if (!_hasMore && _items.length > 3)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text("You've seen every posting.", style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
      ],
    );
  }
}
