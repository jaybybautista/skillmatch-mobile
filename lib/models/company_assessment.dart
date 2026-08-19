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
    required this.title,
    required this.description,
    required this.timeLimitMinutes,
    required this.totalPoints,
    required this.status,
    required this.questionCount,
    required this.submissionCount,
    required this.createdAtHuman,
    this.questions = const [],
  });

  final int id;

  /// The posting this assessment screens for. Required by the backend — an
  /// assessment always belongs to exactly one posting.
  final int? internshipId;
  final String? internshipTitle;

  final String title;
  final String? description;

  /// Null when the company set no limit, in which case the quiz runs untimed.
  final int? timeLimitMinutes;

  final int totalPoints;

  /// 'draft' until questions are saved, then 'published'.
  final String status;

  final int questionCount;
  final int submissionCount;
  final String createdAtHuman;

  /// Only populated by the endpoints that return the whole paper (show,
  /// store, update) — the library list leaves it empty.
  final List<CompanyAssessmentQuestion> questions;

  bool get isPublished => status == 'published';
  bool get isDraft => status != 'published';

  factory CompanyAssessment.fromJson(Map<String, dynamic> json) => CompanyAssessment(
        id: (json['id'] as num).toInt(),
        internshipId: (json['internship_id'] as num?)?.toInt(),
        internshipTitle: json['internship_title'] as String?,
        title: json['title'] as String? ?? 'Untitled assessment',
        description: json['description'] as String?,
        timeLimitMinutes: (json['time_limit'] as num?)?.toInt(),
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'draft',
        questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
        submissionCount: (json['submission_count'] as num?)?.toInt() ?? 0,
        createdAtHuman: json['created_at_human'] as String? ?? '',
        questions: (json['questions'] as List? ?? const [])
            .map((e) => CompanyAssessmentQuestion.fromJson(e as Map<String, dynamic>))
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
        id: (json['id'] as num).toInt(),
        text: json['question_text'] as String? ?? '',
        description: json['description'] as String?,
        type: QuestionType.parse(json['question_type'] as String?),
        imageUrl: json['image_url'] as String?,
        points: (json['points'] as num?)?.toInt() ?? 1,
        choices: (json['choices'] as List? ?? const [])
            .map((e) => CompanyAssessmentChoice.fromJson(e as Map<String, dynamic>))
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
        id: (json['id'] as num?)?.toInt() ?? 0,
        text: json['choice_text'] as String? ?? '',
        isCorrect: json['is_correct'] as bool? ?? false,
      );
}

/// A posting an assessment can be attached to. Only open postings are
/// offered, matching the web's create/edit dropdown.
class AssessmentPostingOption {
  const AssessmentPostingOption({required this.id, required this.title});

  final int id;
  final String title;

  factory AssessmentPostingOption.fromJson(Map<String, dynamic> json) =>
      AssessmentPostingOption(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? 'Untitled posting',
      );
}

/// The library payload: the assessments plus the postings a new one can go
/// under.
class AssessmentLibrary {
  const AssessmentLibrary({
    required this.assessments,
    required this.postingOptions,
  });

  final List<CompanyAssessment> assessments;
  final List<AssessmentPostingOption> postingOptions;

  factory AssessmentLibrary.fromJson(Map<String, dynamic> json) => AssessmentLibrary(
        assessments: (json['assessments'] as List? ?? const [])
            .map((e) => CompanyAssessment.fromJson(e as Map<String, dynamic>))
            .toList(),
        postingOptions: (json['posting_options'] as List? ?? const [])
            .map((e) => AssessmentPostingOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Colour pair for an assessment's status pill.
({Color background, Color text}) assessmentStatusColors(String status) {
  return status == 'published'
      ? (background: const Color(0xFFEAFAF1), text: const Color(0xFF1A7F4B))
      : (background: AppColors.warningBackground, text: AppColors.warning);
}
