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
    this.remarks,
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
  final String? remarks;

  /// The web only shows the Log Hours form while the placement is ongoing.
  bool get canLogHours => status == 'ongoing';

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
      coordinatorName: json['coordinator_name'] as String? ?? 'Assigned Coordinator',
      coordinatorEmail: json['coordinator_email'] as String?,
      coordinatorDept: json['coordinator_dept'] as String?,
      remarks: json['remarks'] as String?,
    );
  }
}

/// The full My Placement payload: the placement itself (null when the
/// student hasn't been placed yet) plus the OJT hours tracker numbers.
class PlacementSummary {
  PlacementSummary({
    this.placement,
    required this.requiredHours,
    required this.hoursRendered,
    required this.progressPercent,
    required this.hoursRemaining,
  });

  final Placement? placement;
  final int requiredHours;
  final int hoursRendered;
  final int progressPercent;
  final int hoursRemaining;

  factory PlacementSummary.fromJson(Map<String, dynamic> json) {
    return PlacementSummary(
      placement: json['placement'] != null ? Placement.fromJson(json['placement'] as Map<String, dynamic>) : null,
      requiredHours: (json['required_hours'] as num?)?.toInt() ?? 0,
      hoursRendered: (json['hours_rendered'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      hoursRemaining: (json['hours_remaining'] as num?)?.toInt() ?? 0,
    );
  }
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
