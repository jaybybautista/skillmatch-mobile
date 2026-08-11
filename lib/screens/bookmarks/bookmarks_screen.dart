import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/internship.dart';
import '../../services/internship_service.dart';
import '../../widgets/match_card.dart';

/// Bookmarked internship postings — GET /api/student/bookmarks, backed by
/// the same saved_internships table the web app's Bookmarks page uses.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final _internshipService = InternshipService();

  bool _isLoading = true;
  Object? _error;
  List<Internship> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _internshipService.fetchBookmarks();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  // Un-bookmarking a card from this screen should remove it immediately,
  // the same way toggling it again elsewhere would — no manual refresh.
  void _handleBookmarkChanged(int internshipId, bool bookmarked) {
    if (bookmarked) return;
    setState(() => _items = _items.where((i) => i.id != internshipId).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 20),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Bookmarks',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
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
                onRefresh: _load,
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_error != null) {
                      final message = _error is ApiException ? (_error as ApiException).message : 'Could not load your bookmarks.';
                      return ListView(
                        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                        children: [
                          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                          const SizedBox(height: 12),
                          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
                        ],
                      );
                    }

                    if (_items.isEmpty) {
                      return ListView(
                        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
                        children: const [
                          Icon(Icons.bookmark_border, size: 40, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            "You haven't bookmarked any internships yet.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      children: [
                        for (final internship in _items) ...[
                          MatchCard(
                            key: ValueKey(internship.id),
                            internship: internship,
                            onBookmarkChanged: (bookmarked) => _handleBookmarkChanged(internship.id, bookmarked),
                            onReturned: _load,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
