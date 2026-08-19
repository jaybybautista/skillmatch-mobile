/// Whether a company has acted on a candidate's completed attempt yet.
enum SubmissionStatus { pending, accepted, rejected }

/// One candidate's completed attempt at a [CompanyAssessment] — shown as a
/// card on [AssessmentSubmissionsScreen].
///
/// TODO: static placeholder data — there is no company-submissions endpoint
/// on the backend yet (same caveat as [CompanyPosting]/[CompanyAssessment]).
class AssessmentSubmission {
  AssessmentSubmission({
    required this.name,
    required this.email,
    required this.completedDate,
    required this.score,
    required this.totalScore,
    this.status = SubmissionStatus.pending,
  });

  final String name;
  final String email;
  final String completedDate;
  final int score;
  final int totalScore;
  SubmissionStatus status;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Same placeholder list regardless of which assessment it's shown under —
/// there's no per-assessment submissions endpoint to distinguish them yet.
List<AssessmentSubmission> placeholderSubmissions() => [
  AssessmentSubmission(
    name: 'Alexandria Rivera',
    email: 'alex.rivera@gmail.com',
    completedDate: 'Oct 24, 2023',
    score: 18,
    totalScore: 24,
    status: SubmissionStatus.accepted,
  ),
  AssessmentSubmission(
    name: 'Marcus Thorne',
    email: 'm.thorne@gmail.com',
    completedDate: 'Oct 24, 2023',
    score: 18,
    totalScore: 24,
    status: SubmissionStatus.rejected,
  ),
  AssessmentSubmission(
    name: 'Jordan Smith',
    email: 'jsmith_design@gmail.com',
    completedDate: 'Oct 24, 2023',
    score: 18,
    totalScore: 24,
  ),
];
