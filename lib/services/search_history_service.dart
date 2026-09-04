import '../core/api_client.dart';
import '../models/search_history_entry.dart';

/// Which search box a remembered search belongs to. Each one keeps its own
/// list, so postings the student looked for do not mix in with the students a
/// company looked for.
///
/// These strings must match `SearchHistoryService::CONTEXTS` on the server;
/// anything it does not recognise quietly falls back to `global`.
class SearchContext {
  static const global = 'global';
  static const internships = 'internships';
  static const candidates = 'candidates';
  static const applications = 'applications';
  static const placements = 'placements';
  static const records = 'records';
  static const assessments = 'assessments';
}

/// Talks to SearchHistoryController, the same controller the website's
/// dropdown uses. One list per person, so a search typed on the phone is
/// waiting on the website too.
class SearchHistoryService {
  SearchHistoryService({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<List<SearchHistoryEntry>> recent(String context) async {
    final response = await _client.get(
      '/search-history?context=${Uri.encodeQueryComponent(context)}',
      authenticated: true,
    );

    return (response['items'] as List? ?? [])
        .map((e) => SearchHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// A word the person searched for. The server drops anything shorter than
  /// two characters, so half-typed leftovers never reach the list.
  Future<void> recordTerm(String context, String term) async {
    await _client.post('/search-history', {
      'context': context,
      'kind': 'term',
      'term': term,
    }, authenticated: true);
  }

  /// A result the person actually opened. The name and picture are copied
  /// into the row, so the tile still reads correctly later even if the
  /// original record is gone by then.
  Future<void> recordEntity(
    String context, {
    required String entityType,
    required int entityId,
    required String label,
    String? subtitle,
    String? imageUrl,
    String? initials,
  }) async {
    await _client.post('/search-history', {
      'context': context,
      'kind': 'entity',
      'entity_type': entityType,
      'entity_id': entityId,
      'label': label,
      // Yung wala, hindi na ipinapadala - default na lang ang ginagamit ng
      // server para dito.
      'subtitle': ?subtitle,
      'image_url': ?imageUrl,
      'initials': ?initials,
    }, authenticated: true);
  }

  Future<void> forget(int id) async {
    await _client.delete('/search-history/$id', authenticated: true);
  }

  Future<void> clear(String context) async {
    await _client.delete(
      '/search-history/all?context=${Uri.encodeQueryComponent(context)}',
      authenticated: true,
    );
  }
}
