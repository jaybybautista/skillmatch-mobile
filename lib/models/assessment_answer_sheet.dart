import '../core/json_parse.dart';
import 'assessment.dart';

/// One question as it was answered, straight from `assessment_answers`.
///
/// The same row the website's answer sheet reads, so a company looking at an
/// attempt on the phone and on the browser sees identical marks.
class AnswerSheetRow {
  const AnswerSheetRow({
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.manual,
    required this.answered,
    required this.pointsAwarded,
    required this.pointsPossible,
    this.answerId,
    this.isCorrect,
    this.answerText,
    this.chosen = const [],
    this.correct = const [],
    this.languageBadge,
    this.sourceCode,
    this.expectedOutput,
  });

  final int questionId;

  /// The `assessment_answers` row id. Needed when scoring a written answer.
  final int? answerId;

  final String questionText;
  final String questionType;

  /// True when the company set no answer key, so this one is scored by hand.
  final bool manual;

  final bool answered;

  /// Null means either nothing was submitted, or it is a written answer that
  /// has not been scored yet.
  final bool? isCorrect;

  final double pointsAwarded;
  final int pointsPossible;

  /// What the student typed, for short answer and paragraph questions.
  final String? answerText;

  /// What the student picked, for choice questions.
  final List<String> chosen;

  /// The answer key. Empty when the question is scored by hand.
  final List<String> correct;

  /// Code tracing lang ang may laman sa tatlong ito. Yung code na binasa ng
  /// estudyante, at yung dapat lumabas - kailangan nila ito para may
  /// pagbasehan yung sinagot niya.
  final LanguageBadge? languageBadge;
  final String? sourceCode;
  final String? expectedOutput;

  bool get isCodeTracing => questionType == 'code_tracing';

  bool get isWritten => answerText != null && answerText!.trim().isNotEmpty;

  factory AnswerSheetRow.fromJson(Map<String, dynamic> json) => AnswerSheetRow(
        questionId: asInt(json['question_id']),
        answerId: asIntOrNull(json['answer_id']),
        questionText: json['question_text'] as String? ?? '',
        questionType: json['question_type'] as String? ?? 'multiple_choice',
        manual: json['manual'] as bool? ?? false,
        answered: json['answered'] as bool? ?? false,
        isCorrect: json['is_correct'] as bool?,
        pointsAwarded: asDouble(json['points_awarded']),
        pointsPossible: asInt(json['points_possible']),
        answerText: json['answer_text'] as String?,
        chosen: (json['chosen'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        correct: (json['correct'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
        languageBadge: json['language_badge'] is Map<String, dynamic>
            ? LanguageBadge.fromJson(
                json['language_badge'] as Map<String, dynamic>,
              )
            : null,
        sourceCode: json['source_code'] as String?,
        expectedOutput: json['expected_output'] as String?,
      );
}

/// A whole attempt: the header figures plus every question.
class AssessmentAnswerSheet {
  const AssessmentAnswerSheet({
    required this.resultId,
    required this.studentName,
    required this.assessmentTitle,
    required this.score,
    required this.totalPoints,
    required this.percentage,
    required this.passed,
    required this.timedOut,
    required this.pendingReview,
    required this.hasAnswers,
    this.durationLabel,
    this.submittedAtLabel,
    this.applicationId,
    this.retakeOpen = false,
    this.rows = const [],
  });

  final int resultId;
  final String studentName;
  final String assessmentTitle;

  /// The application Retake reassigns this paper to. Null when the server
  /// could not tell which application this attempt came through.
  final int? applicationId;

  /// A fresh attempt is already open and unanswered — the standing proof
  /// that a Retake went through, on the same rule the web uses.
  final bool retakeOpen;

  final double score;
  final int totalPoints;
  final int percentage;
  final bool passed;
  final bool timedOut;

  /// True while a written answer is still waiting to be scored, in which case
  /// the pass or fail verdict is not final yet.
  final bool pendingReview;

  /// False for attempts submitted before answers were kept, which have a
  /// score but nothing to show per question.
  final bool hasAnswers;

  final String? durationLabel;
  final String? submittedAtLabel;

  final List<AnswerSheetRow> rows;

  /// The written answers a company still has to put a score on.
  List<AnswerSheetRow> get gradable =>
      rows.where((r) => r.manual && r.answered && r.isWritten).toList();

  factory AssessmentAnswerSheet.fromJson(Map<String, dynamic> json) {
    final result = (json['result'] as Map<String, dynamic>?) ?? const {};

    return AssessmentAnswerSheet(
      resultId: asInt(result['id']),
      studentName: result['student_name'] as String? ?? 'Candidate',
      assessmentTitle: result['assessment_title'] as String? ?? 'Assessment',
      score: asDouble(result['score']),
      totalPoints: asInt(result['total_points']),
      percentage: asInt(result['percentage']),
      passed: result['passed'] as bool? ?? false,
      timedOut: result['timed_out'] as bool? ?? false,
      pendingReview: result['pending_review'] as bool? ?? false,
      durationLabel: result['duration_label'] as String?,
      submittedAtLabel: result['submitted_at_label'] as String?,
      applicationId: asIntOrNull(result['application_id']),
      retakeOpen: result['retake_open'] as bool? ?? false,
      hasAnswers: json['has_answers'] as bool? ?? false,
      rows: (json['rows'] as List? ?? const [])
          .map((e) => AnswerSheetRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
