import 'package:flutter/material.dart';

/// One row of the student's applications list — the same `applications`
/// record the web page renders, including its resolved status label and
/// colours so both platforms stay in step.
class ApplicationSummary {
  ApplicationSummary({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.statusBackground,
    required this.statusTextColor,
    required this.internshipTitle,
    required this.companyName,
    this.companyLogoUrl,
    required this.companyInitial,
    this.appliedAt,
    required this.hasPendingAssessment,
    required this.isReassignment,
    this.assessmentId,
  });

  final int id;
  final String status;
  final String statusLabel;
  final Color statusBackground;
  final Color statusTextColor;
  final String internshipTitle;
  final String companyName;
  final String? companyLogoUrl;
  final String companyInitial;
  final String? appliedAt;

  /// True when a published competency test is waiting on this application —
  /// the card shows "Take assessment" instead of a status strip.
  final bool hasPendingAssessment;

  /// True when the student already answered this assessment and the company
  /// reassigned it — the card then shows the green "Retake Assessment" button
  /// instead of the blue "Take Assessment" one, matching the web.
  final bool isReassignment;
  final int? assessmentId;

  factory ApplicationSummary.fromJson(Map<String, dynamic> json) {
    return ApplicationSummary(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['status_label'] as String? ?? 'Pending',
      statusBackground: _parseHexColor(
        json['status_bg_color'] as String?,
        const Color(0xFFF1F5F9),
      ),
      statusTextColor: _parseHexColor(
        json['status_text_color'] as String?,
        const Color(0xFF64748B),
      ),
      internshipTitle: json['internship_title'] as String? ?? 'Internship',
      companyName: json['company_name'] as String? ?? 'Company',
      companyLogoUrl: json['company_logo_url'] as String?,
      companyInitial: json['company_initial'] as String? ?? 'C',
      appliedAt: json['applied_at'] as String?,
      hasPendingAssessment: json['has_pending_assessment'] as bool? ?? false,
      isReassignment: json['is_reassignment'] as bool? ?? false,
      assessmentId: (json['assessment_id'] as num?)?.toInt(),
    );
  }
}

/// The list plus the flags driving the notification banner. The web shows one
/// banner at a time and lets the green "reassigned" one win, so the API sends
/// these already resolved.
class ApplicationsResult {
  ApplicationsResult({
    required this.applications,
    required this.hasNewAssessment,
    required this.hasReassignment,
  });

  final List<ApplicationSummary> applications;
  final bool hasNewAssessment;
  final bool hasReassignment;

  factory ApplicationsResult.fromJson(Map<String, dynamic> json) {
    return ApplicationsResult(
      applications: (json['applications'] as List? ?? [])
          .map((e) => ApplicationSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasNewAssessment: json['has_new_assessment'] as bool? ?? false,
      hasReassignment: json['has_reassignment'] as bool? ?? false,
    );
  }
}

/// The lightweight snapshot polled every 15 seconds — enough to notice a
/// status change or a newly (re)assigned test without refetching everything.
class ApplicationsStatusSnapshot {
  ApplicationsStatusSnapshot({
    required this.statuses,
    required this.pendingAssessments,
    required this.reassignedAssessments,
  });

  /// Application id -> its current state, compared tick to tick to spot changes.
  final Map<int, ApplicationStatusEntry> statuses;
  final int pendingAssessments;
  final int reassignedAssessments;

  factory ApplicationsStatusSnapshot.fromJson(Map<String, dynamic> json) {
    final entries = <int, ApplicationStatusEntry>{};
    for (final raw in (json['applications'] as List? ?? const [])) {
      final entry = ApplicationStatusEntry.fromJson(
        raw as Map<String, dynamic>,
      );
      entries[entry.id] = entry;
    }

    return ApplicationsStatusSnapshot(
      statuses: entries,
      pendingAssessments: (json['pending_assessments'] as num?)?.toInt() ?? 0,
      reassignedAssessments:
          (json['reassigned_assessments'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApplicationStatusEntry {
  ApplicationStatusEntry({
    required this.id,
    required this.internshipTitle,
    required this.status,
    required this.hasPendingAssessment,
    required this.isReassignment,
  });

  final int id;
  final String internshipTitle;
  final String status;
  final bool hasPendingAssessment;
  final bool isReassignment;

  factory ApplicationStatusEntry.fromJson(Map<String, dynamic> json) =>
      ApplicationStatusEntry(
        id: (json['id'] as num).toInt(),
        internshipTitle:
            json['internship_title'] as String? ?? 'your application',
        status: json['status'] as String? ?? 'pending',
        hasPendingAssessment: json['has_pending_assessment'] as bool? ?? false,
        isReassignment: json['is_reassignment'] as bool? ?? false,
      );
}

/// The API sends the web's CSS colours as `#RRGGBB`.
Color _parseHexColor(String? hex, Color fallback) {
  if (hex == null) return fallback;
  final cleaned = hex.replaceFirst('#', '').trim();
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  return value == null ? fallback : Color(0xFF000000 | value);
}
