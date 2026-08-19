/// A review or a reply — they are the same `reviews` row on the backend, told
/// apart by [parentId]. A reply carries no rating.
class Review {
  Review({
    required this.id,
    required this.parentId,
    required this.depth,
    required this.replyToName,
    required this.content,
    required this.title,
    required this.rating,
    required this.createdAtHuman,
    required this.authorName,
    required this.authorRole,
    required this.authorAvatarUrl,
    required this.authorInitial,
    required this.authorScreen,
    required this.authorScreenParams,
    required this.isMine,
    required this.likeCount,
    required this.hasLiked,
    required this.canEdit,
    required this.editSecondsRemaining,
    required this.canDelete,
    required this.replyCount,
    required this.replies,
    this.reviewableContext,
  });

  final int id;
  final int? parentId;
  final int depth;

  /// Whose reply this one answers, when it answers another reply rather than
  /// the review itself. Rendered as a blue @mention, which is what lets every
  /// reply share one branch instead of indenting into a staircase.
  final String? replyToName;
  final String content;
  final String? title;
  final int? rating;
  final String createdAtHuman;
  final String authorName;
  final String authorRole;
  final String? authorAvatarUrl;
  final String authorInitial;

  /// Where tapping this author's name or avatar goes — resolved server-side
  /// by ProfileLinkService, the same service that answers people search.
  /// Null when the author has no viewable profile (a deleted account).
  final String? authorScreen;
  final Map<String, dynamic> authorScreenParams;
  final bool isMine;
  final int likeCount;
  final bool hasLiked;

  /// Resolved server-side against the 30-minute window, so the app never has
  /// to reason about clock skew between the phone and the server.
  final bool canEdit;
  final int editSecondsRemaining;
  final bool canDelete;

  /// Replies at every depth beneath this one, not just direct children.
  final int replyCount;
  final List<Review> replies;

  /// "On internship: Backend Intern" when this review was left on a posting
  /// rather than on the company itself. Null otherwise, and only rendered by
  /// lists that mix the two — the company's own profile does, an individual
  /// posting's review tab does not.
  final String? reviewableContext;

  bool get isReply => parentId != null;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      parentId: (json['parent_id'] as num?)?.toInt(),
      depth: (json['depth'] as num?)?.toInt() ?? 0,
      replyToName: json['reply_to_name'] as String?,
      content: json['content'] as String? ?? '',
      title: json['title'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      createdAtHuman: json['created_at_human'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Anonymous',
      authorRole: json['author_role'] as String? ?? 'user',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      authorInitial: json['author_initial'] as String? ?? 'U',
      authorScreen: json['author_screen'] as String?,
      authorScreenParams: (json['author_screen_params'] as Map?)?.cast<String, dynamic>() ?? const {},
      isMine: json['is_mine'] as bool? ?? false,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      hasLiked: json['has_liked'] as bool? ?? false,
      canEdit: json['can_edit'] as bool? ?? false,
      editSecondsRemaining: (json['edit_seconds_remaining'] as num?)?.toInt() ?? 0,
      canDelete: json['can_delete'] as bool? ?? false,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      replies: (json['replies'] as List? ?? [])
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
      reviewableContext: json['reviewable_context'] as String?,
    );
  }

  Review copyWith({
    String? content,
    int? likeCount,
    bool? hasLiked,
    bool? canEdit,
    List<Review>? replies,
    int? replyCount,
  }) {
    return Review(
      id: id,
      parentId: parentId,
      depth: depth,
      replyToName: replyToName,
      content: content ?? this.content,
      title: title,
      rating: rating,
      createdAtHuman: createdAtHuman,
      authorName: authorName,
      authorRole: authorRole,
      authorAvatarUrl: authorAvatarUrl,
      authorInitial: authorInitial,
      authorScreen: authorScreen,
      authorScreenParams: authorScreenParams,
      isMine: isMine,
      likeCount: likeCount ?? this.likeCount,
      hasLiked: hasLiked ?? this.hasLiked,
      canEdit: canEdit ?? this.canEdit,
      editSecondsRemaining: editSecondsRemaining,
      canDelete: canDelete,
      replyCount: replyCount ?? this.replyCount,
      replies: replies ?? this.replies,
      reviewableContext: reviewableContext,
    );
  }
}

/// The rating breakdown shown above the list.
class ReviewSummary {
  ReviewSummary({required this.total, required this.average, required this.ratingCounts});

  final int total;
  final double average;

  /// Star value (1–5) to how many reviews gave it.
  final Map<int, int> ratingCounts;

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final raw = (json['rating_counts'] as Map?) ?? {};
    return ReviewSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      average: (json['average'] as num?)?.toDouble() ?? 0,
      ratingCounts: {
        for (final entry in raw.entries)
          int.tryParse(entry.key.toString()) ?? 0: (entry.value as num?)?.toInt() ?? 0,
      },
    );
  }

  static ReviewSummary empty() => ReviewSummary(total: 0, average: 0, ratingCounts: const {});
}

/// Everything the reviews tab needs in one response.
class ReviewThread {
  ReviewThread({
    required this.reviews,
    required this.summary,
    required this.canReview,
    required this.alreadyReviewed,
    required this.editWindowMinutes,
  });

  final List<Review> reviews;
  final ReviewSummary summary;

  /// False once this student has already reviewed the entity — the web allows
  /// exactly one review each, and so does the app.
  final bool canReview;
  final bool alreadyReviewed;
  final int editWindowMinutes;

  factory ReviewThread.fromJson(Map<String, dynamic> json) {
    return ReviewThread(
      reviews: (json['reviews'] as List? ?? [])
          .map((e) => Review.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] != null
          ? ReviewSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : ReviewSummary.empty(),
      canReview: json['can_review'] as bool? ?? false,
      alreadyReviewed: json['already_reviewed'] as bool? ?? false,
      editWindowMinutes: (json['edit_window_minutes'] as num?)?.toInt() ?? 30,
    );
  }
}
