import '../core/api_client.dart';
import '../models/assessment_submission.dart';
import '../models/company_assessment.dart';

/// Talks to Api\CompanyAssessmentController, which shares
/// CompanyAssessmentService with the website's assessment builder — so the
/// validation, the blank-option cleaning, the "replace the whole paper"
/// save, the points and the publish rules are identical on both platforms.
///
/// An assessment created here opens for editing on the web, and one edited
/// on the web shows its new questions here on the next refresh.
class CompanyAssessmentService {
  final ApiClient _client = ApiClient.instance;

  /// The library, plus the postings a new assessment can be attached to.
  Future<AssessmentLibrary> fetchLibrary() async {
    final response = await _client.get('/company/assessments', authenticated: true);
    return AssessmentLibrary.fromJson(response);
  }

  /// One assessment with its questions and which answers are correct.
  Future<CompanyAssessment> fetchAssessment(int id) async {
    final response = await _client.get('/company/assessments/$id', authenticated: true);
    return CompanyAssessment.fromJson(response['assessment'] as Map<String, dynamic>);
  }

  /// Step 1 for a new assessment. Creates it as a draft — it only becomes
  /// published once [saveQuestions] runs, the same two-step flow the web has.
  Future<CompanyAssessment> createAssessment({
    required int internshipId,
    required String title,
    String? description,
    int? timeLimitMinutes,
  }) async {
    final response = await _client.post(
      '/company/assessments',
      {
        'internship_id': internshipId,
        'title': title,
        'description': ?description,
        'time_limit': ?timeLimitMinutes,
      },
      authenticated: true,
    );

    return CompanyAssessment.fromJson(response['assessment'] as Map<String, dynamic>);
  }

  /// Step 1 again, for an assessment that already exists.
  Future<CompanyAssessment> updateAssessment({
    required int id,
    required int internshipId,
    required String title,
    String? description,
    int? timeLimitMinutes,
  }) async {
    final response = await _client.put(
      '/company/assessments/$id',
      {
        'internship_id': internshipId,
        'title': title,
        'description': ?description,
        'time_limit': ?timeLimitMinutes,
      },
      authenticated: true,
    );

    return CompanyAssessment.fromJson(response['assessment'] as Map<String, dynamic>);
  }

  /// Step 2: replaces the whole paper and publishes it.
  ///
  /// [questions] is the payload shape the web builder posts —
  /// `{type, question_text, description, image_url, choices: [{text,
  /// is_correct}]}` — because the same service parses both. Blank answer
  /// options may be left in; the server drops them.
  Future<CompanyAssessment> saveQuestions({
    required int id,
    required List<Map<String, dynamic>> questions,
  }) async {
    final response = await _client.post(
      '/company/assessments/$id/questions',
      {'questions': questions},
      authenticated: true,
    );

    return CompanyAssessment.fromJson(response['assessment'] as Map<String, dynamic>);
  }

  Future<void> deleteAssessment(int id) async {
    await _client.delete('/company/assessments/$id', authenticated: true);
  }

  /// Everyone who has completed this assessment, newest first.
  Future<List<AssessmentSubmission>> fetchSubmissions(int id, {String query = ''}) async {
    final suffix = query.trim().isEmpty ? '' : '?q=${Uri.encodeQueryComponent(query.trim())}';
    final response = await _client.get(
      '/company/assessments/$id/submissions$suffix',
      authenticated: true,
    );

    return (response['submissions'] as List? ?? const [])
        .map((e) => AssessmentSubmission.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
