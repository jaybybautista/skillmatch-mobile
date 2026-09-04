import 'dart:convert';

import '../core/api_client.dart';
import '../core/resume_updates.dart';
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
    final response = await _client.get(
      '/student/profile/editable',
      authenticated: true,
    );
    return EditableProfile.fromJson(response);
  }

  Future<void> updatePersonalInfo({
    required String firstName,
    required String lastName,
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
    await _client.put('/student/profile', {
      'first_name': firstName,
      'last_name': lastName,
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
    }, authenticated: true);
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
  Future<({String message, ResumeInfo? resume})> uploadResume(
    String filePath,
  ) async {
    final response = await _client.postMultipart(
      '/student/profile/resume',
      fields: const {},
      filePath: filePath,
      fileFieldName: 'resume_file',
      authenticated: true,
    );
    // The profile's resume card is not the only place this shows up, so the
    // rest of the app is told rather than left to find out on its own.
    ResumeUpdates.instance.changed();
    return _resumeResult(response);
  }

  /// "Upload & Auto-Fill" — stores the file, then runs the same OCR + AI
  /// pipeline as the web and merges skills/education/experience into the
  /// profile. Accepts PDF/JPG/PNG up to 8 MB.
  Future<({String message, ResumeInfo? resume})> uploadResumeWithAutofill(
    String filePath,
  ) async {
    final response = await _client.postMultipart(
      '/student/profile/resume/autofill',
      fields: const {},
      filePath: filePath,
      fileFieldName: 'resume_file',
      authenticated: true,
    );
    // This one also rewrites skills, education and experience from what the
    // parser read, so more than the resume card is now out of date.
    ResumeUpdates.instance.changed();
    return _resumeResult(response);
  }

  Future<void> removeResume() async {
    await _client.delete('/student/profile/resume', authenticated: true);
    ResumeUpdates.instance.changed();
  }


  // ---------------------------------------------------------------------
  // Profile sections.
  //
  // These hit Student\StudentProfileController, the very controller the
  // website posts to. Not a copy of it, the same one. So the rules about
  // what is required, what is too long, and who is allowed to change a row
  // are decided in exactly one place for both platforms.
  // ---------------------------------------------------------------------

  Future<void> updateSkills(List<String> skills) async {
    await _client.post('/student/profile/skills', {
      // The web posts this as a JSON string in a form field, so the app
      // matches rather than the controller growing a second shape.
      'skills': jsonEncode(skills),
    }, authenticated: true);
  }

  Future<void> updateSummary(String summary) async {
    await _client.post('/student/profile/summary', {
      'professional_summary': summary,
    }, authenticated: true);
  }

  Future<void> saveEducation({
    int? id,
    required String institution,
    String? degree,
    String? fieldOfStudy,
    int? startYear,
    int? endYear,
  }) async {
    final body = {
      'institution': institution,
      'degree': degree,
      'field_of_study': fieldOfStudy,
      'start_year': startYear,
      'end_year': endYear,
    };

    if (id == null) {
      await _client.post('/student/profile/education', body,
          authenticated: true);
    } else {
      await _client.put('/student/profile/education/$id', body,
          authenticated: true);
    }
  }

  Future<void> deleteEducation(int id) async {
    await _client.delete('/student/profile/education/$id', authenticated: true);
  }

  Future<void> saveCertification({
    int? id,
    required String title,
    String? issuingOrganization,
    String? issueDate,
    String? expiryDate,
    String? credentialUrl,
  }) async {
    final body = {
      'title': title,
      'issuing_organization': issuingOrganization,
      'issue_date': issueDate,
      'expiry_date': expiryDate,
      'credential_url': credentialUrl,
    };

    if (id == null) {
      await _client.post('/student/profile/certifications', body,
          authenticated: true);
    } else {
      await _client.put('/student/profile/certifications/$id', body,
          authenticated: true);
    }
  }

  Future<void> deleteCertification(int id) async {
    await _client.delete('/student/profile/certifications/$id',
        authenticated: true);
  }

  Future<void> saveExperience({
    int? id,
    required String position,
    required String organization,
    required String type,
    String? startDate,
    String? endDate,
    String? description,
  }) async {
    final body = {
      'position': position,
      'organization': organization,
      'type': type,
      'start_date': startDate,
      'end_date': endDate,
      'description': description,
    };

    if (id == null) {
      await _client.post('/student/profile/experiences', body,
          authenticated: true);
    } else {
      await _client.put('/student/profile/experiences/$id', body,
          authenticated: true);
    }
  }

  Future<void> deleteExperience(int id) async {
    await _client.delete('/student/profile/experiences/$id',
        authenticated: true);
  }

  Future<void> saveProject({
    int? id,
    required String title,
    String? role,
    String? description,
    String? link,
    String? startDate,
    String? endDate,
  }) async {
    final body = {
      'title': title,
      'role': role,
      'description': description,
      'link': link,
      'start_date': startDate,
      'end_date': endDate,
    };

    if (id == null) {
      await _client.post('/student/profile/projects', body,
          authenticated: true);
    } else {
      await _client.put('/student/profile/projects/$id', body,
          authenticated: true);
    }
  }

  Future<void> deleteProject(int id) async {
    await _client.delete('/student/profile/projects/$id', authenticated: true);
  }

  Future<void> saveAchievement({
    int? id,
    required String title,
    String? issuer,
    String? dateAwarded,
    String? description,
  }) async {
    final body = {
      'title': title,
      'issuer': issuer,
      'date_awarded': dateAwarded,
      'description': description,
    };

    if (id == null) {
      await _client.post('/student/profile/achievements', body,
          authenticated: true);
    } else {
      await _client.put('/student/profile/achievements/$id', body,
          authenticated: true);
    }
  }

  Future<void> deleteAchievement(int id) async {
    await _client.delete('/student/profile/achievements/$id',
        authenticated: true);
  }

  ({String message, ResumeInfo? resume}) _resumeResult(
    Map<String, dynamic> response,
  ) {
    return (
      message: response['message'] as String? ?? 'Resume updated.',
      resume: response['resume'] != null
          ? ResumeInfo.fromJson(response['resume'] as Map<String, dynamic>)
          : null,
    );
  }
}
