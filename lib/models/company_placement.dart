import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// One placement record — a student who is (or was) doing their OJT with this
/// company. The same `placements` row the website's company placements page
/// lists; the app only reads it, because placements are created and updated
/// by coordinators on the web.
class CompanyPlacement {
  const CompanyPlacement({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentAvatarUrl,
    required this.studentNumber,
    required this.internshipTitle,
    required this.startDate,
    required this.endDate,
    required this.createdAtHuman,
    required this.updatedAtHuman,
  });

  final int id;
  final String status;
  final String statusLabel;
  final int? studentId;
  final String studentName;
  final String? studentEmail;
  final String? studentAvatarUrl;
  final String? studentNumber;
  final String? internshipTitle;
  final String? startDate;
  final String? endDate;
  final String createdAtHuman;
  final String updatedAtHuman;

  String get initials {
    final parts = studentName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory CompanyPlacement.fromJson(Map<String, dynamic> json) => CompanyPlacement(
        id: (json['id'] as num).toInt(),
        status: json['status'] as String? ?? 'ongoing',
        statusLabel: json['status_label'] as String? ?? 'Ongoing',
        studentId: (json['student_id'] as num?)?.toInt(),
        studentName: json['student_name'] as String? ?? 'Unknown',
        studentEmail: json['student_email'] as String?,
        studentAvatarUrl: json['student_avatar_url'] as String?,
        studentNumber: json['student_number'] as String?,
        internshipTitle: json['internship_title'] as String?,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        createdAtHuman: json['created_at_human'] as String? ?? '',
        updatedAtHuman: json['updated_at_human'] as String? ?? '',
      );
}

/// The posting a placement is against, as the detail screen shows it.
class PlacementInternship {
  const PlacementInternship({
    required this.title,
    required this.location,
    required this.skills,
    required this.responsibilities,
  });

  final String title;
  final String? location;
  final List<String> skills;
  final List<String> responsibilities;

  factory PlacementInternship.fromJson(Map<String, dynamic> json) => PlacementInternship(
        title: json['title'] as String? ?? 'Untitled posting',
        location: json['location'] as String?,
        skills: (json['skills'] as List? ?? const []).map((e) => '$e').toList(),
        responsibilities:
            (json['responsibilities'] as List? ?? const []).map((e) => '$e').toList(),
      );
}

/// Everything the placement detail screen shows: the list fields plus the
/// student's particulars, the posting, the hours, and the coordinator.
class CompanyPlacementDetail {
  const CompanyPlacementDetail({
    required this.placement,
    required this.course,
    required this.yearLevel,
    required this.campus,
    required this.contactNumber,
    required this.address,
    required this.studentSkills,
    required this.internship,
    required this.coordinatorName,
    required this.coordinatorEmail,
    required this.hoursRendered,
    required this.requiredHours,
    required this.evaluationScore,
    required this.remarks,
  });

  final CompanyPlacement placement;
  final String? course;
  final int? yearLevel;
  final String? campus;
  final String? contactNumber;
  final String? address;
  final List<String> studentSkills;
  final PlacementInternship? internship;
  final String? coordinatorName;
  final String? coordinatorEmail;
  final int hoursRendered;
  final int requiredHours;
  final double? evaluationScore;
  final String? remarks;

  /// Fraction of the required hours logged so far, clamped to 0–1 so an
  /// over-run doesn't overflow the progress bar.
  double get hoursProgress {
    if (requiredHours <= 0) return 0;
    return (hoursRendered / requiredHours).clamp(0.0, 1.0);
  }

  factory CompanyPlacementDetail.fromJson(Map<String, dynamic> json) =>
      CompanyPlacementDetail(
        placement: CompanyPlacement.fromJson(json),
        course: json['course'] as String?,
        yearLevel: (json['year_level'] as num?)?.toInt(),
        campus: json['campus'] as String?,
        contactNumber: json['contact_number'] as String?,
        address: json['address'] as String?,
        studentSkills: (json['student_skills'] as List? ?? const []).map((e) => '$e').toList(),
        internship: json['internship'] == null
            ? null
            : PlacementInternship.fromJson(json['internship'] as Map<String, dynamic>),
        coordinatorName: json['coordinator_name'] as String?,
        coordinatorEmail: json['coordinator_email'] as String?,
        hoursRendered: (json['hours_rendered'] as num?)?.toInt() ?? 0,
        requiredHours: (json['required_hours'] as num?)?.toInt() ?? 0,
        evaluationScore: (json['evaluation_score'] as num?)?.toDouble(),
        remarks: json['remarks'] as String?,
      );
}

/// How many placements sit in each status — the summary cards.
class PlacementCounts {
  const PlacementCounts({
    required this.total,
    required this.ongoing,
    required this.completed,
    required this.terminated,
  });

  final int total;
  final int ongoing;
  final int completed;
  final int terminated;

  static const empty =
      PlacementCounts(total: 0, ongoing: 0, completed: 0, terminated: 0);

  factory PlacementCounts.fromJson(Map<String, dynamic> json) {
    int at(String key) => (json[key] as num?)?.toInt() ?? 0;
    return PlacementCounts(
      total: at('total'),
      ongoing: at('ongoing'),
      completed: at('completed'),
      terminated: at('terminated'),
    );
  }
}

/// Foreground/background pair for a placement status pill, matching the
/// colours the web's status badge uses for the same three values.
({Color background, Color text}) placementStatusColors(String status) {
  switch (status) {
    case 'completed':
      return (background: const Color(0xFFEAFAF1), text: const Color(0xFF1A7F4B));
    case 'terminated':
      return (background: const Color(0xFFFFF1F1), text: AppColors.danger);
    default:
      return (background: AppColors.chipBackground, text: AppColors.primary);
  }
}
