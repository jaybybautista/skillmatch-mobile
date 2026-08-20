import '../core/api_client.dart';
import '../models/person_search_result.dart';

/// Which kind of account to search for — mirrors the web global search's
/// type filter, minus 'internship' (that already has its own search screen).
enum PersonSearchType {
  all('all', 'All'),
  student('student', 'Students'),
  company('company', 'Companies'),
  coordinator('coordinator', 'Coordinators');

  const PersonSearchType(this.value, this.label);

  final String value;
  final String label;
}

/// Talks to Api\GlobalSearchController@people, which runs the same queries
/// (and the same visibility rules) as the web's global search.
class PeopleSearchService {
  PeopleSearchService({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<List<PersonSearchResult>> search({
    required String query,
    PersonSearchType type = PersonSearchType.all,
  }) async {
    final response = await _client.get(
      '/search/people?q=${Uri.encodeQueryComponent(query)}&type=${type.value}',
      authenticated: true,
    );

    return (response['results'] as List? ?? [])
        .map((e) => PersonSearchResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
