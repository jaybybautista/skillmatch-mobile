import 'placement.dart';

/// Re-exported so screens importing student_profile.dart also get the
/// current-OJT indicator type without needing a second import.
export 'placement.dart' show PlacementIndicator;

class EducationInfo {
  EducationInfo({this.school, this.schoolAddress, this.program, this.major});

  final String? school;
  final String? schoolAddress;
  final String? program;
  final String? major;

  factory EducationInfo.fromJson(Map<String, dynamic> json) {
    return EducationInfo(
      school: json['school'] as String?,
      schoolAddress: json['school_address'] as String?,
      program: json['program'] as String?,
      major: json['major'] as String?,
    );
  }
}

class CertificationInfo {
  CertificationInfo({
    this.id,
    this.title,
    this.issuingOrganization,
    this.issueDate,
    this.issueDateRaw,
    this.expiryDateRaw,
    this.credentialUrl,
  });

  /// Needed to edit or remove this row. Null only on rows built by tests.
  final int? id;

  final String? title;
  final String? issuingOrganization;

  /// Already formatted for reading, e.g. "Mar 2026". The raw fields carry the
  /// ISO date the edit form needs.
  final String? issueDate;
  final String? issueDateRaw;
  final String? expiryDateRaw;
  final String? credentialUrl;

  factory CertificationInfo.fromJson(Map<String, dynamic> json) {
    return CertificationInfo(
      id: (json['id'] as num?)?.toInt(),
      title: json['title'] as String?,
      issuingOrganization: json['issuing_organization'] as String?,
      issueDate: json['issue_date'] as String?,
      issueDateRaw: json['issue_date_raw'] as String?,
      expiryDateRaw: json['expiry_date_raw'] as String?,
      credentialUrl: json['credential_url'] as String?,
    );
  }
}

class ExperienceInfo {
  ExperienceInfo({
    this.id,
    this.position,
    this.organization,
    this.type,
    this.description,
    this.startDate,
    this.endDate,
    this.startDateRaw,
    this.endDateRaw,
  });

  final int? id;
  final String? position;
  final String? organization;

  /// Either work or extracurricular, matching the choice the web offers.
  final String? type;
  final String? description;

  final String? startDate;
  final String? endDate;
  final String? startDateRaw;
  final String? endDateRaw;

  factory ExperienceInfo.fromJson(Map<String, dynamic> json) {
    return ExperienceInfo(
      id: (json['id'] as num?)?.toInt(),
      position: json['position'] as String?,
      organization: json['organization'] as String?,
      type: json['type'] as String?,
      description: json['description'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      startDateRaw: json['start_date_raw'] as String?,
      endDateRaw: json['end_date_raw'] as String?,
    );
  }
}

/// One school the student attended. Separate from [EducationInfo], which is
/// the campus and course on their own student record.
class EducationEntry {
  EducationEntry({
    this.id,
    this.institution,
    this.degree,
    this.fieldOfStudy,
    this.startYear,
    this.endYear,
  });

  final int? id;
  final String? institution;
  final String? degree;
  final String? fieldOfStudy;
  final int? startYear;
  final int? endYear;

  String get period {
    final start = startYear?.toString() ?? '';
    final end = endYear?.toString() ?? 'Present';
    return start.isEmpty ? end : '$start to $end';
  }

  factory EducationEntry.fromJson(Map<String, dynamic> json) {
    return EducationEntry(
      id: (json['id'] as num?)?.toInt(),
      institution: json['institution'] as String?,
      degree: json['degree'] as String?,
      fieldOfStudy: json['field_of_study'] as String?,
      startYear: (json['start_year'] as num?)?.toInt(),
      endYear: (json['end_year'] as num?)?.toInt(),
    );
  }
}

/// One project on the student's profile. Typed in on the profile page, or
/// lifted out of an uploaded resume by the OCR import; either way the student
/// can edit it afterwards.
class ProjectInfo {
  ProjectInfo({
    this.id,
    this.startDateRaw,
    this.endDateRaw,
    this.title,
    this.role,
    this.description,
    this.link,
    this.startDate,
    this.endDate,
  });

  final int? id;
  final String? startDateRaw;
  final String? endDateRaw;
  final String? title;
  final String? role;
  final String? description;
  final String? link;
  final String? startDate;
  final String? endDate;

  factory ProjectInfo.fromJson(Map<String, dynamic> json) {
    return ProjectInfo(
      id: (json['id'] as num?)?.toInt(),
      startDateRaw: json['start_date_raw'] as String?,
      endDateRaw: json['end_date_raw'] as String?,
      title: json['title'] as String?,
      role: json['role'] as String?,
      description: json['description'] as String?,
      link: json['link'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
    );
  }
}

/// A recognition or award. Same two sources as [ProjectInfo].
class AchievementInfo {
  AchievementInfo({
    this.id,
    this.title,
    this.issuer,
    this.dateAwarded,
    this.dateAwardedRaw,
    this.description,
  });

  final int? id;
  final String? title;
  final String? issuer;
  final String? dateAwarded;
  final String? dateAwardedRaw;
  final String? description;

  factory AchievementInfo.fromJson(Map<String, dynamic> json) {
    return AchievementInfo(
      id: (json['id'] as num?)?.toInt(),
      title: json['title'] as String?,
      issuer: json['issuer'] as String?,
      dateAwarded: json['date_awarded'] as String?,
      dateAwardedRaw: json['date_awarded_raw'] as String?,
      description: json['description'] as String?,
    );
  }
}

class ResumeInfo {
  ResumeInfo({required this.filename, required this.url});

  final String filename;
  final String url;

  factory ResumeInfo.fromJson(Map<String, dynamic> json) {
    return ResumeInfo(
      filename: json['filename'] as String,
      url: json['url'] as String,
    );
  }
}

class StudentProfile {
  StudentProfile({
    required this.name,
    required this.email,
    this.profilePictureUrl,
    this.course,
    this.campus,
    this.contactNumber,
    this.location,
    this.professionalSummary,
    required this.skills,
    this.resume,
    this.placement,
    this.education,
    required this.certifications,
    required this.experiences,
    this.projects = const [],
    this.achievements = const [],
    this.educationHistory = const [],
  });

  final String name;
  final String email;
  final String? profilePictureUrl;
  final String? course;
  final String? campus;
  final String? contactNumber;
  final String? location;
  final String? professionalSummary;
  final List<String> skills;
  final ResumeInfo? resume;

  /// Where the student is currently doing their OJT, when they've been
  /// placed — null otherwise.
  final PlacementIndicator? placement;
  final EducationInfo? education;
  final List<CertificationInfo> certifications;
  final List<ExperienceInfo> experiences;

  /// The student decides the order of these two, so they arrive already
  /// sorted and are rendered in the order given rather than by date.
  final List<ProjectInfo> projects;
  final List<AchievementInfo> achievements;

  /// The schools the student attended. [education] above is the campus and
  /// course on their student record, which is a different thing.
  final List<EducationEntry> educationHistory;

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      name: json['name'] as String,
      email: json['email'] as String,
      profilePictureUrl: json['profile_picture_url'] as String?,
      course: json['course'] as String?,
      campus: json['campus'] as String?,
      contactNumber: json['contact_number'] as String?,
      location: json['location'] as String?,
      professionalSummary: json['professional_summary'] as String?,
      skills: (json['skills'] as List? ?? []).map((e) => e.toString()).toList(),
      resume: json['resume'] != null
          ? ResumeInfo.fromJson(json['resume'] as Map<String, dynamic>)
          : null,
      placement: json['placement'] != null
          ? PlacementIndicator.fromJson(
              json['placement'] as Map<String, dynamic>,
            )
          : null,
      education: json['education'] != null
          ? EducationInfo.fromJson(json['education'] as Map<String, dynamic>)
          : null,
      certifications: (json['certifications'] as List? ?? [])
          .map((e) => CertificationInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      experiences: (json['experiences'] as List? ?? [])
          .map((e) => ExperienceInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      projects: (json['projects'] as List? ?? [])
          .map((e) => ProjectInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      achievements: (json['achievements'] as List? ?? [])
          .map((e) => AchievementInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      educationHistory: (json['education_history'] as List? ?? [])
          .map((e) => EducationEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
