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
  longAnswer,
  codeTracing;

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
      case 'code_tracing':
        return QuestionType.codeTracing;
      default:
        return QuestionType.multipleChoice;
    }
  }

  /// True when the answer is free text rather than a choice id. Kasama dito ang
  /// code tracing - yung output na tinipa niya ang ipinapadala, teksto rin yun,
  /// at teksto rin ang ihahambing ng server.
  bool get isFreeText =>
      this == QuestionType.shortAnswer ||
      this == QuestionType.longAnswer ||
      this == QuestionType.codeTracing;

  /// Binabasa niya yung code, tinitipa niya kung ano ang ipipirint nito.
  bool get isCodeTracing => this == QuestionType.codeTracing;

  /// True when more than one choice may be selected.
  bool get isMultiSelect => this == QuestionType.checkbox;
}

/// Yung tanda ng wika na nakadikit sa isang code tracing na tanong. Pangalan,
/// logo, kulay at isa o dalawang letra - galing sa ProgrammingLanguages ng
/// server, kaya iisa ang itsura nito sa web at dito.
class LanguageBadge {
  const LanguageBadge({
    required this.slug,
    required this.label,
    required this.mono,
    required this.color,
    required this.kind,
    this.hasIcon = false,
  });

  final String slug;
  final String label;

  /// Yung isa o dalawang letra sa loob ng tanda. Ito ang lumalabas pag walang
  /// logo yung wika, gaya ng SQL at ng Pseudocode.
  final String mono;

  /// Hex na may unahang #, gaya ng #3776AB. Likod ng tanda kapag walang logo.
  final String color;

  /// language o framework. Dito nagkakahiwalay ang dalawang pangkat sa picker.
  final String kind;

  /// May logo ba ang wikang ito. Sinasabi ito ng server, at dito nakikita ng
  /// app kung dapat pa nitong hanapin yung file sa assets/devicon o tanda na
  /// lang agad ang ilalabas.
  final bool hasIcon;

  static const LanguageBadge plain = LanguageBadge(
    slug: '',
    label: 'Plain text',
    mono: '::',
    color: '#6B7A99',
    kind: 'language',
  );

  factory LanguageBadge.fromJson(Map<String, dynamic> json) => LanguageBadge(
    slug: json['slug'] as String? ?? '',
    label: json['label'] as String? ?? 'Plain text',
    mono: json['mono'] as String? ?? '::',
    color: json['color'] as String? ?? '#6B7A99',
    kind: json['kind'] as String? ?? 'language',
    // Address ng logo ang ipinapadala ng server. Hindi ito ginagamit dito,
    // nakabalot na kasi sa app yung mga logo - pero sinasabi nito kung meron.
    hasIcon: (json['icon'] as String?)?.isNotEmpty ?? false,
  );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'label': label,
    'mono': mono,
    'color': color,
    'kind': kind,
    'has_icon': hasIcon,
  };
}

class AssessmentQuestion {
  AssessmentQuestion({
    required this.id,
    required this.text,
    this.description,
    required this.type,
    required this.points,
    this.imageUrl,
    this.language,
    this.sourceCode,
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

  /// Code tracing lang ang may laman dito. Yung expected output, hindi
  /// kailanman ipinapadala ng server habang sumasagot siya - yun mismo ang
  /// sagot, at nasa telepono niya ito.
  final LanguageBadge? language;
  final String? sourceCode;

  final List<QuestionChoice> choices;

  factory AssessmentQuestion.fromJson(Map<String, dynamic> json) =>
      AssessmentQuestion(
        id: (json['id'] as num).toInt(),
        text: json['question_text'] as String? ?? '',
        description: json['description'] as String?,
        type: QuestionType.parse(json['question_type'] as String?),
        points: (json['points'] as num?)?.toInt() ?? 1,
        imageUrl: json['image_url'] as String?,
        language: json['language'] is Map<String, dynamic>
            ? LanguageBadge.fromJson(json['language'] as Map<String, dynamic>)
            : null,
        sourceCode: json['source_code'] as String?,
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

/// How many questions were settled on the spot and how many a person still
/// has to read.
class AssessmentReviewCounts {
  const AssessmentReviewCounts({
    this.total = 0,
    this.autoChecked = 0,
    this.awaiting = 0,
  });

  final int total;
  final int autoChecked;

  /// Written answers the company has not scored yet. A question left blank is
  /// not counted here: there is nothing to read, so it is already a zero and
  /// does not depend on the review.
  final int awaiting;

  factory AssessmentReviewCounts.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AssessmentReviewCounts();

    return AssessmentReviewCounts(
      total: (json['total'] as num?)?.toInt() ?? 0,
      autoChecked: (json['auto_checked'] as num?)?.toInt() ?? 0,
      awaiting: (json['awaiting'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A graded attempt, as stored in `assessment_results`.
///
/// [score], [percentage] and [passed] are deliberately nullable. When the
/// attempt has written answers nobody has read yet, the API sends them as null
/// instead of a half-finished number, because a score built from only the
/// auto-checked half reads as a fail even when the written answers would have
/// carried it. Nothing is claimed until the company has looked.
///
/// Read [state] rather than testing the numbers: `under_review`, `passed`,
/// `failed` or `timed_out`. Every word on the screen comes from the server as
/// well, so the phone and the website cannot say different things about one
/// attempt.
class AssessmentAttemptResult {
  AssessmentAttemptResult({
    required this.assessmentTitle,
    required this.state,
    required this.score,
    required this.totalPoints,
    required this.percentage,
    required this.passed,
    required this.headline,
    required this.message,
    required this.timedOut,
    this.pendingReview = false,
    this.wasReviewed = false,
    this.companyName = 'the employer',
    this.reviewCounts = const AssessmentReviewCounts(),
    this.reviewDetails = const [],
    this.submittedAt,
    this.reviewedAt,
  });

  final String assessmentTitle;

  /// One of `under_review`, `passed`, `failed`, `timed_out`.
  final String state;

  final int? score;
  final int totalPoints;
  final int? percentage;
  final bool? passed;
  final String headline;
  final String message;

  /// Written answers are still with the company. No verdict and no score are
  /// shown while this is true.
  final bool pendingReview;

  /// The company has since read the written answers, so the score on screen is
  /// the final one rather than a freshly auto-graded guess.
  final bool wasReviewed;

  final String companyName;
  final AssessmentReviewCounts reviewCounts;

  /// The lines explaining what was settled and what is still owed, worded by
  /// the server so both platforms read identically.
  final List<String> reviewDetails;

  /// The countdown submitted this attempt. It is graded, but never a pass.
  final bool timedOut;
  final String? submittedAt;
  final String? reviewedAt;

  bool get isUnderReview => pendingReview || state == 'under_review';

  factory AssessmentAttemptResult.fromJson(Map<String, dynamic> json) =>
      AssessmentAttemptResult(
        assessmentTitle: json['assessment_title'] as String? ?? 'Assessment',
        state: json['state'] as String? ?? 'failed',
        score: (json['score'] as num?)?.toInt(),
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toInt(),
        passed: json['passed'] as bool?,
        headline: json['headline'] as String? ?? 'Assessment complete',
        message: json['message'] as String? ?? '',
        pendingReview: json['pending_review'] as bool? ?? false,
        wasReviewed: json['was_reviewed'] as bool? ?? false,
        companyName: json['company_name'] as String? ?? 'the employer',
        reviewCounts: AssessmentReviewCounts.fromJson(
          json['review_counts'] as Map<String, dynamic>?,
        ),
        reviewDetails: (json['review_details'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        timedOut: json['timed_out'] as bool? ?? false,
        submittedAt: json['submitted_at'] as String?,
        reviewedAt: json['reviewed_at'] as String?,
      );
}
