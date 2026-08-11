import '../core/api_client.dart';
import '../models/editable_profile.dart';
import '../models/student_profile.dart';

/// Reads and writes the student profile via /api/student/profile — the same
/// tables the web app's Profile page uses, including its two resume upload
/// modes (auto-fill vs. upload only).
class ProfileService {
  final ApiClient _client = ApiClient.instance;

  Future<StudentProfile> fetchStudentProfile() async {
    final response = await _client.get('/student/profile', authenticated: true);
    return StudentProfile.fromJson(response);
  }

  Future<EditableProfile> fetchEditableProfile() async {
    final response = await _client.get('/student/profile/editable', authenticated: true);
    return EditableProfile.fromJson(response);
  }

  Future<void> updatePersonalInfo({
    required String name,
    String? studentNumber,
    String? contactNumber,
    int? campusId,
    String? course,
    int? yearLevel,
    String? address,
    String? region,
    String? province,
    String? cityMunicipality,
    String? barangay,
  }) async {
    await _client.put(
      '/student/profile',
      {
        'name': name,
        'student_number': studentNumber,
        'contact_number': contactNumber,
        'campus_id': campusId,
        'course': course,
        'year_level': yearLevel,
        'address': address,
        'region': region,
        'province': province,
        'city_municipality': cityMunicipality,
        'barangay': barangay,
      },
      authenticated: true,
    );
  }

  /// Uploads a new profile photo (any image, max 2 MB) and returns the new
  /// URL. Writes the same users.profile_picture value the web uses.
  Future<String?> updatePhoto(String filePath) async {
    final response = await _client.postMultipart(
      '/student/profile/photo',
      fields: const {},
      filePath: filePath,
      fileFieldName: 'profile_picture',
      authenticated: true,
    );
    return response['profile_picture_url'] as String?;
  }

  /// "Upload Only" — stores the file, leaves profile fields untouched.
  /// Accepts PDF/DOC/DOCX up to 5 MB, matching the web form.
  Future<({String message, ResumeInfo? resume})> uploadResume(String filePath) async {
    final response = await _client.postMultipart(
      '/student/profile/resume',
      fields: const {},
      filePath: filePath,
      fileFieldName: 'resume_file',
      authenticated: true,
    );
    return _resumeResult(response);
  }

  /// "Upload & Auto-Fill" — stores the file, then runs the same OCR + AI
  /// pipeline as the web and merges skills/education/experience into the
  /// profile. Accepts PDF/JPG/PNG up to 8 MB.
  Future<({String message, ResumeInfo? resume})> uploadResumeWithAutofill(String filePath) async {
    final response = await _client.postMultipart(
      '/student/profile/resume/autofill',
      fields: const {},
      filePath: filePath,
      fileFieldName: 'resume_file',
      authenticated: true,
    );
    return _resumeResult(response);
  }

  Future<void> removeResume() async {
    await _client.delete('/student/profile/resume', authenticated: true);
  }

  ({String message, ResumeInfo? resume}) _resumeResult(Map<String, dynamic> response) {
    return (
      message: response['message'] as String? ?? 'Resume updated.',
      resume: response['resume'] != null ? ResumeInfo.fromJson(response['resume'] as Map<String, dynamic>) : null,
    );
  }
}
