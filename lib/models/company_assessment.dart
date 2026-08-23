import '../core/json_parse.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'assessment.dart';

/// One assessment on the company side — the same `assessments` row the
/// website's assessment library lists, authored through the shared
/// CompanyAssessmentService so a paper written on the phone and one written
/// in the browser are stored identically.
class CompanyAssessment {
  const CompanyAssessment({
    required this.id,
    required this.internshipId,
    required this.internshipTitle,
    this.internships = const [],
    required this.title,
    required this.description,
    required this.timeLimitMinutes,
    required this.totalPoints,
    required this.status,
    required this.questionCount,
    required this.submissionCount,
    this.submissionScopeInternshipId,
    required this.createdAtHuman,
    this.questions = const [],
  });

  final int id;

  /// Where this assessment was first written. Kept because older rows have
  /// it and the API still sends it, but it is no longer what decides which
  /// postings screen with this paper — [internships] is.
  final int? internshipId;
  final String? internshipTitle;

  /// Every posting that screens with this assessment. One paper can be
  /// reused across as many postings as the company likes; the link lives in
  /// the `assessment_internship` pivot both platforms write to.
  final List<AssessmentPostingOption> internships;

  final String title;
  final String? description;

  /// Null when the company set no limit, in which case the quiz runs untimed.
  final int? timeLimitMinutes;

  final int totalPoints;

  /// 'draft' until questions are saved, then 'published'.
  final String status;

  final int questionCount;

  /// How many students have completed this paper. Counted for one posting
  /// when this card came from a posting's group, and across every posting
  /// when it did not — [submissionScopeInternshipId] says which.
  final int submissionCount;

  /// The posting [submissionCount] was counted for, or null when it counts
  /// everyone.
  final int? submissionScopeInternshipId;

  final String createdAtHuman;

  /// Only populated by the endpoints that return the whole paper (show,
  /// store, update) — the library list leaves it empty.
  final List<CompanyAssessmentQuestion> questions;

  bool get isPublished => status == 'published';
  bool get isDraft => status != 'published';

  /// The ids this assessment is currently linked to, for handing straight
  /// back to the update endpoint.
  List<int> get internshipIds => internships.map((i) => i.id).toList();

  /// True when this one paper screens for more than one posting.
  ///
  /// Worth saying on screen: it is the difference between "this belongs to
  /// that posting" and "editing this changes what several postings ask".
  bool get isShared => internships.length > 1;

  /// What to show under the title: which postings this paper screens for,
  /// named rather than counted. A count alone ("2 postings") is what made a
  /// reused assessment unreadable — two cards, same title, same count, no
  /// way to tell what either was for.
  String? get postingsLabel {
    if (internships.isEmpty) return internshipTitle;
    return internships.map((i) => i.title).join(', ');
  }

  factory CompanyAssessment.fromJson(Map<String, dynamic> json) =>
      CompanyAssessment(
        id: asInt(json['id']),
        internshipId: asIntOrNull(json['internship_id']),
        internshipTitle: json['internship_title'] as String?,
        internships: (json['internships'] as List? ?? const [])
            .map(
              (e) => AssessmentPostingOption.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        title: json['title'] as String? ?? 'Untitled assessment',
        description: json['description'] as String?,
        timeLimitMinutes: asIntOrNull(json['time_limit']),
        totalPoints: asInt(json['total_points']),
        status: json['status'] as String? ?? 'draft',
        questionCount: asInt(json['question_count']),
        submissionCount: asInt(json['submission_count']),
        submissionScopeInternshipId: asIntOrNull(
          json['submission_scope_internship_id'],
        ),
        createdAtHuman: json['created_at_human'] as String? ?? '',
        questions: (json['questions'] as List? ?? const [])
            .map(
              (e) =>
                  CompanyAssessmentQuestion.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}

/// A question as its author sees it — unlike the student-facing
/// [AssessmentQuestion], this one carries which choices are correct, because
/// only the company that wrote the paper can reach it.
class CompanyAssessmentQuestion {
  const CompanyAssessmentQuestion({
    required this.id,
    required this.text,
    required this.description,
    required this.type,
    required this.imageUrl,
    required this.points,
    required this.choices,
  });

  final int id;
  final String text;
  final String? description;
  final QuestionType type;

  /// Either an http(s) URL or an inline `data:image/...;base64,` URI, which
  /// is what both question builders produce.
  final String? imageUrl;

  final int points;
  final List<CompanyAssessmentChoice> choices;

  factory CompanyAssessmentQuestion.fromJson(Map<String, dynamic> json) =>
      CompanyAssessmentQuestion(
        id: asInt(json['id']),
        text: json['question_text'] as String? ?? '',
        description: json['description'] as String?,
        type: QuestionType.parse(json['question_type'] as String?),
        imageUrl: json['image_url'] as String?,
        points: asInt(json['points'], 1),
        choices: (json['choices'] as List? ?? const [])
            .map(
              (e) =>
                  CompanyAssessmentChoice.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      );
}

class CompanyAssessmentChoice {
  const CompanyAssessmentChoice({
    required this.id,
    required this.text,
    required this.isCorrect,
  });

  final int id;
  final String text;
  final bool isCorrect;

  factory CompanyAssessmentChoice.fromJson(Map<String, dynamic> json) =>
      CompanyAssessmentChoice(
        id: asInt(json['id']),
        text: json['choice_text'] as String? ?? '',
        isCorrect: json['is_correct'] as bool? ?? false,
      );
}

/// A posting an assessment can be attached to. Open postings are offered,
/// plus any closed one this assessment is already linked to — matching the
/// web's picker, and for the same reason: a posting missing from the list
/// would be silently unlinked the moment the form is saved.
class AssessmentPostingOption {
  const AssessmentPostingOption({required this.id, required this.title});

  final int id;
  final String title;

  factory AssessmentPostingOption.fromJson(Map<String, dynamic> json) =>
      AssessmentPostingOption(
        id: asInt(json['id']),
        title: json['title'] as String? ?? 'Untitled posting',
      );
}

/// One posting and the assessments that screen for it.
///
/// This is how the library reads on both platforms: a heading per posting,
/// with its papers underneath. A paper used by two postings appears under
/// both — not as a copy, but as the same paper doing a job in two places,
/// and its submission count under each heading is the applicants who took
/// it *for that posting*.
class AssessmentGroup {
  const AssessmentGroup({
    required this.internshipId,
    required this.internshipTitle,
    required this.status,
    required this.assessments,
  });

  final int internshipId;
  final String internshipTitle;

  /// 'open' or 'closed', shown next to the heading the way the postings
  /// list shows it.
  final String status;

  final List<CompanyAssessment> assessments;

  bool get isOpen => status == 'open';

  factory AssessmentGroup.fromJson(Map<String, dynamic> json) =>
      AssessmentGroup(
        internshipId: asInt(json['internship_id']),
        internshipTitle: json['internship_title'] as String? ?? 'Untitled posting',
        status: json['status'] as String? ?? 'open',
        assessments: (json['assessments'] as List? ?? const [])
            .map((e) => CompanyAssessment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// What the edit form needs in one round trip: the whole paper, and the
/// postings its picker may offer for this particular assessment.
class AssessmentEdit {
  const AssessmentEdit({
    required this.assessment,
    required this.postingOptions,
  });

  final CompanyAssessment assessment;
  final List<AssessmentPostingOption> postingOptions;
}

/// The library payload: the assessments plus the postings a new one can go
/// under.
class AssessmentLibrary {
  const AssessmentLibrary({
    required this.assessments,
    required this.postingOptions,
    this.groups = const [],
  });

  /// Every assessment once, however many postings use it, counted across
  /// all of them. This is the paper itself — what the "reuse an existing
  /// assessment" picker offers.
  final List<CompanyAssessment> assessments;

  final List<AssessmentPostingOption> postingOptions;

  /// The same assessments arranged under the postings they screen for,
  /// which is what the library screen shows.
  final List<AssessmentGroup> groups;

  factory AssessmentLibrary.fromJson(Map<String, dynamic> json) =>
      AssessmentLibrary(
        // One card per assessment. The server groups them under the posting
        // they screen for, so a paper reused across three postings arrives
        // three times; de-duplicating here as well means an app talking to
        // an older server still shows it once.
        assessments: _uniqueById(
          (json['assessments'] as List? ?? const [])
              .map((e) => CompanyAssessment.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        postingOptions: (json['posting_options'] as List? ?? const [])
            .map(
              (e) =>
                  AssessmentPostingOption.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        groups: (json['groups'] as List? ?? const [])
            .map((e) => AssessmentGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

List<CompanyAssessment> _uniqueById(List<CompanyAssessment> assessments) {
  final seen = <int>{};
  return assessments.where((a) => seen.add(a.id)).toList();
}

/// Colour pair for an assessment's status pill.
({Color background, Color text}) assessmentStatusColors(String status) {
  return status == 'published'
      ? (background: const Color(0xFFEAFAF1), text: const Color(0xFF1A7F4B))
      : (background: AppColors.warningBackground, text: AppColors.warning);
}
