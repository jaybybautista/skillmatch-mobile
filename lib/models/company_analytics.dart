/// The company dashboard and analytics figures, as returned by
/// Api\CompanyDashboardController.
///
/// Every number is computed server-side by CompanyAnalyticsService — the same
/// class the website's dashboard asks — so the app never does its own maths
/// on top and can never disagree with the web page.
library;

import '../core/json_parse.dart';

/// The dashboard's headline counters.
class CompanyDashboardStats {
  const CompanyDashboardStats({
    required this.totalPostings,
    required this.openPostings,
    required this.closedPostings,
    required this.totalOpenSlots,
    required this.totalApplicants,
    required this.pendingApps,
    required this.interviewApps,
    required this.hiredApps,
    required this.avgMatchScore,
    required this.topMatchCount,
    required this.totalAssessments,
    required this.totalQuizzesTaken,
    required this.avgAssessmentScore,
    required this.totalPlacements,
    required this.activePlacements,
  });

  final int totalPostings;
  final int openPostings;
  final int closedPostings;
  final int totalOpenSlots;
  final int totalApplicants;
  final int pendingApps;
  final int interviewApps;
  final int hiredApps;
  final int avgMatchScore;
  final int topMatchCount;
  final int totalAssessments;
  final int totalQuizzesTaken;
  final int avgAssessmentScore;
  final int totalPlacements;
  final int activePlacements;

  factory CompanyDashboardStats.fromJson(Map<String, dynamic> json) {
    int at(String key) => asInt(json[key]);

    return CompanyDashboardStats(
      totalPostings: at('total_postings'),
      openPostings: at('open_postings'),
      closedPostings: at('closed_postings'),
      totalOpenSlots: at('total_open_slots'),
      totalApplicants: at('total_applicants'),
      pendingApps: at('pending_apps'),
      interviewApps: at('interview_apps'),
      hiredApps: at('hired_apps'),
      avgMatchScore: at('avg_match_score'),
      topMatchCount: at('top_match_count'),
      totalAssessments: at('total_assessments'),
      totalQuizzesTaken: at('total_quizzes_taken'),
      avgAssessmentScore: at('avg_assessment_score'),
      totalPlacements: at('total_placements'),
      activePlacements: at('active_placements'),
    );
  }
}

/// A posting in the dashboard's "recent postings" list.
class DashboardPosting {
  const DashboardPosting({
    required this.id,
    required this.title,
    required this.status,
    required this.slotsAvailable,
    required this.applicationsCount,
    required this.createdAtHuman,
  });

  final int id;
  final String title;
  final String status;
  final int slotsAvailable;
  final int applicationsCount;
  final String createdAtHuman;

  bool get isOpen => status == 'open';

  factory DashboardPosting.fromJson(Map<String, dynamic> json) =>
      DashboardPosting(
        id: asInt(json['id']),
        title: json['title'] as String? ?? 'Untitled posting',
        status: json['status'] as String? ?? 'open',
        slotsAvailable: asInt(json['slots_available']),
        applicationsCount: asInt(json['applications_count']),
        createdAtHuman: json['created_at_human'] as String? ?? '',
      );
}

/// An application in the dashboard's "recent applications" list.
class DashboardApplication {
  const DashboardApplication({
    required this.id,
    required this.status,
    required this.studentId,
    required this.studentName,
    required this.studentAvatarUrl,
    required this.internshipTitle,
    required this.appliedAtHuman,
  });

  final int id;
  final String status;
  final int? studentId;
  final String studentName;
  final String? studentAvatarUrl;
  final String? internshipTitle;
  final String appliedAtHuman;

  factory DashboardApplication.fromJson(Map<String, dynamic> json) =>
      DashboardApplication(
        id: asInt(json['id']),
        status: json['status'] as String? ?? 'pending',
        studentId: asIntOrNull(json['student_id']),
        studentName: json['student_name'] as String? ?? 'Unknown',
        studentAvatarUrl: json['student_avatar_url'] as String?,
        internshipTitle: json['internship_title'] as String?,
        appliedAtHuman: json['applied_at_human'] as String? ?? '',
      );
}

/// A best-matched student in the dashboard's shortlist.
class DashboardCandidate {
  const DashboardCandidate({
    required this.studentId,
    required this.studentName,
    required this.studentAvatarUrl,
    required this.course,
    required this.internshipTitle,
    required this.matchScore,
  });

  final int? studentId;
  final String studentName;
  final String? studentAvatarUrl;
  final String? course;
  final String? internshipTitle;
  final int matchScore;

  factory DashboardCandidate.fromJson(Map<String, dynamic> json) =>
      DashboardCandidate(
        studentId: asIntOrNull(json['student_id']),
        studentName: json['student_name'] as String? ?? 'Unknown',
        studentAvatarUrl: json['student_avatar_url'] as String?,
        course: json['course'] as String?,
        internshipTitle: json['internship_title'] as String?,
        matchScore: asInt(json['match_score']),
      );
}

/// Everything the mobile dashboard renders, in one response.
class CompanyDashboard {
  const CompanyDashboard({
    required this.greeting,
    required this.stats,
    required this.recentPostings,
    required this.recentApplications,
    required this.topCandidates,
  });

  final String greeting;
  final CompanyDashboardStats stats;
  final List<DashboardPosting> recentPostings;
  final List<DashboardApplication> recentApplications;
  final List<DashboardCandidate> topCandidates;

  factory CompanyDashboard.fromJson(Map<String, dynamic> json) =>
      CompanyDashboard(
        greeting: json['greeting'] as String? ?? 'Welcome',
        stats: CompanyDashboardStats.fromJson(
          json['stats'] as Map<String, dynamic>? ?? const {},
        ),
        recentPostings: (json['recent_postings'] as List? ?? const [])
            .map((e) => DashboardPosting.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentApplications: (json['recent_applications'] as List? ?? const [])
            .map(
              (e) => DashboardApplication.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        topCandidates: (json['top_candidates'] as List? ?? const [])
            .map((e) => DashboardCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One stage of the applicant pipeline, with its share of the total.
class PipelineStage {
  const PipelineStage({
    required this.status,
    required this.label,
    required this.count,
    required this.percentage,
  });

  final String status;
  final String label;
  final int count;
  final int percentage;

  factory PipelineStage.fromJson(Map<String, dynamic> json) => PipelineStage(
    status: json['status'] as String? ?? '',
    label: json['label'] as String? ?? '',
    count: asInt(json['count']),
    percentage: asInt(json['percentage']),
  );
}

/// A posting the pipeline can be narrowed to — the web page's dropdown.
class PostingOption {
  const PostingOption({required this.id, required this.title});

  final int id;
  final String title;

  factory PostingOption.fromJson(Map<String, dynamic> json) => PostingOption(
    id: asInt(json['id']),
    title: json['title'] as String? ?? 'Untitled',
  );
}

/// A row of the assessment participation table.
class AssessmentRow {
  const AssessmentRow({
    required this.id,
    required this.title,
    required this.questionsCount,
  });

  final int id;
  final String title;
  final int questionsCount;

  factory AssessmentRow.fromJson(Map<String, dynamic> json) => AssessmentRow(
    id: asInt(json['id']),
    title: json['title'] as String? ?? 'Untitled assessment',
    questionsCount: asInt(json['questions_count']),
  );
}

/// A row of the recruitment activity feed.
class ActivityRow {
  const ActivityRow({
    required this.id,
    required this.studentName,
    required this.internshipTitle,
    required this.status,
    required this.assignedAssessment,
    required this.updatedAtHuman,
  });

  final int id;
  final String studentName;
  final String? internshipTitle;
  final String status;
  final String? assignedAssessment;
  final String updatedAtHuman;

  factory ActivityRow.fromJson(Map<String, dynamic> json) => ActivityRow(
    id: asInt(json['id']),
    studentName: json['student_name'] as String? ?? 'Unknown Student',
    internshipTitle: json['internship_title'] as String?,
    status: json['status'] as String? ?? '',
    assignedAssessment: json['assigned_assessment'] as String?,
    updatedAtHuman: json['updated_at_human'] as String? ?? '',
  );
}

/// The analytics screen's whole payload.
class CompanyAnalytics {
  const CompanyAnalytics({
    required this.totalPostings,
    required this.openPostings,
    required this.closedPostings,
    required this.openSlots,
    required this.slotsFilled,
    required this.applicantCounts,
    required this.avgMatchScore,
    required this.highMatchCount,
    required this.totalAssessments,
    required this.quizzesTaken,
    required this.avgQuizScore,
    required this.totalPlacements,
    required this.activePlacements,
    required this.pipelineTotal,
    required this.pipelineStages,
    required this.pipelineFilter,
    required this.postingOptions,
    required this.assessmentRows,
    required this.recentActivity,
  });

  final int totalPostings;
  final int openPostings;
  final int closedPostings;
  final int openSlots;
  final int slotsFilled;

  /// Keyed by status ('total', 'pending', 'under_review', …).
  final Map<String, int> applicantCounts;

  final int avgMatchScore;
  final int highMatchCount;
  final int totalAssessments;
  final int quizzesTaken;
  final int avgQuizScore;
  final int totalPlacements;
  final int activePlacements;

  final int pipelineTotal;
  final List<PipelineStage> pipelineStages;

  /// The posting the pipeline is currently narrowed to, or null for all.
  final int? pipelineFilter;

  final List<PostingOption> postingOptions;
  final List<AssessmentRow> assessmentRows;
  final List<ActivityRow> recentActivity;

  int get totalApplicants => applicantCounts['total'] ?? 0;
  int get pendingApps => applicantCounts['pending'] ?? 0;

  factory CompanyAnalytics.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) =>
        json[key] as Map<String, dynamic>? ?? const {};

    int from(String key, String field) =>
        asInt(section(key)[field]);

    final pipeline = section('pipeline');

    return CompanyAnalytics(
      totalPostings: from('postings', 'total'),
      openPostings: from('postings', 'open'),
      closedPostings: from('postings', 'closed'),
      openSlots: from('postings', 'open_slots'),
      slotsFilled: from('postings', 'slots_filled'),
      applicantCounts: {
        for (final entry in section('applicants').entries)
          entry.key: asInt(entry.value),
      },
      avgMatchScore: from('matching', 'average_score'),
      highMatchCount: from('matching', 'high_match_count'),
      totalAssessments: from('assessments', 'total'),
      quizzesTaken: from('assessments', 'quizzes_taken'),
      avgQuizScore: from('assessments', 'average_score'),
      totalPlacements: from('placements', 'total'),
      activePlacements: from('placements', 'active'),
      pipelineTotal: asInt(pipeline['total']),
      pipelineStages: (pipeline['stages'] as List? ?? const [])
          .map((e) => PipelineStage.fromJson(e as Map<String, dynamic>))
          .toList(),
      pipelineFilter: asIntOrNull(json['pipeline_filter']),
      postingOptions: (json['posting_options'] as List? ?? const [])
          .map((e) => PostingOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      assessmentRows: (json['assessment_rows'] as List? ?? const [])
          .map((e) => AssessmentRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentActivity: (json['recent_activity'] as List? ?? const [])
          .map((e) => ActivityRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
