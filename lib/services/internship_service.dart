import '../core/api_client.dart';
import '../models/internship.dart';
import '../models/internship_detail.dart';

/// Talks to Api\InternshipController — real internship postings and the
/// real AI-computed match scores, not placeholder data.
class InternshipService {
  final ApiClient _client = ApiClient.instance;

  Future<List<Internship>> fetchRecommendations({int limit = 5}) async {
    final response = await _client.get(
      '/internships/recommendations?limit=$limit',
      authenticated: true,
    );
    return (response['internships'] as List)
        .map((e) => Internship.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Browse or search postings.
  ///
  /// [filter] is one of the web's three orderings — `all` (newest first),
  /// `top_matches` (best fit first) or `proximity` (nearest first). The server
  /// does the sorting, so both platforms rank identically.
  Future<List<Internship>> fetchAll({
    String query = '',
    InternshipFilter filter = InternshipFilter.topMatches,
  }) async {
    final params = <String, String>{'filter': filter.value};
    if (query.isNotEmpty) params['q'] = query;

    final path = '/internships?${Uri(queryParameters: params).query}';
    final response = await _client.get(path, authenticated: true);
    return (response['internships'] as List)
        .map((e) => Internship.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Recomputes match scores for the current student against every open
  /// internship — mirrors the web dashboard's "Refresh Matches" action.
  Future<void> refreshMatches() async {
    await _client.post('/internships/refresh-matches', {}, authenticated: true);
  }

  Future<List<Internship>> fetchBookmarks() async {
    final response = await _client.get(
      '/student/bookmarks',
      authenticated: true,
    );
    return (response['internships'] as List)
        .map((e) => Internship.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InternshipDetail> fetchDetail(int id) async {
    final response = await _client.get('/internships/$id', authenticated: true);
    return InternshipDetail.fromJson(response);
  }

  /// Returns the new bookmarked state.
  Future<bool> toggleBookmark(int id) async {
    final response = await _client.post(
      '/internships/$id/bookmark',
      {},
      authenticated: true,
    );
    return response['bookmarked'] as bool;
  }

  Future<void> apply(int id) async {
    await _client.post('/internships/$id/apply', {}, authenticated: true);
  }
}
