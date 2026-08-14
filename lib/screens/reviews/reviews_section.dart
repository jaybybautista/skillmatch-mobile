import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/review.dart';
import '../../services/review_service.dart';
import '../../widgets/review_thread.dart';
import '../chatbot/chat_destinations.dart';
import 'review_replies_screen.dart';

/// Replaces [review] wherever it sits in a thread, keeping the rest intact.
List<Review> replaceInTree(List<Review> reviews, int id, Review Function(Review) update) {
  return reviews.map((review) {
    if (review.id == id) return update(review);
    if (review.replies.isEmpty) return review;
    return review.copyWith(replies: replaceInTree(review.replies, id, update));
  }).toList();
}

/// The reviews tab: the rating summary, a form to leave one review, and the
/// list of reviews with their reply threads.
///
/// Everything here writes to the same `reviews` rows the website uses, so a
/// review left on the phone shows up on the web page and vice versa.
class ReviewsSection extends StatefulWidget {
  const ReviewsSection({
    super.key,
    required this.reviewableType,
    required this.reviewableId,
    this.service,
  });

  /// 'internship' or 'company'.
  final String reviewableType;
  final int reviewableId;
  final ReviewService? service;

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  late final ReviewService _service = widget.service ?? ReviewService();

  ReviewThread? _thread;
  String? _error;
  bool _isLoading = true;

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
      final thread = await _service.fetchThread(
        reviewableType: widget.reviewableType,
        reviewableId: widget.reviewableId,
      );
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load reviews. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleLike(Review review) async {
    // Applied locally first so the thread doesn't rebuild from scratch for a
    // single tap; a failure re-reads the truth from the server.
    try {
      final result = await _service.toggleLike(review.id);
      if (!mounted) return;
      setState(() {
        _thread = _threadWith(replaceInTree(
          _thread!.reviews,
          review.id,
          (r) => r.copyWith(hasLiked: result.liked, likeCount: result.likeCount),
        ));
      });
    } on ApiException catch (e) {
      _notify(e.message);
      _load();
    }
  }

  ReviewThread _threadWith(List<Review> reviews) {
    final current = _thread!;
    return ReviewThread(
      reviews: reviews,
      summary: current.summary,
      canReview: current.canReview,
      alreadyReviewed: current.alreadyReviewed,
      editWindowMinutes: current.editWindowMinutes,
    );
  }

  Future<void> _openThread(Review root) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReviewRepliesScreen(rootReviewId: root.id, service: _service),
      ),
    );
    // Replies, likes or deletions may all have happened in there.
    if (mounted) _load();
  }

  void _openAuthorProfile(Review review) {
    final screen = review.authorScreen;
    if (screen == null) return;

    final destination = chatDestinationFor(screen, review.authorScreenParams);
    if (destination == null) return;
    destination(context);
  }

  Future<void> _delete(Review review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(review.isReply ? 'Delete reply?' : 'Delete review?'),
        content: Text(
          review.replyCount > 0
              ? 'This will also remove the ${review.replyCount} '
                  '${review.replyCount == 1 ? 'reply' : 'replies'} underneath it.'
              : 'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.delete(review.id);
      _notify('Deleted.');
      _load();
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  Future<void> _edit(Review review) async {
    final edited = await showEditReviewSheet(context, review);
    if (edited == null) return;

    try {
      await _service.edit(reviewId: review.id, content: edited);
      _notify('Updated.');
      _load();
    } on ApiException catch (e) {
      // The window can close between opening the sheet and saving.
      _notify(e.message);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        children: [
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    final thread = _thread!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _SummaryCard(summary: thread.summary),
          const SizedBox(height: 14),
          if (thread.canReview)
            _NewReviewCard(
              onSubmit: (rating, title, content) async {
                try {
                  await _service.postReview(
                    reviewableType: widget.reviewableType,
                    reviewableId: widget.reviewableId,
                    rating: rating,
                    title: title,
                    content: content,
                  );
                  _notify('Review posted.');
                  _load();
                } on ApiException catch (e) {
                  _notify(e.message);
                }
              },
            )
          else if (thread.alreadyReviewed)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAFAF1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'You have already reviewed this. Thank you for your feedback!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF1A7F4B), fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          if (thread.reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No reviews yet. Be the first to share your experience.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            for (final review in thread.reviews)
              ReviewTile(
                review: review,
                showReplies: false,
                onOpenThread: _openThread,
                onLike: _toggleLike,
                onReply: _openThread,
                onAuthorTap: _openAuthorProfile,
                onEdit: _edit,
                onDelete: _delete,
              ),
        ],
      ),
    );
  }
}

/// Opens the edit sheet and returns the new text, or null if cancelled.
Future<String?> showEditReviewSheet(BuildContext context, Review review) {
  final controller = TextEditingController(text: review.content);

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              review.isReply ? 'Edit reply' : 'Edit review',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.of(sheetContext).pop(text);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                summary.average.toStringAsFixed(1),
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= summary.average.round() ? Icons.star : Icons.star_border,
                      size: 13,
                      color: const Color(0xFFF5A623),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.total} ${summary.total == 1 ? 'review' : 'reviews'}',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(
                      children: [
                        Text('$star', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 6,
                              value: summary.total == 0
                                  ? 0
                                  : (summary.ratingCounts[star] ?? 0) / summary.total,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation(Color(0xFFF5A623)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 18,
                          child: Text(
                            '${summary.ratingCounts[star] ?? 0}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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

class _NewReviewCard extends StatefulWidget {
  const _NewReviewCard({required this.onSubmit});

  final Future<void> Function(int rating, String title, String content) onSubmit;

  @override
  State<_NewReviewCard> createState() => _NewReviewCardState();
}

class _NewReviewCardState extends State<_NewReviewCard> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  int _rating = 5;
  bool _isSending = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_content.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    await widget.onSubmit(_rating, _title.text.trim(), _content.text.trim());
    if (!mounted) return;
    _title.clear();
    _content.clear();
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Leave a Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                  icon: Icon(
                    i <= _rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF5A623),
                    size: 26,
                  ),
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Headline (optional)',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _content,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Share your experience, the culture, or advice…',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isSending ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit Review'),
            ),
          ),
        ],
      ),
    );
  }
}
