import '../core/json_parse.dart';

/// A posting the submissions list can be narrowed to, and how many
/// attempts belong to it.
class SubmissionPosting {
  const SubmissionPosting({
    required this.id,
    required this.title,
    required this.submissionCount,
  });

  final int id;
  final String title;
  final int submissionCount;

  factory SubmissionPosting.fromJson(Map<String, dynamic> json) =>
      SubmissionPosting(
        id: asInt(json['id']),
        title: json['title'] as String? ?? 'Untitled posting',
        submissionCount: asInt(json['submission_count']),
      );
}

/// The submissions list plus the postings it can be split by.
class AssessmentSubmissions {
  const AssessmentSubmissions({
    required this.submissions,
    this.postings = const [],
    this.unattributedCount = 0,
  });

  final List<AssessmentSubmission> submissions;

  /// Every posting this paper screens for, each with its own total. Shown
  /// as a filter only when there is more than one — one posting is not a
  /// choice.
  final List<SubmissionPosting> postings;

  /// Attempts that could not be traced back to a posting.
  final int unattributedCount;

  factory AssessmentSubmissions.fromJson(Map<String, dynamic> json) =>
      AssessmentSubmissions(
        submissions: (json['submissions'] as List? ?? const [])
            .map((e) => AssessmentSubmission.fromJson(e as Map<String, dynamic>))
            .toList(),
        postings: (json['postings'] as List? ?? const [])
            .map((e) => SubmissionPosting.fromJson(e as Map<String, dynamic>))
            .toList(),
        unattributedCount: asInt(json['unattributed_count']),
      );
}

/// One student's completed attempt at a company's assessment — the same
/// `assessment_results` row the website's Records → Assessments table lists.
///
/// Read-only on both platforms: the score was computed by the shared
/// AssessmentService when the student submitted, and nothing here can change
/// it. Deciding what to do about a candidate happens on their application,
/// not on the attempt.
class AssessmentSubmission {
  const AssessmentSubmission({
    required this.id,
    required this.studentId,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.score,
    required this.totalPoints,
    required this.percentage,
    required this.passed,
    required this.timedOut,
    required this.submittedAtLabel,
    this.internshipId,
    this.internshipTitle,
  });

  final int id;
  final int? studentId;
  final String name;
  final String? email;
  final String? avatarUrl;

  final int score;
  final int totalPoints;
  final int percentage;

  /// Computed server-side by AssessmentService — the same verdict the student
  /// saw on their own result screen.
  final bool passed;

  /// The countdown submitted this attempt. It is still graded, but a timed-out
  /// attempt never passes however well the answered questions scored.
  final bool timedOut;

  final String submittedAtLabel;

  /// The posting this attempt was taken for.
  ///
  /// `assessment_results` has no posting column — a student reaches a paper
  /// through their application to a posting, either because the company
  /// assigned it there or because that posting screens with it, and the
  /// server works out which application this attempt came through. Null when
  /// it cannot be told any more, which is what happens if the posting was
  /// unlinked after the attempt.
  final int? internshipId;
  final String? internshipTitle;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AssessmentSubmission.fromJson(Map<String, dynamic> json) =>
      AssessmentSubmission(
        id: asInt(json['id']),
        studentId: asIntOrNull(json['student_id']),
        name: json['student_name'] as String? ?? 'Unknown',
        email: json['student_email'] as String?,
        avatarUrl: json['student_avatar_url'] as String?,
        score: asInt(json['score']),
        totalPoints: asInt(json['total_points']),
        percentage: asInt(json['percentage']),
        passed: json['passed'] as bool? ?? false,
        timedOut: json['timed_out'] as bool? ?? false,
        submittedAtLabel: json['submitted_at_label'] as String? ?? '',
        internshipId: asIntOrNull(json['internship_id']),
        internshipTitle: json['internship_title'] as String?,
      );
}
