import '../core/api_client.dart';
import '../models/company_settings.dart';

/// Talks to Api\CompanySettingsController, which shares
/// CompanySettingsService with the website's settings page — so the account
/// credentials, the password rules and the recruitment preferences are the
/// same rows and the same validation on both platforms.
class CompanySettingsService {
  final ApiClient _client = ApiClient.instance;

  Future<CompanySettings> fetch() async {
    final response = await _client.get(
      '/company/settings',
      authenticated: true,
    );
    return CompanySettings.fromJson(response);
  }

  Future<CompanySettings> updateAccount({
    required String name,
    required String email,
  }) async {
    final response = await _client.put('/company/settings/account', {
      'name': name,
      'email': email,
    }, authenticated: true);

    return CompanySettings.fromJson(
      response['settings'] as Map<String, dynamic>,
    );
  }

  /// The server checks [currentPassword] itself, so a wrong one comes back as
  /// a field error rather than being judged here.
  Future<void> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _client.put('/company/settings/password', {
      'current_password': currentPassword,
      'password': password,
      'password_confirmation': passwordConfirmation,
    }, authenticated: true);
  }

  Future<CompanySettings> updatePreferences({
    String? contactEmail,
    String? contactNumber,
    required bool notifyApplications,
    required bool notifyAssessments,
    required bool notifyPlacements,
    required int minMatchThreshold,
    String? defaultWorkType,
    String? workingHours,
  }) async {
    final response = await _client.put('/company/settings/preferences', {
      'contact_email': ?contactEmail,
      'contact_number': ?contactNumber,
      // Sent explicitly rather than omitted when false: the backend reads
      // an absent toggle as "off", which is what lets them be turned off.
      'notify_applications': notifyApplications,
      'notify_assessments': notifyAssessments,
      'notify_placements': notifyPlacements,
      'min_match_threshold': minMatchThreshold,
      'default_work_type': ?defaultWorkType,
      'working_hours': ?workingHours,
    }, authenticated: true);

    return CompanySettings.fromJson(
      response['settings'] as Map<String, dynamic>,
    );
  }
}
