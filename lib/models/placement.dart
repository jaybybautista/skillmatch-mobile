/// A student's official OJT placement — the same `placements` row the web
/// app's My Placement page reads.
class Placement {
  Placement({
    required this.id,
    required this.status,
    required this.roleTitle,
    required this.companyName,
    this.companyLogoUrl,
    required this.companyInitial,
    this.startDate,
    this.endDate,
    this.location,
    required this.coordinatorName,
    this.coordinatorEmail,
    this.coordinatorDept,
    this.coordinatorCampus,
    this.evaluationScore,
    this.recordedAt,
    this.internshipId,
  });

  final int id;
  final String status;
  final String roleTitle;
  final String companyName;
  final String? companyLogoUrl;
  final String companyInitial;
  final String? startDate;
  final String? endDate;
  final String? location;
  final String coordinatorName;
  final String? coordinatorEmail;
  final String? coordinatorDept;
  final String? coordinatorCampus;

  /// The coordinator's mark out of 100, once they have given one.
  final int? evaluationScore;

  /// When the coordinator created this record.
  final String? recordedAt;

  /// The posting behind the placement, for "View the original posting".
  /// Null when the record was made without one.
  final int? internshipId;

  /// Still running, as opposed to completed or terminated.
  bool get isOngoing => status == 'ongoing';

  factory Placement.fromJson(Map<String, dynamic> json) {
    return Placement(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'ongoing',
      roleTitle: json['role_title'] as String? ?? 'Intern Placement',
      companyName: json['company_name'] as String? ?? 'Company',
      companyLogoUrl: json['company_logo_url'] as String?,
      companyInitial: json['company_initial'] as String? ?? 'C',
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      location: json['location'] as String?,
      coordinatorName:
          json['coordinator_name'] as String? ?? 'Assigned Coordinator',
      coordinatorEmail: json['coordinator_email'] as String?,
      coordinatorDept: json['coordinator_dept'] as String?,
      coordinatorCampus: json['coordinator_campus'] as String?,
      evaluationScore: (json['evaluation_score'] as num?)?.toInt(),
      recordedAt: json['recorded_at'] as String?,
      internshipId: (json['internship_id'] as num?)?.toInt(),
    );
  }
}

/// The full My Placement payload: the placement itself (null when the
/// student hasn't been placed yet), how far through the period it is, and
/// the placements that came before it.
class PlacementSummary {
  PlacementSummary({
    this.placement,
    this.progressPercent,
    this.studentCampus,
    this.history = const [],
  });

  final Placement? placement;

  /// How much of the placement *period* has passed, counted in days between
  /// the start and end dates — not hours worked. Null when either date is
  /// missing, in which case there is nothing to show, which is exactly what
  /// the web does.
  final int? progressPercent;

  /// Falls back for the coordinator card when the coordinator has no campus
  /// of their own recorded.
  final String? studentCampus;

  /// Placements that came before this one. The web page lists them under the
  /// current record so a student who has finished one OJT and started
  /// another can still see the first.
  final List<PlacementHistoryEntry> history;

  factory PlacementSummary.fromJson(Map<String, dynamic> json) {
    return PlacementSummary(
      placement: json['placement'] != null
          ? Placement.fromJson(json['placement'] as Map<String, dynamic>)
          : null,
      progressPercent: (json['progress_percent'] as num?)?.toInt(),
      studentCampus: json['student_campus'] as String?,
      history: (json['history'] as List? ?? const [])
          .map((e) =>
              PlacementHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One earlier placement, as the history list shows it.
class PlacementHistoryEntry {
  const PlacementHistoryEntry({
    required this.id,
    required this.status,
    required this.roleTitle,
    required this.companyName,
    this.startDate,
    this.endDate,
  });

  final int id;
  final String status;
  final String roleTitle;
  final String companyName;
  final String? startDate;
  final String? endDate;

  String get period {
    if (startDate == null && endDate == null) return 'Dates not set';
    return '${startDate ?? 'Not set'} - ${endDate ?? 'Not set'}';
  }

  factory PlacementHistoryEntry.fromJson(Map<String, dynamic> json) =>
      PlacementHistoryEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'completed',
        roleTitle: json['role_title'] as String? ?? 'Intern Placement',
        companyName: json['company_name'] as String? ?? 'Company',
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
      );
}

/// Compact "currently doing OJT at ..." summary shown on the Profile screen.
class PlacementIndicator {
  PlacementIndicator({
    required this.status,
    required this.roleTitle,
    required this.companyName,
    this.companyLogoUrl,
  });

  final String status;
  final String roleTitle;
  final String companyName;
  final String? companyLogoUrl;

  factory PlacementIndicator.fromJson(Map<String, dynamic> json) {
    return PlacementIndicator(
      status: json['status'] as String? ?? 'ongoing',
      roleTitle: json['role_title'] as String? ?? 'Intern Placement',
      companyName: json['company_name'] as String? ?? 'Company',
      companyLogoUrl: json['company_logo_url'] as String?,
    );
  }
}
