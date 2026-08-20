import '../core/api_client.dart';
import '../models/company_record.dart';

/// Talks to Api\CompanyRecordsController, which shares CompanyRecordsService
/// with the website's Records pages — so the same filters match the same rows
/// and the counters agree on both platforms.
///
/// Read-only: these are reports. Anything that changes a row is done on the
/// screen that owns it.
class CompanyRecordsService {
  final ApiClient _client = ApiClient.instance;

  /// The four counters plus what the filters offer.
  Future<RecordsOverview> fetchOverview() async {
    final response = await _client.get('/company/records', authenticated: true);
    return RecordsOverview.fromJson(response);
  }

  Future<List<ApplicationRecord>> fetchApplications({
    String status = '',
    int? internshipId,
    String query = '',
  }) async {
    final response = await _client.get(
      '/company/records/applications${_query({'status': status, 'internship_id': internshipId?.toString() ?? '', 'q': query})}',
      authenticated: true,
    );

    return (response['records'] as List? ?? const [])
        .map((e) => ApplicationRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AssessmentRecord>> fetchAssessments({
    int? internshipId,
    String query = '',
  }) async {
    final response = await _client.get(
      '/company/records/assessments${_query({'internship_id': internshipId?.toString() ?? '', 'q': query})}',
      authenticated: true,
    );

    return (response['records'] as List? ?? const [])
        .map((e) => AssessmentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PlacementRecord>> fetchPlacements({
    String status = '',
    String query = '',
  }) async {
    final response = await _client.get(
      '/company/records/placements${_query({'status': status, 'q': query})}',
      authenticated: true,
    );

    return (response['records'] as List? ?? const [])
        .map((e) => PlacementRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Builds a query string from the entries that actually carry a value, so
  /// an unset filter is absent rather than sent as an empty string the
  /// backend would have to special-case.
  String _query(Map<String, String> params) {
    final pairs = params.entries
        .where((e) => e.value.trim().isNotEmpty)
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value.trim())}')
        .toList();

    return pairs.isEmpty ? '' : '?${pairs.join('&')}';
  }
}
