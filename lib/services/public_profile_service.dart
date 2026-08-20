import '../core/api_client.dart';
import '../models/public_profile.dart';

/// Talks to Api\PublicProfileController — the same read-only detail the web's
/// search-result click-throughs show.
class PublicProfileService {
  PublicProfileService({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<StudentPublicProfile> fetchStudent(int studentId) async {
    final response = await _client.get(
      '/students/$studentId/profile',
      authenticated: true,
    );
    return StudentPublicProfile.fromJson(response);
  }

  Future<CompanyPublicProfile> fetchCompany(int companyId) async {
    final response = await _client.get(
      '/companies/$companyId/profile',
      authenticated: true,
    );
    return CompanyPublicProfile.fromJson(response);
  }

  Future<CoordinatorPublicProfile> fetchCoordinator(int coordinatorId) async {
    final response = await _client.get(
      '/coordinators/$coordinatorId/profile',
      authenticated: true,
    );
    return CoordinatorPublicProfile.fromJson(response);
  }
}
