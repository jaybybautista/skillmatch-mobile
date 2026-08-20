import '../core/json_parse.dart';
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
      id: asIntOrNull(json['id']),
      name: json['name'] as String? ?? 'Student',
      email: json['email'] as String?,
      course: json['course'] as String?,
      yearLevel: asIntOrNull(json['year_level']),
      campus: json['campus'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      initials: json['initials'] as String? ?? 'S',
      skills: (json['skills'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
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
    this.matchScore,
    this.matchedSkills = const [],
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

  /// How well this student matches the posting they applied to. Null when the
  /// matcher hasn't run for the pair — which is not the same as a zero score.
  final int? matchScore;
  final List<String> matchedSkills;

  factory CompanyApplication.fromJson(Map<String, dynamic> json) {
    return CompanyApplication(
      id: asInt(json['id']),
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['status_label'] as String? ?? 'Pending',
      rejectionReason: json['rejection_reason'] as String?,
      canUndo: json['can_undo'] as bool? ?? false,
      previousStatus: json['previous_status'] as String?,
      appliedAtHuman: json['applied_at_human'] as String?,
      internshipId: asIntOrNull(json['internship_id']),
      internshipTitle: json['internship_title'] as String? ?? 'Internship',
      matchScore: asIntOrNull(json['match_score']),
      matchedSkills: (json['matched_skills'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      assignedAssessmentId: asIntOrNull(json['assigned_assessment_id']),
      assignedAssessmentTitle: json['assigned_assessment_title'] as String?,
      student: CandidateSummary.fromJson(
        json['student'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// Per-status totals driving the filter chips.
class ApplicationCounts {
  const ApplicationCounts(this._counts);

  final Map<String, int> _counts;

  int operator [](String key) => _counts[key] ?? 0;

  factory ApplicationCounts.fromJson(Map<String, dynamic> json) {
    return ApplicationCounts(
      json.map((k, v) => MapEntry(k, asInt(v))),
    );
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
      matchScore: asInt(json['match_score']),
      matchedSkills: (json['matched_skills'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      assessmentScore: asIntOrNull(json['assessment_score']),
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
    'pending' => (
      background: const Color(0xFFFFF4E5),
      text: const Color(0xFFB87700),
    ),
    'under_review' => (
      background: const Color(0xFFE8EEFF),
      text: const Color(0xFF3D6EF5),
    ),
    'interview' => (
      background: const Color(0xFFF3EEFE),
      text: const Color(0xFF7C3AED),
    ),
    'accepted' => (
      background: const Color(0xFFEAFAF1),
      text: const Color(0xFF1A7F4B),
    ),
    'rejected' => (background: const Color(0xFFFFF1F1), text: AppColors.danger),
    _ => (background: const Color(0xFFF1F5F9), text: const Color(0xFF64748B)),
  };
}

/// A schooling, certification or work entry on a candidate's record. The
/// three read the same way — a title, who it was with, and when — so they
/// share one shape rather than three near-identical ones.
class CandidateCredential {
  const CandidateCredential({
    required this.title,
    required this.subtitle,
    this.detail,
  });

  final String title;
  final String subtitle;
  final String? detail;

  factory CandidateCredential.education(Map<String, dynamic> json) {
    final start = json['start_year'];
    final end = json['end_year'];
    final years = [start, end].where((y) => y != null).join(' – ');

    return CandidateCredential(
      title:
          json['degree'] as String? ??
          json['field_of_study'] as String? ??
          'Studied',
      subtitle: json['institution'] as String? ?? '',
      detail: years.isEmpty ? null : years,
    );
  }

  factory CandidateCredential.certification(Map<String, dynamic> json) =>
      CandidateCredential(
        title: json['title'] as String? ?? 'Certification',
        subtitle: json['issuing_organization'] as String? ?? '',
      );

  factory CandidateCredential.experience(Map<String, dynamic> json) =>
      CandidateCredential(
        title: json['position'] as String? ?? 'Role',
        subtitle: json['organization'] as String? ?? '',
        detail: json['description'] as String?,
      );
}

/// One candidate in full — the phone's version of the website's candidate
/// page: the match, what they have and haven't got against the posting, their
/// latest assessment, and their background.
class CandidateDetail {
  const CandidateDetail({
    required this.candidate,
    required this.missingSkills,
    required this.education,
    required this.certifications,
    required this.experiences,
  });

  final Candidate candidate;

  /// Required skills this candidate doesn't list — the other half of the
  /// match, and the reason a company would look past a middling score.
  final List<String> missingSkills;

  final List<CandidateCredential> education;
  final List<CandidateCredential> certifications;
  final List<CandidateCredential> experiences;

  factory CandidateDetail.fromJson(
    Map<String, dynamic> json,
  ) => CandidateDetail(
    candidate: Candidate.fromJson(json),
    missingSkills: (json['missing_skills'] as List? ?? const [])
        .map((e) => e.toString())
        .toList(),
    education: (json['education'] as List? ?? const [])
        .map((e) => CandidateCredential.education(e as Map<String, dynamic>))
        .toList(),
    certifications: (json['certifications'] as List? ?? const [])
        .map(
          (e) => CandidateCredential.certification(e as Map<String, dynamic>),
        )
        .toList(),
    experiences: (json['experiences'] as List? ?? const [])
        .map((e) => CandidateCredential.experience(e as Map<String, dynamic>))
        .toList(),
  );
}
