import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/review.dart';

/// Colour of the rail that ties replies to the review they belong to.
const _railColor = Color(0xFFD7DCE5);

/// Width of the gutter the branch rail lives in.
const double _railWidth = 26;

/// Where down the row the elbow turns in — level with the avatar's middle.
const double _elbowY = 20;

/// Actions a review row can raise. The screen that owns the data performs
/// them, so the tiles stay stateless and re-render from fresh data.
typedef ReviewAction = void Function(Review review);

/// Draws the branch rail: a vertical line down the gutter with a rounded elbow
/// turning into this reply, continuing past it only when another reply
/// follows. The last reply's rail stops at its own elbow, which is what
/// visually closes the branch.
class _BranchRailPainter extends CustomPainter {
  const _BranchRailPainter({required this.isLast});

  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _railColor
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const x = 1.0;
    const radius = 10.0;

    canvas.drawLine(
      const Offset(x, 0),
      Offset(x, isLast ? _elbowY - radius : size.height),
      paint,
    );

    final elbow = Path()
      ..moveTo(x, _elbowY - radius)
      ..quadraticBezierTo(x, _elbowY, x + radius, _elbowY)
      ..lineTo(size.width, _elbowY);
    canvas.drawPath(elbow, paint);
  }

  @override
  bool shouldRepaint(_BranchRailPainter oldDelegate) => oldDelegate.isLast != isLast;
}

/// One review with its replies in a single branch beneath it.
///
/// A thread is exactly one branch deep. Replies to replies still exist — the
/// backend flattens them into the same branch and gives each one the name it
/// answers, shown as a blue @mention. Indenting every answer one step further
/// turned a long back-and-forth into a staircase that ran out of width.
class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.review,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    this.showReplies = true,
    this.onOpenThread,
  });

  final Review review;
  final ReviewAction onLike;
  final ReviewAction onReply;
  final ReviewAction onEdit;
  final ReviewAction onDelete;

  /// False on the reviews list, where a "N replies" button opens the thread
  /// instead of expanding it inline.
  final bool showReplies;
  final ReviewAction? onOpenThread;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReviewBody(
            review: review,
            onLike: onLike,
            onReply: onReply,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
          if (showReplies)
            for (var i = 0; i < review.replies.length; i++)
              ReplyRow(
                review: review.replies[i],
                isLastSibling: i == review.replies.length - 1,
                onLike: onLike,
                onReply: onReply,
                onEdit: onEdit,
                onDelete: onDelete,
              )
          else if (review.replyCount > 0 && onOpenThread != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: () => onOpenThread!(review),
                icon: const Icon(Icons.forum_outlined, size: 16),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                label: Text(
                  review.replyCount == 1 ? '1 reply' : '${review.replyCount} replies',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One reply sitting in the branch, with its rail.
class ReplyRow extends StatelessWidget {
  const ReplyRow({
    super.key,
    required this.review,
    required this.isLastSibling,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  final Review review;

  /// Whether a reply follows this one, which decides if its rail carries on.
  final bool isLastSibling;
  final ReviewAction onLike;
  final ReviewAction onReply;
  final ReviewAction onEdit;
  final ReviewAction onDelete;

  @override
  Widget build(BuildContext context) {
    // The rail is painted in the gutter behind the content, so the Stack still
    // takes its height from the reply itself and can never overlap the text.
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _railWidth,
          child: CustomPaint(painter: _BranchRailPainter(isLast: isLastSibling)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: _railWidth + 4, top: 6),
          child: ReviewBody(
            review: review,
            onLike: onLike,
            onReply: onReply,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}

/// The avatar, header, text and action row shared by reviews and replies.
class ReviewBody extends StatelessWidget {
  const ReviewBody({
    super.key,
    required this.review,
    required this.onLike,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  final Review review;
  final ReviewAction onLike;
  final ReviewAction onReply;
  final ReviewAction onEdit;
  final ReviewAction onDelete;

  @override
  Widget build(BuildContext context) {
    final isReply = review.isReply;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: isReply ? 13 : 18,
          backgroundColor: AppColors.chipBackground,
          backgroundImage:
              review.authorAvatarUrl != null ? NetworkImage(review.authorAvatarUrl!) : null,
          child: review.authorAvatarUrl == null
              ? Text(
                  review.authorInitial,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: isReply ? 11 : 14,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      review.authorName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isReply ? 12.5 : 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${review.createdAtHuman}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
              if (!isReply && review.rating != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= review.rating! ? Icons.star : Icons.star_border,
                          size: 14,
                          color: const Color(0xFFF5A623),
                        ),
                    ],
                  ),
                ),
              if (!isReply && (review.title?.isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    review.title!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text.rich(
                  TextSpan(
                    children: [
                      // Names who is being answered, so a reply reads on its
                      // own without needing its own indent level.
                      if (review.replyToName != null)
                        TextSpan(
                          text: '@${review.replyToName} ',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      TextSpan(text: review.content),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: isReply ? 13 : 13.5,
                    height: 1.4,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    _IconAction(
                      icon: review.hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: review.hasLiked ? AppColors.primary : AppColors.textMuted,
                      label: review.likeCount > 0 ? '${review.likeCount}' : null,
                      tooltip: 'Like',
                      onTap: () => onLike(review),
                    ),
                    const SizedBox(width: 4),
                    _IconAction(
                      icon: Icons.mode_comment_outlined,
                      color: AppColors.textMuted,
                      tooltip: 'Reply',
                      onTap: () => onReply(review),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (review.canEdit || review.canDelete)
          _MoreMenu(
            review: review,
            onEdit: () => onEdit(review),
            onDelete: () => onDelete(review),
          )
        else
          const SizedBox(width: 8),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              if (label != null) ...[
                const SizedBox(width: 5),
                Text(label!, style: TextStyle(fontSize: 12, color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.review, required this.onEdit, required this.onDelete});

  final Review review;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      tooltip: 'More',
      onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (context) => [
        if (review.canEdit)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 18),
                const SizedBox(width: 10),
                // The remaining-time suffix can outgrow a narrow menu, so it
                // is allowed to shrink rather than overflow the row.
                Flexible(
                  child: Text(
                    'Edit · ${_remainingLabel(review.editSecondsRemaining)} left',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (review.canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                SizedBox(width: 10),
                Text('Delete', style: TextStyle(color: AppColors.danger)),
              ],
            ),
          ),
      ],
    );
  }

  static String _remainingLabel(int seconds) {
    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      return '$minutes min';
    }
    return '${seconds}s';
  }
}

/// The bottom composer: a rounded field and a send button.
class ReviewComposer extends StatelessWidget {
  const ReviewComposer({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSubmit,
    required this.isSending,
    this.focusNode,
    this.contextLabel,
    this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final VoidCallback onSubmit;
  final bool isSending;

  /// e.g. "Replying to Maria", shown above the field.
  final String? contextLabel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (contextLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          contextLabel!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                      if (onCancel != null)
                        InkWell(
                          onTap: onCancel,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: hintText,
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: isSending ? null : onSubmit,
                    icon: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: AppColors.primary),
                    tooltip: 'Send',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
