import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:skillmatch/models/review.dart';
import 'package:skillmatch/screens/reviews/reviews_section.dart';
import 'package:skillmatch/widgets/review_thread.dart';

Map<String, dynamic> _json({
  required int id,
  int? parentId,
  String content = 'text',
  String author = 'Someone',
  int? rating,
  String? replyToName,
  bool canEdit = false,
  int editSeconds = 0,
  int replyCount = 0,
  List<Map<String, dynamic>> replies = const [],
}) {
  return {
    'id': id,
    'parent_id': parentId,
    'depth': parentId == null ? 0 : 1,
    'reply_to_name': replyToName,
    'content': content,
    'title': null,
    'rating': rating,
    'created_at_human': '2 minutes ago',
    'author_name': author,
    'author_role': 'student',
    'author_avatar_url': null,
    'author_initial': author.substring(0, 1),
    'is_mine': canEdit,
    'like_count': 0,
    'has_liked': false,
    'can_edit': canEdit,
    'edit_seconds_remaining': editSeconds,
    'can_delete': canEdit,
    'reply_count': replyCount,
    'replies': replies,
  };
}

void main() {
  group('Review model', () {
    test('parses a nested thread and keeps reply depth', () {
      final review = Review.fromJson(_json(
        id: 1,
        rating: 4,
        replyCount: 2,
        replies: [
          _json(id: 2, parentId: 1, content: 'first reply', replies: [
            _json(id: 3, parentId: 2, content: 'nested reply'),
          ]),
        ],
      ));

      expect(review.isReply, isFalse);
      expect(review.rating, 4);
      expect(review.replies, hasLength(1));
      expect(review.replies.first.isReply, isTrue);
      expect(review.replies.first.replies.single.content, 'nested reply');
    });

    test('a reply carries no rating', () {
      final reply = Review.fromJson(_json(id: 2, parentId: 1));
      expect(reply.rating, isNull);
      expect(reply.isReply, isTrue);
    });

    test('summary tolerates string-keyed rating counts from JSON', () {
      final summary = ReviewSummary.fromJson({
        'total': 3,
        'average': 4.3,
        'rating_counts': {'5': 2, '4': 1, '3': 0, '2': 0, '1': 0},
      });

      expect(summary.total, 3);
      expect(summary.ratingCounts[5], 2);
      expect(summary.ratingCounts[4], 1);
    });
  });

  group('replaceInTree', () {
    test('updates a deeply nested reply without touching its siblings', () {
      final root = Review.fromJson(_json(
        id: 1,
        replies: [
          _json(id: 2, parentId: 1, content: 'sibling'),
          _json(id: 3, parentId: 1, content: 'target', replies: [
            _json(id: 4, parentId: 3, content: 'deep'),
          ]),
        ],
      ));

      final updated = replaceInTree(
        [root],
        4,
        (r) => r.copyWith(hasLiked: true, likeCount: 7),
      ).single;

      expect(updated.replies[0].content, 'sibling');
      expect(updated.replies[0].hasLiked, isFalse);

      final deep = updated.replies[1].replies.single;
      expect(deep.hasLiked, isTrue);
      expect(deep.likeCount, 7);
    });
  });

  group('ReviewTile', () {
    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );

    testWidgets('offers no edit menu once the window has closed', (tester) async {
      final review = Review.fromJson(_json(id: 1, canEdit: false));

      await tester.pumpWidget(wrap(ReviewTile(
        review: review,
        onLike: (_) {},
        onReply: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      )));

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('shows the remaining edit time while the window is open', (tester) async {
      final review = Review.fromJson(_json(id: 1, canEdit: true, editSeconds: 22 * 60));

      await tester.pumpWidget(wrap(ReviewTile(
        review: review,
        onLike: (_) {},
        onReply: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      )));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Edit · 22 min left'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('the list collapses replies behind a count button', (tester) async {
      var opened = 0;
      final review = Review.fromJson(_json(
        id: 1,
        replyCount: 3,
        replies: [_json(id: 2, parentId: 1, content: 'hidden reply')],
      ));

      await tester.pumpWidget(wrap(ReviewTile(
        review: review,
        showReplies: false,
        onOpenThread: (_) => opened++,
        onLike: (_) {},
        onReply: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      )));

      expect(find.text('hidden reply'), findsNothing);
      expect(find.text('3 replies'), findsOneWidget);

      await tester.tap(find.text('3 replies'));
      expect(opened, 1);
    });

    testWidgets('every reply sits in one branch, never a nested one', (tester) async {
      // The shape the backend now sends: a reply-to-a-reply is hoisted into
      // the same branch and carries the name it answers instead.
      final review = Review.fromJson(_json(
        id: 1,
        content: 'root review',
        replyCount: 2,
        replies: [
          _json(id: 2, parentId: 1, author: 'Ana', content: 'first reply'),
          _json(id: 3, parentId: 2, author: 'Ben', content: 'answering Ana', replyToName: 'Ana'),
        ],
      ));

      await tester.pumpWidget(wrap(ReviewTile(
        review: review,
        onLike: (_) {},
        onReply: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      )));

      expect(find.text('root review'), findsOneWidget);
      expect(find.text('first reply'), findsOneWidget);

      // Both replies are direct children of the single branch — no laddering.
      final rows = tester.widgetList<ReplyRow>(find.byType(ReplyRow)).toList();
      expect(rows, hasLength(2));
      expect(rows.last.isLastSibling, isTrue);
      expect(rows.first.isLastSibling, isFalse);

      for (final row in rows) {
        expect(
          find.descendant(of: find.byWidget(row), matching: find.byType(ReplyRow)),
          findsNothing,
          reason: 'a reply must not contain another ReplyRow',
        );
      }
    });

    testWidgets('a reply answering another reply shows a blue @mention', (tester) async {
      final review = Review.fromJson(_json(
        id: 1,
        replies: [
          _json(id: 2, parentId: 1, author: 'Ana', content: 'plain reply'),
          _json(id: 3, parentId: 2, author: 'Ben', content: 'answering', replyToName: 'Ana'),
        ],
      ));

      await tester.pumpWidget(wrap(ReviewTile(
        review: review,
        onLike: (_) {},
        onReply: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      )));

      final texts = tester.widgetList<RichText>(find.byType(RichText));
      final mentions = texts
          .map((t) => t.text.toPlainText())
          .where((s) => s.startsWith('@Ana '))
          .toList();

      expect(mentions, hasLength(1));
      expect(mentions.single, '@Ana answering');

      // The reply that answers the review itself carries no mention.
      expect(
        texts.map((t) => t.text.toPlainText()).where((s) => s == 'plain reply'),
        hasLength(1),
      );
    });

    testWidgets('replying seeds the composer with the author @mention', (tester) async {
      // Mirrors what ReviewRepliesScreen._startReply does: swap the mention it
      // is carrying for the new one, keeping anything already typed.
      final controller = TextEditingController();
      var mention = '';

      void startReply(String? authorName) {
        final next = authorName == null ? '' : '@$authorName ';
        final typed = controller.text.startsWith(mention)
            ? controller.text.substring(mention.length)
            : controller.text;
        mention = next;
        controller.text = next + typed;
      }

      startReply('Ana Cruz');
      expect(controller.text, '@Ana Cruz ');

      controller.text = '${controller.text}thanks for this';
      expect(controller.text, '@Ana Cruz thanks for this');

      // Re-aiming at someone else swaps only the mention, even though the
      // previous name contained a space.
      startReply('Ben Santos');
      expect(controller.text, '@Ben Santos thanks for this');

      // Replying to the review itself drops the mention entirely.
      startReply(null);
      expect(controller.text, 'thanks for this');

      controller.dispose();
    });

    testWidgets('tapping the like icon raises the action', (tester) async {
      Review? liked;
      final review = Review.fromJson(_json(id: 1));

      await tester.pumpWidget(wrap(ReviewTile(
        review: review,
        onLike: (r) => liked = r,
        onReply: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
      )));

      await tester.tap(find.byIcon(Icons.thumb_up_outlined));
      expect(liked?.id, 1);
    });
  });
}
