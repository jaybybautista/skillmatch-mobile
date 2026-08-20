import '../core/api_client.dart';
import '../models/resume.dart';

/// Talks to Api\ResumeBuilderController — the same resumes/sections/items
/// the web app's Resume Builder reads and writes, so edits stay in sync in
/// both directions.
class ResumeService {
  final ApiClient _client = ApiClient.instance;

  /// Update endpoints use Laravel's `$request->only([...])`, which only
  /// touches keys actually present in the JSON body — so dropping null
  /// entries here lets a partial "just this one field changed" update go
  /// out without wiping the other fields back to null server-side.
  Map<String, dynamic> _presentOnly(Map<String, dynamic> body) {
    return {
      for (final entry in body.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }

  Future<List<ResumeSummary>> fetchResumes() async {
    final response = await _client.get('/resumes', authenticated: true);
    return (response['resumes'] as List)
        .map((e) => ResumeSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Resume> createResume(String title) async {
    final response = await _client.post('/resumes', {
      'title': title,
    }, authenticated: true);
    return Resume.fromJson(response);
  }

  Future<void> renameResume(int resumeId, String title) async {
    await _client.put('/resumes/$resumeId/rename', {
      'title': title,
    }, authenticated: true);
  }

  Future<void> deleteResume(int resumeId) async {
    await _client.delete('/resumes/$resumeId', authenticated: true);
  }

  Future<Resume> fetchResume(int resumeId) async {
    final response = await _client.get(
      '/resumes/$resumeId',
      authenticated: true,
    );
    return Resume.fromJson(response);
  }

  Future<void> addSection({
    required int resumeId,
    required String title,
    String? description,
    required String inputType,
  }) async {
    await _client.post('/resumes/$resumeId/sections', {
      'title': title,
      'description': description,
      'input_type': inputType,
    }, authenticated: true);
  }

  Future<void> deleteSection(int sectionId) async {
    await _client.delete('/resume-sections/$sectionId', authenticated: true);
  }

  Future<void> updateBasicInfo(
    int sectionId, {
    String? fullName,
    String? address,
    String? zipCode,
    String? phoneNumber,
    String? email,
  }) async {
    await _client.put(
      '/resume-sections/$sectionId/basic-info',
      _presentOnly({
        'full_name': fullName,
        'address': address,
        'zip_code': zipCode,
        'phone_number': phoneNumber,
        'email': email,
      }),
      authenticated: true,
    );
  }

  Future<void> updateTextSection(int sectionId, String? content) async {
    await _client.put('/resume-sections/$sectionId/text', {
      'content': content,
    }, authenticated: true);
  }

  Future<ResumeExperienceEntry> addExperience(
    int sectionId, {
    String? jobTitle,
    String? company,
    String? address,
    String? responsibilities,
    String? periodStart,
    String? periodEnd,
  }) async {
    final response = await _client
        .post('/resume-sections/$sectionId/experiences', {
          'job_title': jobTitle,
          'company': company,
          'address': address,
          'responsibilities': responsibilities,
          'period_start': periodStart,
          'period_end': periodEnd,
        }, authenticated: true);
    return ResumeExperienceEntry.fromJson(response);
  }

  Future<void> updateExperience(
    int experienceId, {
    String? jobTitle,
    String? company,
    String? address,
    String? responsibilities,
    String? periodStart,
    String? periodEnd,
  }) async {
    await _client.put(
      '/resume-experiences/$experienceId',
      _presentOnly({
        'job_title': jobTitle,
        'company': company,
        'address': address,
        'responsibilities': responsibilities,
        'period_start': periodStart,
        'period_end': periodEnd,
      }),
      authenticated: true,
    );
  }

  Future<void> deleteExperience(int experienceId) async {
    await _client.delete(
      '/resume-experiences/$experienceId',
      authenticated: true,
    );
  }

  Future<ResumeAchievementEntry> addAchievement(
    int sectionId, {
    String? title,
    String? category,
    String? location,
    String? dateText,
  }) async {
    final response = await _client.post(
      '/resume-sections/$sectionId/achievements',
      {
        'title': title,
        'category': category,
        'location': location,
        'date_text': dateText,
      },
      authenticated: true,
    );
    return ResumeAchievementEntry.fromJson(response);
  }

  Future<void> updateAchievement(
    int achievementId, {
    String? title,
    String? category,
    String? location,
    String? dateText,
  }) async {
    await _client.put(
      '/resume-achievements/$achievementId',
      _presentOnly({
        'title': title,
        'category': category,
        'location': location,
        'date_text': dateText,
      }),
      authenticated: true,
    );
  }

  Future<void> deleteAchievement(int achievementId) async {
    await _client.delete(
      '/resume-achievements/$achievementId',
      authenticated: true,
    );
  }

  Future<ResumeProjectEntry> addProject(
    int sectionId, {
    String? title,
    String? description,
  }) async {
    final response = await _client.post(
      '/resume-sections/$sectionId/projects',
      {'title': title, 'description': description},
      authenticated: true,
    );
    return ResumeProjectEntry.fromJson(response);
  }

  Future<void> updateProject(
    int projectId, {
    String? title,
    String? description,
  }) async {
    await _client.put(
      '/resume-projects/$projectId',
      _presentOnly({'title': title, 'description': description}),
      authenticated: true,
    );
  }

  Future<void> deleteProject(int projectId) async {
    await _client.delete('/resume-projects/$projectId', authenticated: true);
  }

  Future<ResumeEducationEntry> addEducation(
    int sectionId, {
    String? degree,
    String? schoolName,
    String? startDate,
    String? endDate,
  }) async {
    final response = await _client
        .post('/resume-sections/$sectionId/education', {
          'degree': degree,
          'school_name': schoolName,
          'start_date': startDate,
          'end_date': endDate,
        }, authenticated: true);
    return ResumeEducationEntry.fromJson(response);
  }

  Future<void> updateEducation(
    int educationId, {
    String? degree,
    String? schoolName,
    String? startDate,
    String? endDate,
  }) async {
    await _client.put(
      '/resume-education/$educationId',
      _presentOnly({
        'degree': degree,
        'school_name': schoolName,
        'start_date': startDate,
        'end_date': endDate,
      }),
      authenticated: true,
    );
  }

  Future<void> deleteEducation(int educationId) async {
    await _client.delete('/resume-education/$educationId', authenticated: true);
  }

  /// Returns the section's full, updated skill lists (technical + soft) —
  /// the backend returns the whole section here rather than a single skill.
  Future<ResumeSection> addSkill(
    int sectionId, {
    required String category,
    required String skillName,
  }) async {
    final response = await _client.post('/resume-sections/$sectionId/skills', {
      'category': category,
      'skill_name': skillName,
    }, authenticated: true);
    return ResumeSection.fromJson(response);
  }

  Future<void> deleteSkill(int skillId) async {
    await _client.delete('/resume-skills/$skillId', authenticated: true);
  }

  /// Sends the current text to the same Groq-backed rewrite endpoint the web
  /// app's "AI Help" buttons use, returning the improved version. [context]
  /// carries extra fields (e.g. job_title/company) the model uses for tone.
  Future<String> improveText(
    String fieldLabel,
    String text, {
    Map<String, String> context = const {},
  }) async {
    final response = await _client.postLong('/resumes/ai-help', {
      'field_label': fieldLabel,
      'text': text,
      'context': context,
    }, authenticated: true);
    return response['text'] as String;
  }

  /// Uploads a resume file (or reuses the student's already-uploaded profile
  /// resume) to the same OCR + AI parsing pipeline the web app's Import
  /// feature uses, and returns the newly created resume.
  Future<Resume> importResume({
    String? filePath,
    bool useProfileResume = false,
  }) async {
    final response = await _client.postMultipart(
      '/resumes/import',
      fields: {'use_profile_resume': useProfileResume.toString()},
      filePath: useProfileResume ? null : filePath,
      fileFieldName: useProfileResume ? null : 'resume_file',
      authenticated: true,
    );
    return Resume.fromJson(response);
  }
}
