import '../core/api_client.dart';
import '../models/placement.dart';

/// Talks to Api\PlacementController, which reads and writes the same
/// `placements` row as the web app's My Placement page.
class PlacementService {
  final ApiClient _client = ApiClient.instance;

  Future<PlacementSummary> fetchPlacement() async {
    final response = await _client.get(
      '/student/placement',
      authenticated: true,
    );
    return PlacementSummary.fromJson(response);
  }

  /// Logs hours against the placement and returns the refreshed tracker
  /// numbers, plus the same confirmation message the web flashes.
  Future<
    ({
      String message,
      int hoursRendered,
      int progressPercent,
      int hoursRemaining,
    })
  >
  logHours({required double hours, String? remarks}) async {
    final response = await _client.post('/student/placement/log-hours', {
      'hours': hours,
      if (remarks != null && remarks.trim().isNotEmpty)
        'remarks': remarks.trim(),
    }, authenticated: true);

    return (
      message: response['message'] as String? ?? 'Hours logged.',
      hoursRendered: (response['hours_rendered'] as num?)?.toInt() ?? 0,
      progressPercent: (response['progress_percent'] as num?)?.toInt() ?? 0,
      hoursRemaining: (response['hours_remaining'] as num?)?.toInt() ?? 0,
    );
  }
}
