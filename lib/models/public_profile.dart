/// Read-only profiles reached from search or a review author — the mobile
/// twin of the web's student/company/coordinator profile-viewer pages.
///
/// Deliberately separate from [StudentProfile] in `student_profile.dart`:
/// that model shapes the *owner's own* profile (Api\StudentProfileController,
/// one education entry, editable fields). These shape Api\PublicProfileController's
/// response — a full history of education/certifications/experience for
/// someone else's account, with no edit affordances at all.
library;

class PublicEducationEntry {
  PublicEducationEntry({
    required this.institution,
    required this.degree,
    required this.fieldOfStudy,
    required this.startYear,
    required this.endYear,
  });

  final String? institution;
  final String? degree;
  final String? fieldOfStudy;
  final int? startYear;
  final int? endYear;

  factory PublicEducationEntry.fromJson(Map<String, dynamic> json) {
    return PublicEducationEntry(
      institution: json['institution'] as String?,
      degree: json['degree'] as String?,
      fieldOfStudy: json['field_of_study'] as String?,
      startYear: (json['start_year'] as num?)?.toInt(),
      endYear: (json['end_year'] as num?)?.toInt(),
    );
  }
}

class PublicCertificationEntry {
  PublicCertificationEntry({
    required this.title,
    required this.issuingOrganization,
    required this.issueDate,
    required this.credentialUrl,
  });

  final String? title;
  final String? issuingOrganization;
  final String? issueDate;
  final String? credentialUrl;

  factory PublicCertificationEntry.fromJson(Map<String, dynamic> json) {
    return PublicCertificationEntry(
      title: json['title'] as String?,
      issuingOrganization: json['issuing_organization'] as String?,
      issueDate: json['issue_date'] as String?,
      credentialUrl: json['credential_url'] as String?,
    );
  }
}

class PublicExperienceEntry {
  PublicExperienceEntry({
    required this.position,
    required this.organization,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.description,
  });

  final String? position;
  final String? organization;
  final String? type;
  final String? startDate;
  final String? endDate;
  final String? description;

  factory PublicExperienceEntry.fromJson(Map<String, dynamic> json) {
    return PublicExperienceEntry(
      position: json['position'] as String?,
      organization: json['organization'] as String?,
      type: json['type'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      description: json['description'] as String?,
    );
  }
}

/// Either a real profile, or a signal that the id resolved to the viewer's
/// own account — the app should show the editable profile screen instead.
class StudentPublicProfile {
  StudentPublicProfile({
    required this.isSelf,
    this.name,
    this.avatarUrl,
    this.coverUrl,
    this.course,
    this.yearLevel,
    this.campus,
    this.address,
    this.skills = const [],
    this.isOnOjt = false,
    this.placementCompany,
    this.education = const [],
    this.certifications = const [],
    this.experiences = const [],
  });

  final bool isSelf;
  final String? name;
  final String? avatarUrl;
  final String? coverUrl;
  final String? course;
  final int? yearLevel;
  final String? campus;
  final String? address;
  final List<String> skills;
  final bool isOnOjt;
  final String? placementCompany;
  final List<PublicEducationEntry> education;
  final List<PublicCertificationEntry> certifications;
  final List<PublicExperienceEntry> experiences;

  factory StudentPublicProfile.fromJson(Map<String, dynamic> json) {
    if (json['is_self'] == true) {
      return StudentPublicProfile(isSelf: true);
    }

    return StudentPublicProfile(
      isSelf: false,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      course: json['course'] as String?,
      yearLevel: (json['year_level'] as num?)?.toInt(),
      campus: json['campus'] as String?,
      address: json['address'] as String?,
      skills: (json['skills'] as List? ?? []).map((e) => e.toString()).toList(),
      isOnOjt: json['is_on_ojt'] as bool? ?? false,
      placementCompany: json['placement_company'] as String?,
      education: (json['education'] as List? ?? [])
          .map((e) => PublicEducationEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      certifications: (json['certifications'] as List? ?? [])
          .map((e) => PublicCertificationEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      experiences: (json['experiences'] as List? ?? [])
          .map((e) => PublicExperienceEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OpenInternshipSummary {
  OpenInternshipSummary({
    required this.id,
    required this.title,
    required this.location,
    required this.slotsAvailable,
    required this.skills,
  });

  final int id;
  final String title;
  final String? location;
  final int slotsAvailable;
  final List<String> skills;

  factory OpenInternshipSummary.fromJson(Map<String, dynamic> json) {
    return OpenInternshipSummary(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      location: json['location'] as String?,
      slotsAvailable: (json['slots_available'] as num?)?.toInt() ?? 0,
      skills: (json['skills'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class CompanyPublicProfile {
  CompanyPublicProfile({
    required this.id,
    required this.name,
    this.industry,
    this.description,
    this.logoUrl,
    this.coverUrl,
    this.city,
    this.province,
    this.website,
    this.address,
    this.contactEmail,
    this.contactNumber,
    this.isVerified = false,
    this.internshipCount = 0,
    this.openInternships = const [],
  });

  final int id;
  final String name;
  final String? industry;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String? city;
  final String? province;
  final String? website;
  final String? address;
  final String? contactEmail;
  final String? contactNumber;
  final bool isVerified;
  final int internshipCount;
  final List<OpenInternshipSummary> openInternships;

  factory CompanyPublicProfile.fromJson(Map<String, dynamic> json) {
    return CompanyPublicProfile(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Company',
      industry: json['industry'] as String?,
      description: json['description'] as String?,
      logoUrl: json['logo_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      website: json['website'] as String?,
      address: json['address'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactNumber: json['contact_number'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      internshipCount: (json['internship_count'] as num?)?.toInt() ?? 0,
      openInternships: (json['open_internships'] as List? ?? [])
          .map((e) => OpenInternshipSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CoordinatorPublicProfile {
  CoordinatorPublicProfile({
    required this.isSelf,
    this.name,
    this.avatarUrl,
    this.coverUrl,
    this.department,
    this.campus,
    this.email,
    this.contactNumber,
  });

  final bool isSelf;
  final String? name;
  final String? avatarUrl;
  final String? coverUrl;
  final String? department;
  final String? campus;
  final String? email;
  final String? contactNumber;

  factory CoordinatorPublicProfile.fromJson(Map<String, dynamic> json) {
    if (json['is_self'] == true) {
      return CoordinatorPublicProfile(isSelf: true);
    }

    return CoordinatorPublicProfile(
      isSelf: false,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      department: json['department'] as String?,
      campus: json['campus'] as String?,
      email: json['email'] as String?,
      contactNumber: json['contact_number'] as String?,
    );
  }
}
