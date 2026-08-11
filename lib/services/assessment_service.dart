import '../core/api_client.dart';
import '../models/assessment.dart';

/// Talks to Api\AssessmentController, which shares AssessmentService with the
/// web pages — so access rules, attempt windows and grading are identical
/// whichever platform the student takes the test on.
class AssessmentService {
  final ApiClient _client = ApiClient.instance;

  Future<AssessmentIntro> fetchIntro(int assessmentId) async {
    final response = await _client.get('/student/assessments/$assessmentId', authenticated: true);
    return AssessmentIntro.fromJson(response);
  }

  /// Whether the student may still submit an attempt. Polled while answering,
  /// so finishing the same test on the web closes the quiz here immediately.
  Future<bool> isAttemptOpen(int assessmentId) async {
    final response = await _client.get('/student/assessments/$assessmentId/state', authenticated: true);
    return response['open'] as bool? ?? true;
  }

  Future<AssessmentQuiz> fetchQuiz(int assessmentId) async {
    final response = await _client.get('/student/assessments/$assessmentId/quiz', authenticated: true);
    return AssessmentQuiz.fromJson(response);
  }

  /// [answers] is keyed by question id. Values are a choice id (single choice),
  /// a list of choice ids (checkbox), or a string (free text) — the same shapes
  /// the web form posts, since the server grades both with the same code.
  ///
  /// [timedOut] marks an attempt the countdown submitted on the student's
  /// behalf. The server grades it as usual but never passes it.
  Future<AssessmentAttemptResult> submit(
    int assessmentId,
    Map<int, Object> answers, {
    bool timedOut = false,
  }) async {
    final response = await _client.post(
      '/student/assessments/$assessmentId/submit',
      {
        'answers': answers.map((key, value) => MapEntry(key.toString(), value)),
        'timed_out': timedOut,
      },
      authenticated: true,
    );
    return AssessmentAttemptResult.fromJson(response);
  }

  Future<AssessmentAttemptResult> fetchResult(int assessmentId) async {
    final response = await _client.get('/student/assessments/$assessmentId/result', authenticated: true);
    return AssessmentAttemptResult.fromJson(response);
  }
}
