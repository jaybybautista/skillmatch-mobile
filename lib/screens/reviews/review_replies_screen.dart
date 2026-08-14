import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/review.dart';
import '../../services/review_service.dart';
import '../../widgets/review_thread.dart';
import '../chatbot/chat_destinations.dart';
import 'reviews_section.dart' show replaceInTree, showEditReviewSheet;

/// The full conversation under one review: the review itself at the top, the
/// reply thread beneath it with its branch rails, and a composer pinned to the
/// bottom.
///
/// Replies here are the same `reviews` rows the website threads, so a reply
/// written on the phone appears in the web thread and vice versa.
class ReviewRepliesScreen extends StatefulWidget {
  const ReviewRepliesScreen({super.key, required this.rootReviewId, this.service});

  final int rootReviewId;
  final ReviewService? service;

  @override
  State<ReviewRepliesScreen> createState() => _ReviewRepliesScreenState();
}

class _ReviewRepliesScreenState extends State<ReviewRepliesScreen> {
  late final ReviewService _service = widget.service ?? ReviewService();
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();

  Review? _root;
  String? _error;
  bool _isLoading = true;
  bool _isSending = false;

  /// Which comment the composer is aimed at. Null means the root review.
  Review? _replyingTo;

  /// The "@Name " the composer is currently carrying, so aiming at someone
  /// else swaps it out exactly instead of trying to pattern-match a name that
  /// may itself contain spaces.
  String _mention = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final root = await _service.fetchOne(widget.rootReviewId);
      if (!mounted) return;
      setState(() {
        _root = root;
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
        _error = 'Could not load this thread. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send() async {
    final content = _composer.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await _service.postReply(
        parentId: _replyingTo?.id ?? widget.rootReviewId,
        content: content,
      );
      _composer.clear();
      if (mounted) {
        setState(() {
          _replyingTo = null;
          _mention = '';
        });
      }
      await _load();
    } on ApiException catch (e) {
      _notify(e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleLike(Review review) async {
    try {
      final result = await _service.toggleLike(review.id);
      if (!mounted || _root == null) return;
      setState(() {
        _root = replaceInTree(
          [_root!],
          review.id,
          (r) => r.copyWith(hasLiked: result.liked, likeCount: result.likeCount),
        ).first;
      });
    } on ApiException catch (e) {
      _notify(e.message);
      _load();
    }
  }

  void _openAuthorProfile(Review review) {
    final screen = review.authorScreen;
    if (screen == null) return;

    final destination = chatDestinationFor(screen, review.authorScreenParams);
    if (destination == null) return;
    destination(context);
  }

  /// Aims the composer at [review] and seeds it with that person's @mention,
  /// the way replying to a Facebook comment does. Replying to the review
  /// itself needs no mention — the branch already says who it answers.
  void _startReply(Review review) {
    final isRoot = review.id == widget.rootReviewId;
    final mention = isRoot ? '' : '@${review.authorName} ';

    final typed = _composer.text.startsWith(_mention)
        ? _composer.text.substring(_mention.length)
        : _composer.text;

    setState(() {
      _replyingTo = isRoot ? null : review;
      _mention = mention;
      _composer.text = mention + typed;
      _composer.selection = TextSelection.collapsed(offset: _composer.text.length);
    });

    _composerFocus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      final typed = _composer.text.startsWith(_mention)
          ? _composer.text.substring(_mention.length)
          : _composer.text;
      _replyingTo = null;
      _mention = '';
      _composer.text = typed;
    });
  }

  Future<void> _edit(Review review) async {
    final edited = await showEditReviewSheet(context, review);
    if (edited == null) return;

    try {
      await _service.edit(reviewId: review.id, content: edited);
      _notify('Updated.');
      _load();
    } on ApiException catch (e) {
      _notify(e.message);
      _load();
    }
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
      if (!mounted) return;

      // Deleting the root takes the whole thread with it, so leave the screen.
      if (review.id == widget.rootReviewId) {
        Navigator.of(context).pop();
        return;
      }

      _notify('Deleted.');
      _load();
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: const Text('Replies', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          if (_root != null)
            ReviewComposer(
              controller: _composer,
              focusNode: _composerFocus,
              isSending: _isSending,
              hintText: 'Add a reply or @mention…',
              contextLabel:
                  _replyingTo == null ? null : 'Replying to ${_replyingTo!.authorName}',
              onCancel: _cancelReply,
              onSubmit: _send,
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
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: _load, child: const Text('Retry'))),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          ReviewTile(
            review: _root!,
            onLike: _toggleLike,
            onReply: _startReply,
            onAuthorTap: _openAuthorProfile,
            onEdit: _edit,
            onDelete: _delete,
          ),
          if (_root!.replies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No replies yet. Start the conversation.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
