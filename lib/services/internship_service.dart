import '../core/api_client.dart';
import '../models/internship.dart';
import '../models/internship_detail.dart';
import '../models/match_details.dart';

/// Talks to Api\InternshipController — real internship postings and the
/// real AI-computed match scores, not placeholder data.
class InternshipService {
  final ApiClient _client = ApiClient.instance;

  Future<List<Internship>> fetchRecommendations({int limit = 5}) async {
    return (await fetchRecommendationsPage(page: 1, perPage: limit)).items;
  }

  /// One page of the ranked recommendations (lazy loading on Home).
  Future<InternshipPage<Internship>> fetchRecommendationsPage({
    int page = 1,
    int perPage = 5,
  }) async {
    final response = await _client.get(
      '/internships/recommendations?page=$page&per_page=$perPage',
      authenticated: true,
    );
    return _page(response, page);
  }

  InternshipPage<Internship> _page(Map<String, dynamic> response, int page) {
    return InternshipPage(
      items: (response['internships'] as List)
          .map((e) => Internship.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: response['has_more'] as bool? ?? false,
      page: (response['page'] as num?)?.toInt() ?? page,
    );
  }

  /// The "Why this match" sheet: the same breakdown the web shows (tier,
  /// coverage, evaluation matrix, skills you have / are missing, preferred
  /// applicants, AI explanation).
  Future<MatchDetails> fetchMatchDetails(int id) async {
    final response = await _client.get('/internships/$id/match-details', authenticated: true);
    return MatchDetails.fromJson(response);
  }

  /// Asks the AI to restate the matrix in plain words. Cached on the server
  /// until the score changes. Returns (text, "just now" / "3 days ago").
  Future<(String, String?)> explainMatch(int id) async {
    final response = await _client.postLong('/internships/$id/explain-match', {}, authenticated: true);
    return (response['explanation'] as String? ?? '', response['explained_at'] as String?);
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
    return (await fetchAllPage(query: query, filter: filter, page: 1, perPage: 50)).items;
  }

  /// One page of the browse list, for lazy loading while scrolling.
  Future<InternshipPage<Internship>> fetchAllPage({
    String query = '',
    InternshipFilter filter = InternshipFilter.topMatches,
    int page = 1,
    int perPage = 10,
  }) async {
    final params = <String, String>{
      'filter': filter.value,
      'page': '$page',
      'per_page': '$perPage',
    };
    if (query.isNotEmpty) params['q'] = query;

    final path = '/internships?${Uri(queryParameters: params).query}';
    final response = await _client.get(path, authenticated: true);
    return _page(response, page);
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
