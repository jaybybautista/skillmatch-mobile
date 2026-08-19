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

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory AssessmentSubmission.fromJson(Map<String, dynamic> json) => AssessmentSubmission(
        id: (json['id'] as num).toInt(),
        studentId: (json['student_id'] as num?)?.toInt(),
        name: json['student_name'] as String? ?? 'Unknown',
        email: json['student_email'] as String?,
        avatarUrl: json['student_avatar_url'] as String?,
        score: (json['score'] as num?)?.toInt() ?? 0,
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        percentage: (json['percentage'] as num?)?.toInt() ?? 0,
        passed: json['passed'] as bool? ?? false,
        timedOut: json['timed_out'] as bool? ?? false,
        submittedAtLabel: json['submitted_at_label'] as String? ?? '',
      );
}
