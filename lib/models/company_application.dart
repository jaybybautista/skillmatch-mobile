import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The student attached to an application or candidate row.
class CandidateSummary {
  const CandidateSummary({
    required this.id,
    required this.name,
    this.email,
    this.course,
    this.yearLevel,
    this.campus,
    this.avatarUrl,
    required this.initials,
    this.skills = const [],
  });

  final int? id;
  final String name;
  final String? email;
  final String? course;
  final int? yearLevel;
  final String? campus;
  final String? avatarUrl;
  final String initials;
  final List<String> skills;

  factory CandidateSummary.fromJson(Map<String, dynamic> json) {
    return CandidateSummary(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String? ?? 'Student',
      email: json['email'] as String?,
      course: json['course'] as String?,
      yearLevel: (json['year_level'] as num?)?.toInt(),
      campus: json['campus'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      initials: json['initials'] as String? ?? 'S',
      skills: (json['skills'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

/// One application to one of the company's postings — the same `applications`
/// row the website's Applications page manages.
class CompanyApplication {
  const CompanyApplication({
    required this.id,
    required this.status,
    required this.statusLabel,
    this.rejectionReason,
    required this.canUndo,
    this.previousStatus,
    this.appliedAtHuman,
    required this.internshipId,
    required this.internshipTitle,
    required this.student,
    this.assignedAssessmentId,
    this.assignedAssessmentTitle,
  });

  final int id;
  final String status;
  final String statusLabel;
  final String? rejectionReason;

  /// True when the last status change can still be reverted (one level).
  final bool canUndo;
  final String? previousStatus;
  final String? appliedAtHuman;
  final int? internshipId;
  final String internshipTitle;
  final CandidateSummary student;

  /// The competency assessment this applicant has been handed, if any — the
  /// same field the web's activity table shows.
  final int? assignedAssessmentId;
  final String? assignedAssessmentTitle;

  factory CompanyApplication.fromJson(Map<String, dynamic> json) {
    return CompanyApplication(
      id: (json['id'] as num).toInt(),
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['status_label'] as String? ?? 'Pending',
      rejectionReason: json['rejection_reason'] as String?,
      canUndo: json['can_undo'] as bool? ?? false,
      previousStatus: json['previous_status'] as String?,
      appliedAtHuman: json['applied_at_human'] as String?,
      internshipId: (json['internship_id'] as num?)?.toInt(),
      internshipTitle: json['internship_title'] as String? ?? 'Internship',
      assignedAssessmentId: (json['assigned_assessment_id'] as num?)?.toInt(),
      assignedAssessmentTitle: json['assigned_assessment_title'] as String?,
      student: CandidateSummary.fromJson(json['student'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

/// Per-status totals driving the filter chips.
class ApplicationCounts {
  const ApplicationCounts(this._counts);

  final Map<String, int> _counts;

  int operator [](String key) => _counts[key] ?? 0;

  factory ApplicationCounts.fromJson(Map<String, dynamic> json) {
    return ApplicationCounts(json.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)));
  }
}

/// A student in the Browse Candidates list, with the company's own match
/// score against them.
class Candidate {
  const Candidate({
    required this.summary,
    required this.matchScore,
    this.matchedSkills = const [],
    this.assessmentScore,
    required this.isBookmarked,
    this.isOnOjt = false,
  });

  final CandidateSummary summary;
  final int matchScore;
  final List<String> matchedSkills;
  final int? assessmentScore;
  final bool isBookmarked;
  final bool isOnOjt;

  int get id => summary.id ?? 0;

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      summary: CandidateSummary.fromJson(json),
      matchScore: (json['match_score'] as num?)?.toInt() ?? 0,
      matchedSkills:
          (json['matched_skills'] as List? ?? const []).map((e) => e.toString()).toList(),
      assessmentScore: (json['assessment_score'] as num?)?.toInt(),
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      isOnOjt: json['is_on_ojt'] as bool? ?? false,
    );
  }

  Candidate copyWith({bool? isBookmarked}) {
    return Candidate(
      summary: summary,
      matchScore: matchScore,
      matchedSkills: matchedSkills,
      assessmentScore: assessmentScore,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isOnOjt: isOnOjt,
    );
  }
}

/// The palette the web uses for each application status, so both platforms
/// colour a status the same way.
({Color background, Color text}) applicationStatusColors(String status) {
  return switch (status) {
    'pending' => (background: const Color(0xFFFFF4E5), text: const Color(0xFFB87700)),
    'under_review' => (background: const Color(0xFFE8EEFF), text: const Color(0xFF3D6EF5)),
    'interview' => (background: const Color(0xFFF3EEFE), text: const Color(0xFF7C3AED)),
    'accepted' => (background: const Color(0xFFEAFAF1), text: const Color(0xFF1A7F4B)),
    'rejected' => (background: const Color(0xFFFFF1F1), text: AppColors.danger),
    _ => (background: const Color(0xFFF1F5F9), text: const Color(0xFF64748B)),
  };
}
