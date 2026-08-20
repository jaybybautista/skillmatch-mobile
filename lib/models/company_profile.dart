import '../core/json_parse.dart';

/// The four figures the company profile headlines, mirroring the same counts
/// the web profile page shows.
class CompanyStats {
  const CompanyStats({
    required this.internshipCount,
    required this.openSlots,
    required this.applicantCount,
    required this.placementCount,
  });

  final int internshipCount;
  final int openSlots;
  final int applicantCount;
  final int placementCount;

  factory CompanyStats.fromJson(Map<String, dynamic> json) {
    return CompanyStats(
      internshipCount: asInt(json['internship_count']),
      openSlots: asInt(json['open_slots']),
      applicantCount: asInt(json['applicant_count']),
      placementCount: asInt(json['placement_count']),
    );
  }
}

/// The signed-in company's own profile — the same `companies` row the
/// website's company profile page reads and writes.
class CompanyProfile {
  const CompanyProfile({
    required this.id,
    required this.companyName,
    this.industry,
    this.description,
    this.address,
    this.region,
    this.province,
    this.city,
    this.barangay,
    this.website,
    this.contactEmail,
    this.contactNumber,
    this.logoUrl,
    this.coverUrl,
    required this.verificationStatus,
    required this.isVerified,
    this.rejectionReason,
    required this.stats,
  });

  final int id;
  final String companyName;
  final String? industry;
  final String? description;
  final String? address;
  final String? region;
  final String? province;
  final String? city;
  final String? barangay;
  final String? website;
  final String? contactEmail;
  final String? contactNumber;
  final String? logoUrl;

  /// The banner behind the header. Stored on the user account rather than the
  /// company row, which is where the website keeps it too.
  final String? coverUrl;

  /// pending | approved | rejected
  final String verificationStatus;
  final bool isVerified;
  final String? rejectionReason;
  final CompanyStats stats;

  bool get isPending => verificationStatus == 'pending';
  bool get isRejected => verificationStatus == 'rejected';

  /// Whether the company has filled in enough to stop being nudged through
  /// the setup wizard — the same three fields the wizard asks for.
  bool get isSetupComplete =>
      (description ?? '').trim().isNotEmpty &&
      (address ?? '').trim().isNotEmpty &&
      (contactNumber ?? '').trim().isNotEmpty;

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    return CompanyProfile(
      id: asInt(json['id']),
      companyName: json['company_name'] as String? ?? 'Company',
      industry: json['industry'] as String?,
      description: json['description'] as String?,
      address: json['address'] as String?,
      region: json['region'] as String?,
      province: json['province'] as String?,
      city: json['city'] as String?,
      barangay: json['barangay'] as String?,
      website: json['website'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactNumber: json['contact_number'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      verificationStatus: json['verification_status'] as String? ?? 'pending',
      isVerified: json['is_verified'] as bool? ?? false,
      rejectionReason: json['rejection_reason'] as String?,
      stats: CompanyStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
