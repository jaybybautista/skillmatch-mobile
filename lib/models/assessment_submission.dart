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

/// How long attempts took, across whatever list is currently shown.
class SubmissionTiming {
  const SubmissionTiming({
    this.count = 0,
    this.averageSeconds,
    this.fastestSeconds,
    this.slowestSeconds,
  });

  /// How many of the listed attempts actually have a duration. Attempts taken
  /// before the server started recording a start time have none.
  final int count;
  final int? averageSeconds;
  final int? fastestSeconds;
  final int? slowestSeconds;

  bool get hasData => count > 0;

  /// Same shape the web uses, so both platforms read alike.
  static String format(int? seconds) {
    if (seconds == null) return 'Not recorded';
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes < 60) return rest > 0 ? '${minutes}m ${rest}s' : '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }

  factory SubmissionTiming.fromJson(Map<String, dynamic> json) =>
      SubmissionTiming(
        count: asInt(json['count']),
        averageSeconds: asIntOrNull(json['average']),
        fastestSeconds: asIntOrNull(json['fastest']),
        slowestSeconds: asIntOrNull(json['slowest']),
      );
}

/// The submissions list plus the postings it can be split by.
class AssessmentSubmissions {
  const AssessmentSubmissions({
    required this.submissions,
    this.postings = const [],
    this.unattributedCount = 0,
    this.timing = const SubmissionTiming(),
  });

  final List<AssessmentSubmission> submissions;

  final SubmissionTiming timing;

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
        timing: SubmissionTiming.fromJson(
          (json['timing'] as Map<String, dynamic>?) ?? const {},
        ),
      );
}

/// One student's completed attempt at a company's assessment — the same
/// `assessment_results` row the website's Records → Assessments table lists.
///
/// The score itself was computed by the shared AssessmentService when the
/// student submitted, and nothing here can change it directly. The one
/// action available is Retake: it re-runs the same assignment the company
/// would use to hand this paper out in the first place, on the [applicationId]
/// this attempt came through, which opens a fresh attempt window without
/// touching the score already on record.
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
    this.durationLabel,
    this.applicationId,
    this.retakeOpen = false,
  });

  /// The application Retake reassigns this paper to. Null when the server
  /// could no longer tell which application this attempt came through, in
  /// which case there is nothing safe to retake.
  final int? applicationId;

  /// A fresh attempt has been opened and the student has not answered it yet.
  ///
  /// Only ever true on a student's most recent attempt, so their older ones
  /// do not all light up at once. It clears itself the moment they submit
  /// again, which is what makes it a standing indicator rather than a
  /// message that disappears on the next page load.
  final bool retakeOpen;

  /// How long this attempt took, already formatted by the server. Null for
  /// attempts taken before the start time was recorded.
  final String? durationLabel;

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
        durationLabel: json['duration_label'] as String?,
        applicationId: asIntOrNull(json['application_id']),
        retakeOpen: json['retake_open'] as bool? ?? false,
      );
}
