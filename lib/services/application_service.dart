import '../core/api_client.dart';
import '../models/application.dart';

/// Talks to Api\ApplicationController, which reads the same `applications`
/// rows (and applies the same assessment-window rules) as the web page.
class ApplicationService {
  final ApiClient _client = ApiClient.instance;

  Future<ApplicationsResult> fetchApplications({String query = ''}) async {
    final path = query.trim().isEmpty
        ? '/student/applications'
        : '/student/applications?q=${Uri.encodeQueryComponent(query.trim())}';

    final response = await _client.get(path, authenticated: true);
    return ApplicationsResult.fromJson(response);
  }

  /// The 15-second poll, mirroring the web layout's own status check.
  Future<ApplicationsStatusSnapshot> fetchStatusSnapshot() async {
    final response = await _client.get(
      '/student/status-check',
      authenticated: true,
    );
    return ApplicationsStatusSnapshot.fromJson(response);
  }
}
