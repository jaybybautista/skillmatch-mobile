import '../core/api_client.dart';
import '../models/profile_setup.dart';

/// Talks to Api\ProfileSetupController — the first-run wizard.
///
/// Each step writes to the same tables the web wizard writes to, so a profile
/// built here is indistinguishable from one built in a browser.
class ProfileSetupService {
  final ApiClient _client = ApiClient.instance;

  Future<SetupState> fetchState() async {
    final response = await _client.get(
      '/student/setup/state',
      authenticated: true,
    );
    return SetupState.fromJson(response);
  }

  /// Runs the resume through OCR and the AI parser. Slow by nature, so this
  /// uses the long-timeout upload path.
  Future<ParsedResume> uploadResume(String filePath) async {
    final response = await _client.postMultipart(
      '/student/setup/upload-resume',
      fields: const {},
      filePath: filePath,
      fileFieldName: 'resume_file',
      authenticated: true,
    );
    return ParsedResume.fromJson(response);
  }

  Future<void> saveStep1({
    required String name,
    String? address,
    String? zipCode,
    String? phoneNumber,
    String? email,
  }) async {
    await _client.post('/student/setup/step/1', {
      'name': name,
      'address': ?address,
      'zip_code': ?zipCode,
      'phone_number': ?phoneNumber,
      'email': ?email,
    }, authenticated: true);
  }

  Future<void> saveStep2({
    String? schoolName,
    String? schoolAddress,
    String? degree,
    String? major,
  }) async {
    await _client.post('/student/setup/step/2', {
      'school_name': ?schoolName,
      'school_address': ?schoolAddress,
      'degree': ?degree,
      'major': ?major,
    }, authenticated: true);
  }

  Future<void> saveStep3({
    required List<String> technicalSkills,
    required List<String> softSkills,
  }) async {
    await _client.post('/student/setup/step/3', {
      'technical_skills': technicalSkills,
      'soft_skills': softSkills,
    }, authenticated: true);
  }

  Future<Certification> addCertification({
    required String title,
    String? issuingOrganization,
    String? issueDate,
  }) async {
    final response = await _client.post('/student/setup/certifications', {
      'title': title,
      'issuing_organization': ?issuingOrganization,
      'issue_date': ?issueDate,
    }, authenticated: true);
    return Certification.fromJson(
      response['certification'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteCertification(int id) async {
    await _client.delete(
      '/student/setup/certifications/$id',
      authenticated: true,
    );
  }

  Future<Experience> addExperience({
    required String position,
    required String organization,
    String? startDate,
    String? endDate,
    String? description,
  }) async {
    final response = await _client.post('/student/setup/experiences', {
      'position': position,
      'organization': organization,
      'start_date': ?startDate,
      'end_date': ?endDate,
      'description': ?description,
    }, authenticated: true);
    return Experience.fromJson(response['experience'] as Map<String, dynamic>);
  }

  Future<void> deleteExperience(int id) async {
    await _client.delete('/student/setup/experiences/$id', authenticated: true);
  }

  Future<SetupReview> fetchReview() async {
    final response = await _client.get(
      '/student/setup/review',
      authenticated: true,
    );
    return SetupReview.fromJson(response);
  }

  /// Marks setup complete and recomputes match scores server-side, so the
  /// dashboard already knows the student when they land on it.
  Future<void> finish() async {
    await _client.postLong(
      '/student/setup/save',
      const {},
      authenticated: true,
    );
  }

  Future<void> skip() async {
    await _client.post('/student/setup/skip', const {}, authenticated: true);
  }
}
