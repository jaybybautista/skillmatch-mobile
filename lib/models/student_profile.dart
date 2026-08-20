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
  CertificationInfo({this.title, this.issuingOrganization, this.issueDate});

  final String? title;
  final String? issuingOrganization;
  final String? issueDate;

  factory CertificationInfo.fromJson(Map<String, dynamic> json) {
    return CertificationInfo(
      title: json['title'] as String?,
      issuingOrganization: json['issuing_organization'] as String?,
      issueDate: json['issue_date'] as String?,
    );
  }
}

class ExperienceInfo {
  ExperienceInfo({
    this.position,
    this.organization,
    this.startDate,
    this.endDate,
  });

  final String? position;
  final String? organization;
  final String? startDate;
  final String? endDate;

  factory ExperienceInfo.fromJson(Map<String, dynamic> json) {
    return ExperienceInfo(
      position: json['position'] as String?,
      organization: json['organization'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
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
    );
  }
}
