import '../core/api_client.dart';
import '../models/review.dart';

/// Talks to Api\ReviewController, which writes the same `reviews` and
/// `review_reactions` rows the website uses and applies the same rules
/// through the shared ReviewService — one review per entity, a 30-minute
/// edit window, and threaded replies.
class ReviewService {
  ReviewService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// [reviewableType] is 'internship' or 'company'; the backend maps it to the
  /// matching model class, the same way the web forms post it.
  Future<ReviewThread> fetchThread({
    required String reviewableType,
    required int reviewableId,
  }) async {
    final response = await _client.get(
      '/reviews?reviewable_type=$reviewableType&reviewable_id=$reviewableId',
      authenticated: true,
    );

    return ReviewThread.fromJson(response);
  }

  /// One review with its whole reply subtree. The backend walks up to the
  /// root, so passing any reply's id returns the conversation it belongs to.
  Future<Review> fetchOne(int reviewId) async {
    final response = await _client.get(
      '/reviews/$reviewId',
      authenticated: true,
    );
    return Review.fromJson(response['review'] as Map<String, dynamic>);
  }

  Future<Review> postReview({
    required String reviewableType,
    required int reviewableId,
    required String content,
    required int rating,
    String? title,
  }) async {
    final response = await _client.post('/reviews', {
      'reviewable_type': reviewableType,
      'reviewable_id': reviewableId,
      'content': content,
      'rating': rating,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
    }, authenticated: true);

    return Review.fromJson(response['review'] as Map<String, dynamic>);
  }

  Future<Review> postReply({
    required int parentId,
    required String content,
  }) async {
    final response = await _client.post('/reviews', {
      'parent_id': parentId,
      'content': content,
    }, authenticated: true);

    return Review.fromJson(response['review'] as Map<String, dynamic>);
  }

  /// Throws [ApiException] with the server's message when the 30-minute
  /// window has already closed.
  Future<Review> edit({required int reviewId, required String content}) async {
    final response = await _client.put('/reviews/$reviewId', {
      'content': content,
    }, authenticated: true);

    return Review.fromJson(response['review'] as Map<String, dynamic>);
  }

  Future<void> delete(int reviewId) async {
    await _client.delete('/reviews/$reviewId', authenticated: true);
  }

  /// Returns the new (liked, count) pair after toggling.
  Future<({bool liked, int likeCount})> toggleLike(int reviewId) async {
    final response = await _client.post('/reviews/$reviewId/react', {
      'reaction_type': 'like',
    }, authenticated: true);

    return (
      liked: response['reacted'] as bool? ?? false,
      likeCount: (response['like_count'] as num?)?.toInt() ?? 0,
    );
  }
}
