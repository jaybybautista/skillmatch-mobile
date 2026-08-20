/// Competency-test models. These mirror the `assessments`, `questions`,
/// `question_choices` and `assessment_results` tables the web app uses — the
/// API never sends which choice is correct, grading happens server-side.
library;

/// The overview shown before a student starts (the web's assessment-intro page).
class AssessmentIntro {
  AssessmentIntro({
    required this.id,
    required this.title,
    this.description,
    required this.companyName,
    this.location,
    this.internshipTitle,
    required this.questionCount,
    required this.totalPoints,
    this.timeLimitMinutes,
    required this.instructions,
    required this.alreadyCompleted,
    required this.isRetake,
    required this.attemptHistory,
  });

  final int id;
  final String title;
  final String? description;
  final String companyName;
  final String? location;
  final String? internshipTitle;
  final int questionCount;
  final int totalPoints;

  /// Null when the company set no time limit — the quiz then runs untimed.
  final int? timeLimitMinutes;
  final List<String> instructions;

  /// True when an attempt already covers the current assignment window, in
  /// which case the app goes straight to the result (the web redirects).
  final bool alreadyCompleted;

  /// Answered before, reassigned since — the student is retaking it.
  final bool isRetake;

  /// Past attempts, newest first.
  final List<AssessmentAttempt> attemptHistory;

  /// "Creatix Studio · New York, NY" — the subtitle under the hero title.
  String get subtitle {
    final place = location;
    if (place == null || place.trim().isEmpty) return companyName;
    return '$companyName · $place';
  }

  factory AssessmentIntro.fromJson(Map<String, dynamic> json) {
    final assessment = json['assessment'] as Map<String, dynamic>? ?? const {};
    return AssessmentIntro(
      id: (assessment['id'] as num).toInt(),
      title: assessment['title'] as String? ?? 'Assessment',
      description: assessment['description'] as String?,
      companyName: assessment['company_name'] as String? ?? 'Company',
      location: assessment['location'] as String?,
      internshipTitle: assessment['internship_title'] as String?,
      questionCount: (assessment['question_count'] as num?)?.toInt() ?? 0,
      totalPoints: (assessment['total_points'] as num?)?.toInt() ?? 0,
      timeLimitMinutes: (assessment['time_limit'] as num?)?.toInt(),
      instructions: (json['instructions'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      alreadyCompleted: json['already_completed'] as bool? ?? false,
      isRetake: json['is_retake'] as bool? ?? false,
      attemptHistory: (json['attempt_history'] as List? ?? const [])
          .map((e) => AssessmentAttempt.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One past attempt, as the coordinator's history table shows it.
class AssessmentAttempt {
  AssessmentAttempt({
    required this.score,
    required this.totalPoints,
    required this.percentage,
    required this.passed,
    required this.timedOut,
    required this.submittedAtLabel,
    required this.isCurrent,
  });

  final int score;
  final int totalPoints;
  final int percentage;
  final bool passed;

  /// Ran out of time, so it counts as a fail regardless of the score.
  final bool timedOut;
  final String submittedAtLabel;

  /// False for attempts made before the latest reassignment — the web labels
  /// those "Before reassignment".
  final bool isCurrent;

  factory AssessmentAttempt.fromJson(Map<String, dynamic> json) =>
      AssessmentAttempt(
        score: (json['score'] as num?)?.toInt() ?? 0,
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toInt() ?? 0,
        passed: json['passed'] as bool? ?? false,
        timedOut: json['timed_out'] as bool? ?? false,
        submittedAtLabel: json['submitted_at_label'] as String? ?? '',
        isCurrent: json['is_current'] as bool? ?? false,
      );
}

/// One answer option. The API deliberately omits `is_correct`.
class QuestionChoice {
  QuestionChoice({required this.id, required this.text});

  final int id;
  final String text;

  factory QuestionChoice.fromJson(Map<String, dynamic> json) => QuestionChoice(
    id: (json['id'] as num).toInt(),
    text: json['choice_text'] as String? ?? '',
  );
}

/// How a question is answered. Companies can currently author the first three;
/// the others exist in the grading rules, so they're supported here too rather
/// than silently rendering nothing if one ever turns up.
enum QuestionType {
  multipleChoice,
  checkbox,
  dropdown,
  identification,
  shortAnswer,
  longAnswer;

  static QuestionType parse(String? raw) {
    switch (raw) {
      case 'checkbox':
        return QuestionType.checkbox;
      case 'dropdown':
        return QuestionType.dropdown;
      case 'identification':
        return QuestionType.identification;
      case 'short_answer':
        return QuestionType.shortAnswer;
      case 'long_answer':
        return QuestionType.longAnswer;
      default:
        return QuestionType.multipleChoice;
    }
  }

  /// True when the answer is free text rather than a choice id.
  bool get isFreeText =>
      this == QuestionType.shortAnswer || this == QuestionType.longAnswer;

  /// True when more than one choice may be selected.
  bool get isMultiSelect => this == QuestionType.checkbox;
}

class AssessmentQuestion {
  AssessmentQuestion({
    required this.id,
    required this.text,
    this.description,
    required this.type,
    required this.points,
    this.imageUrl,
    required this.choices,
  });

  final int id;
  final String text;
  final String? description;
  final QuestionType type;
  final int points;

  /// Either an absolute http(s) URL or an inline `data:image/...;base64,` URI —
  /// the company question builder produces the latter.
  final String? imageUrl;
  final List<QuestionChoice> choices;

  factory AssessmentQuestion.fromJson(Map<String, dynamic> json) =>
      AssessmentQuestion(
        id: (json['id'] as num).toInt(),
        text: json['question_text'] as String? ?? '',
        description: json['description'] as String?,
        type: QuestionType.parse(json['question_type'] as String?),
        points: (json['points'] as num?)?.toInt() ?? 1,
        imageUrl: json['image_url'] as String?,
        choices: (json['choices'] as List? ?? const [])
            .map((e) => QuestionChoice.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// The paper: the questions plus the timer setting.
class AssessmentQuiz {
  AssessmentQuiz({
    required this.id,
    required this.title,
    this.timeLimitMinutes,
    required this.questions,
  });

  final int id;
  final String title;
  final int? timeLimitMinutes;
  final List<AssessmentQuestion> questions;

  factory AssessmentQuiz.fromJson(Map<String, dynamic> json) {
    final assessment = json['assessment'] as Map<String, dynamic>? ?? const {};
    return AssessmentQuiz(
      id: (assessment['id'] as num).toInt(),
      title: assessment['title'] as String? ?? 'Assessment',
      timeLimitMinutes: (assessment['time_limit'] as num?)?.toInt(),
      questions: (json['questions'] as List? ?? const [])
          .map((e) => AssessmentQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A graded attempt, as stored in `assessment_results`.
class AssessmentAttemptResult {
  AssessmentAttemptResult({
    required this.assessmentTitle,
    required this.score,
    required this.totalPoints,
    required this.percentage,
    required this.passed,
    required this.headline,
    required this.message,
    required this.timedOut,
    this.submittedAt,
  });

  final String assessmentTitle;
  final int score;
  final int totalPoints;
  final int percentage;
  final bool passed;
  final String headline;
  final String message;

  /// The countdown submitted this attempt. It is graded, but never a pass.
  final bool timedOut;
  final String? submittedAt;

  factory AssessmentAttemptResult.fromJson(Map<String, dynamic> json) =>
      AssessmentAttemptResult(
        assessmentTitle: json['assessment_title'] as String? ?? 'Assessment',
        score: (json['score'] as num?)?.toInt() ?? 0,
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toInt() ?? 0,
        passed: json['passed'] as bool? ?? false,
        headline: json['headline'] as String? ?? 'Assessment complete',
        message: json['message'] as String? ?? '',
        timedOut: json['timed_out'] as bool? ?? false,
        submittedAt: json['submitted_at'] as String?,
      );
}
