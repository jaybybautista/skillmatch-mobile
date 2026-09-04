import '../core/api_client.dart';
import '../models/assessment_answer_sheet.dart';
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
    final response = await _client.get(
      '/company/assessments',
      authenticated: true,
    );
    return AssessmentLibrary.fromJson(response);
  }

  /// One assessment with its questions and which answers are correct.
  Future<CompanyAssessment> fetchAssessment(int id) async {
    final response = await _client.get(
      '/company/assessments/$id',
      authenticated: true,
    );
    return CompanyAssessment.fromJson(
      response['assessment'] as Map<String, dynamic>,
    );
  }

  /// The same call, plus the postings the edit form may offer.
  ///
  /// That list is not the library's: it also carries any closed posting this
  /// assessment is already linked to. Saving writes exactly the ticked ids,
  /// so a posting missing from the form would be quietly unlinked — which is
  /// why the server works it out per assessment rather than once per company.
  Future<AssessmentEdit> fetchAssessmentForEditing(int id) async {
    final response = await _client.get(
      '/company/assessments/$id',
      authenticated: true,
    );

    return AssessmentEdit(
      assessment: CompanyAssessment.fromJson(
        response['assessment'] as Map<String, dynamic>,
      ),
      postingOptions: (response['posting_options'] as List? ?? const [])
          .map(
            (e) => AssessmentPostingOption.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Step 1 for a new assessment. Creates it as a draft — it only becomes
  /// published once [saveQuestions] runs, the same two-step flow the web has.
  ///
  /// [internshipIds] is a list because one assessment can screen for several
  /// postings at once. Reusing a paper is a link in `assessment_internship`,
  /// not a copy, so editing it later reaches every posting that uses it.
  Future<CompanyAssessment> createAssessment({
    required List<int> internshipIds,
    required String title,
    String? description,
    int? timeLimitMinutes,
  }) async {
    final response = await _client.post('/company/assessments', {
      'internship_ids': internshipIds,
      'title': title,
      'description': ?description,
      'time_limit': ?timeLimitMinutes,
    }, authenticated: true);

    return CompanyAssessment.fromJson(
      response['assessment'] as Map<String, dynamic>,
    );
  }

  /// Step 1 again, for an assessment that already exists.
  ///
  /// [internshipIds] replaces the whole set of linked postings — whatever is
  /// not in it is unlinked. Answers already given are untouched; only the
  /// next applicant stops seeing the paper on a posting you removed.
  Future<CompanyAssessment> updateAssessment({
    required int id,
    required List<int> internshipIds,
    required String title,
    String? description,
    int? timeLimitMinutes,
  }) async {
    final response = await _client.put('/company/assessments/$id', {
      'internship_ids': internshipIds,
      'title': title,
      'description': ?description,
      'time_limit': ?timeLimitMinutes,
    }, authenticated: true);

    return CompanyAssessment.fromJson(
      response['assessment'] as Map<String, dynamic>,
    );
  }

  /// Adds [internshipId] to the postings this assessment screens for,
  /// leaving the ones it already has alone.
  ///
  /// This is the "reuse what I already wrote" path taken from a posting
  /// rather than from the assessment's own form. It goes through the same
  /// update endpoint, so it is the same pivot write either way.
  Future<CompanyAssessment> linkToPosting(
    CompanyAssessment assessment,
    int internshipId,
  ) async {
    final current = await _reread(assessment);

    return updateAssessment(
      id: current.id,
      internshipIds: {...current.internshipIds, internshipId}.toList(),
      title: current.title,
      description: current.description,
      timeLimitMinutes: current.timeLimitMinutes,
    );
  }

  /// Removes [internshipId] from the postings this assessment screens for.
  ///
  /// Refused when it is the only one left: the backend requires at least one
  /// posting, and an assessment attached to nothing cannot be reached again.
  Future<CompanyAssessment> unlinkFromPosting(
    CompanyAssessment assessment,
    int internshipId,
  ) async {
    final current = await _reread(assessment);

    final remaining = current.internshipIds
        .where((id) => id != internshipId)
        .toList();

    if (remaining.isEmpty) {
      throw StateError(
        'This is the only posting using this assessment. Delete the '
        'assessment instead, or link it elsewhere first.',
      );
    }

    return updateAssessment(
      id: current.id,
      internshipIds: remaining,
      title: current.title,
      description: current.description,
      timeLimitMinutes: current.timeLimitMinutes,
    );
  }

  /// Reads the assessment back before rewriting it.
  ///
  /// Update is a full replace: whatever is left out of the body is cleared,
  /// and whichever ids are sent become the complete set of linked postings.
  /// The card a list screen holds is a summary — it may not carry the
  /// description, and it carries only the postings that list knew about — so
  /// linking from a card would quietly wipe the description and unlink the
  /// other postings. Re-reading first is what makes these two safe to call
  /// from anywhere.
  Future<CompanyAssessment> _reread(CompanyAssessment assessment) =>
      fetchAssessment(assessment.id);

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
    final response = await _client.post('/company/assessments/$id/questions', {
      'questions': questions,
    }, authenticated: true);

    return CompanyAssessment.fromJson(
      response['assessment'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteAssessment(int id) async {
    await _client.delete('/company/assessments/$id', authenticated: true);
  }

  /// Everyone who has completed this assessment, newest first.
  ///
  /// [internshipId] narrows it to the applicants who took the paper for one
  /// posting. A paper shared between postings has one set of questions but
  /// several audiences, and the totals per posting come back either way so
  /// the filter can say how many are behind each option.
  Future<AssessmentSubmissions> fetchSubmissions(
    int id, {
    String query = '',
    int? internshipId,
  }) async {
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (internshipId != null) 'internship_id': '$internshipId',
    };

    final suffix = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

    final response = await _client.get(
      '/company/assessments/$id/submissions$suffix',
      authenticated: true,
    );

    return AssessmentSubmissions.fromJson(response);
  }

  /// One student's whole answer sheet — what they picked or typed per
  /// question, and whether it was marked right. Reads the same
  /// `assessment_answers` rows the website's answer sheet shows.
  Future<AssessmentAnswerSheet> fetchAnswerSheet(
    int assessmentId,
    int resultId,
  ) async {
    final response = await _client.get(
      '/company/assessments/$assessmentId/submissions/$resultId',
      authenticated: true,
    );

    return AssessmentAnswerSheet.fromJson(response);
  }

  /// Puts a score on the written answers. Keys are `assessment_answers` ids,
  /// values are the points given. The server clamps anything above the
  /// question's maximum and recomputes the total, so the phone and the web
  /// cannot end up disagreeing about the score.
  Future<void> gradeSubmission(
    int assessmentId,
    int resultId,
    Map<int, double> pointsByAnswerId,
  ) async {
    await _client.post(
      '/company/assessments/$assessmentId/submissions/$resultId/grade',
      {'points': pointsByAnswerId.map((k, v) => MapEntry('$k', v))},
      authenticated: true,
    );
  }

  /// Retakes [assessmentId] for [applicationId] — the same reassignment the
  /// application's own Assign/Reassign action makes (Api\CompanyApplication
  /// Controller@assignAssessment), so a retake from the submissions list
  /// behaves exactly like reassigning from the application itself. Opens a
  /// fresh attempt window and notifies the student; the score already on
  /// record for the earlier attempt is left untouched.
  Future<void> retake({
    required int applicationId,
    required int assessmentId,
  }) async {
    await _client.post(
      '/company/applications/$applicationId/assign-assessment',
      {'assessment_id': assessmentId},
      authenticated: true,
    );
  }
}
