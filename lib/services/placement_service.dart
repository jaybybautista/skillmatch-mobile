import '../core/api_client.dart';
import '../models/placement.dart';

/// Talks to Api\PlacementController, which reads the same `placements` row
/// as the web app's My Placement page.
///
/// Read-only, because the record is the coordinator's: they create it, set
/// the dates and the required hours, record the hours rendered, and write
/// the remarks and the evaluation. Nothing a student does from here changes
/// it, which is also true of the web page.
class PlacementService {
  final ApiClient _client = ApiClient.instance;

  Future<PlacementSummary> fetchPlacement() async {
    final response = await _client.get(
      '/student/placement',
      authenticated: true,
    );
    return PlacementSummary.fromJson(response);
  }
}
