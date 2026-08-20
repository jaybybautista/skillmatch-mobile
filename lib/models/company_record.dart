/// Records and reports — the read-only history behind a company's postings,
/// the same rows the website's Records pages list.
library;

import '../core/json_parse.dart';

/// One application, as the records table lists it.
class ApplicationRecord {
  const ApplicationRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.avatarUrl,
    required this.course,
    required this.campus,
    required this.internshipTitle,
    required this.status,
    required this.appliedAt,
    required this.updatedAtHuman,
  });

  final int id;
  final int? studentId;
  final String studentName;
  final String? avatarUrl;
  final String? course;
  final String? campus;
  final String? internshipTitle;
  final String status;
  final String? appliedAt;
  final String updatedAtHuman;

  factory ApplicationRecord.fromJson(Map<String, dynamic> json) =>
      ApplicationRecord(
        id: asInt(json['id']),
        studentId: asIntOrNull(json['student_id']),
        studentName: json['student_name'] as String? ?? 'Unknown',
        avatarUrl: json['avatar_url'] as String?,
        course: json['course'] as String?,
        campus: json['campus'] as String?,
        internshipTitle: json['internship_title'] as String?,
        status: json['status'] as String? ?? '',
        appliedAt: json['applied_at'] as String?,
        updatedAtHuman: json['updated_at_human'] as String? ?? '',
      );
}

/// One completed assessment attempt.
class AssessmentRecord {
  const AssessmentRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.avatarUrl,
    required this.course,
    required this.assessmentTitle,
    required this.internshipTitle,
    required this.score,
    required this.totalPoints,
    required this.percentage,
    required this.passed,
    required this.timedOut,
    required this.submittedAt,
  });

  final int id;
  final int? studentId;
  final String studentName;
  final String? avatarUrl;
  final String? course;
  final String? assessmentTitle;
  final String? internshipTitle;
  final int score;
  final int totalPoints;
  final int percentage;

  /// Decided server-side by the same service that graded the attempt.
  final bool passed;
  final bool timedOut;

  final String? submittedAt;

  factory AssessmentRecord.fromJson(Map<String, dynamic> json) =>
      AssessmentRecord(
        id: asInt(json['id']),
        studentId: asIntOrNull(json['student_id']),
        studentName: json['student_name'] as String? ?? 'Unknown',
        avatarUrl: json['avatar_url'] as String?,
        course: json['course'] as String?,
        assessmentTitle: json['assessment_title'] as String?,
        internshipTitle: json['internship_title'] as String?,
        score: asInt(json['score']),
        totalPoints: asInt(json['total_points']),
        percentage: asInt(json['percentage']),
        passed: json['passed'] as bool? ?? false,
        timedOut: json['timed_out'] as bool? ?? false,
        submittedAt: json['submitted_at'] as String?,
      );
}

/// One placement, as the records table lists it.
class PlacementRecord {
  const PlacementRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.avatarUrl,
    required this.campus,
    required this.internshipTitle,
    required this.coordinatorName,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  final int id;
  final int? studentId;
  final String studentName;
  final String? avatarUrl;
  final String? campus;
  final String? internshipTitle;
  final String? coordinatorName;
  final String status;
  final String? startDate;
  final String? endDate;

  factory PlacementRecord.fromJson(Map<String, dynamic> json) =>
      PlacementRecord(
        id: asInt(json['id']),
        studentId: asIntOrNull(json['student_id']),
        studentName: json['student_name'] as String? ?? 'Unknown',
        avatarUrl: json['avatar_url'] as String?,
        campus: json['campus'] as String?,
        internshipTitle: json['internship_title'] as String?,
        coordinatorName: json['coordinator_name'] as String?,
        status: json['status'] as String? ?? '',
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
      );
}

/// A posting the record filters can be narrowed to.
class RecordPostingOption {
  const RecordPostingOption({required this.id, required this.title});

  final int id;
  final String title;

  factory RecordPostingOption.fromJson(Map<String, dynamic> json) =>
      RecordPostingOption(
        id: asInt(json['id']),
        title: json['title'] as String? ?? 'Untitled posting',
      );
}

/// The records landing payload: four counters plus what the filters offer.
class RecordsOverview {
  const RecordsOverview({
    required this.totalApplications,
    required this.totalPlacements,
    required this.totalAssessments,
    required this.totalCompleted,
    required this.postingOptions,
    required this.placementStatuses,
  });

  final int totalApplications;
  final int totalPlacements;
  final int totalAssessments;

  /// Assessment attempts actually submitted, not assessments created.
  final int totalCompleted;

  final List<RecordPostingOption> postingOptions;
  final List<String> placementStatuses;

  factory RecordsOverview.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    int at(String key) => asInt(stats[key]);

    return RecordsOverview(
      totalApplications: at('total_applications'),
      totalPlacements: at('total_placements'),
      totalAssessments: at('total_assessments'),
      totalCompleted: at('total_completed'),
      postingOptions: (json['posting_options'] as List? ?? const [])
          .map((e) => RecordPostingOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      placementStatuses: (json['placement_statuses'] as List? ?? const [])
          .map((e) => '$e')
          .toList(),
    );
  }
}
