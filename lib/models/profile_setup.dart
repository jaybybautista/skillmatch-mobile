/// Models for the first-run profile wizard, mirroring the payloads
/// Api\ProfileSetupController exchanges with the app.
library;

/// Whether the wizard should run, plus what to prefill step 1 with.
class SetupState {
  SetupState({
    required this.needsSetup,
    required this.setupComplete,
    required this.setupSkipped,
    required this.prefill,
  });

  final bool needsSetup;
  final bool setupComplete;
  final bool setupSkipped;
  final PersonalDetails prefill;

  factory SetupState.fromJson(Map<String, dynamic> json) => SetupState(
        needsSetup: json['needs_setup'] as bool? ?? false,
        setupComplete: json['setup_complete'] as bool? ?? false,
        setupSkipped: json['setup_skipped'] as bool? ?? false,
        prefill: PersonalDetails.fromJson(json['prefill'] as Map<String, dynamic>? ?? const {}),
      );
}

class PersonalDetails {
  PersonalDetails({this.name, this.email, this.phoneNumber, this.address, this.zipCode});

  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String? zipCode;

  factory PersonalDetails.fromJson(Map<String, dynamic> json) => PersonalDetails(
        // The API's prefill uses `name`; the AI's resume parse uses `full_name`.
        name: (json['name'] ?? json['full_name']) as String?,
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String?,
        address: json['address'] as String?,
        zipCode: json['zip_code'] as String?,
      );
}

/// What the AI made of an uploaded resume.
///
/// Shape matches GeminiAiService::parseResumeText, which the web wizard and the
/// resume importer both use — so the same file yields the same fields here.
class ParsedResume {
  ParsedResume({
    required this.basicInfo,
    required this.education,
    required this.experience,
    required this.technicalSkills,
    required this.softSkills,
    required this.certifications,
    this.resumeName,
  });

  final PersonalDetails basicInfo;
  final List<ParsedEducation> education;
  final List<ParsedExperience> experience;
  final List<String> technicalSkills;
  final List<String> softSkills;

  /// The AI returns these under `achievements`; the wizard treats them as
  /// certifications, which is what its step 4 collects.
  final List<ParsedCertification> certifications;
  final String? resumeName;

  factory ParsedResume.fromJson(Map<String, dynamic> json) {
    final parsed = json['parsed'] as Map<String, dynamic>? ?? json;
    final skills = parsed['skills'] as Map<String, dynamic>? ?? const {};

    List<String> stringList(Object? raw) =>
        (raw as List? ?? const []).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();

    return ParsedResume(
      basicInfo: PersonalDetails.fromJson(parsed['basic_info'] as Map<String, dynamic>? ?? const {}),
      education: (parsed['education'] as List? ?? const [])
          .map((e) => ParsedEducation.fromJson(e as Map<String, dynamic>))
          .toList(),
      experience: (parsed['experience'] as List? ?? const [])
          .map((e) => ParsedExperience.fromJson(e as Map<String, dynamic>))
          .toList(),
      technicalSkills: stringList(skills['technical']),
      softSkills: stringList(skills['soft']),
      certifications: (parsed['achievements'] as List? ?? const [])
          .map((e) => ParsedCertification.fromJson(e as Map<String, dynamic>))
          .where((c) => c.title.isNotEmpty)
          .toList(),
      resumeName: json['resume_name'] as String?,
    );
  }

  static ParsedResume empty() => ParsedResume(
        basicInfo: PersonalDetails(),
        education: const [],
        experience: const [],
        technicalSkills: const [],
        softSkills: const [],
        certifications: const [],
      );
}

class ParsedEducation {
  ParsedEducation({this.degree, this.schoolName, this.startDate, this.endDate});

  final String? degree;
  final String? schoolName;
  final String? startDate;
  final String? endDate;

  factory ParsedEducation.fromJson(Map<String, dynamic> json) => ParsedEducation(
        degree: json['degree'] as String?,
        schoolName: json['school_name'] as String?,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
      );
}

class ParsedExperience {
  ParsedExperience({
    required this.jobTitle,
    required this.company,
    this.responsibilities,
    this.periodStart,
    this.periodEnd,
  });

  final String jobTitle;
  final String company;
  final String? responsibilities;
  final String? periodStart;
  final String? periodEnd;

  factory ParsedExperience.fromJson(Map<String, dynamic> json) => ParsedExperience(
        jobTitle: json['job_title'] as String? ?? '',
        company: json['company'] as String? ?? '',
        responsibilities: json['responsibilities'] as String?,
        periodStart: json['period_start'] as String?,
        periodEnd: json['period_end'] as String?,
      );
}

class ParsedCertification {
  ParsedCertification({required this.title, this.category, this.dateText});

  final String title;
  final String? category;
  final String? dateText;

  factory ParsedCertification.fromJson(Map<String, dynamic> json) => ParsedCertification(
        title: (json['title'] as String? ?? '').trim(),
        category: json['category'] as String?,
        dateText: json['date_text'] as String?,
      );
}

/// A saved certification row (`student_certifications`).
class Certification {
  Certification({required this.id, required this.title, this.issuingOrganization, this.issueDate});

  final int id;
  final String title;
  final String? issuingOrganization;
  final String? issueDate;

  String get subtitle => [
        if (issuingOrganization != null && issuingOrganization!.isNotEmpty) issuingOrganization,
        if (issueDate != null && issueDate!.isNotEmpty) issueDate,
      ].join(' • ');

  factory Certification.fromJson(Map<String, dynamic> json) => Certification(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        issuingOrganization: json['issuing_organization'] as String?,
        issueDate: json['issue_date'] as String?,
      );
}

/// A saved experience row (`student_experiences`).
class Experience {
  Experience({
    required this.id,
    required this.position,
    required this.organization,
    this.startDate,
    this.endDate,
    this.description,
  });

  final int id;
  final String position;
  final String organization;
  final String? startDate;
  final String? endDate;
  final String? description;

  String get period {
    final start = startDate?.trim() ?? '';
    final end = endDate?.trim() ?? '';
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty) return start;
    if (start.isEmpty) return end;
    return '$start–$end';
  }

  factory Experience.fromJson(Map<String, dynamic> json) => Experience(
        id: (json['id'] as num).toInt(),
        position: json['position'] as String? ?? '',
        organization: json['organization'] as String? ?? '',
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        description: json['description'] as String?,
      );
}

/// Everything the review screen shows before saving.
class SetupReview {
  SetupReview({
    required this.personal,
    required this.school,
    required this.degree,
    required this.major,
    required this.skills,
    required this.certifications,
    required this.experiences,
    this.resumeName,
  });

  final PersonalDetails personal;
  final String? school;
  final String? degree;
  final String? major;
  final List<String> skills;
  final List<Certification> certifications;
  final List<Experience> experiences;
  final String? resumeName;

  factory SetupReview.fromJson(Map<String, dynamic> json) {
    final education = json['education'] as Map<String, dynamic>? ?? const {};
    final resume = json['resume'] as Map<String, dynamic>? ?? const {};

    return SetupReview(
      personal: PersonalDetails.fromJson(json['personal'] as Map<String, dynamic>? ?? const {}),
      school: education['school'] as String?,
      degree: education['degree'] as String?,
      major: education['major'] as String?,
      skills: (json['skills'] as List? ?? const []).map((e) => e.toString()).toList(),
      certifications: (json['certifications'] as List? ?? const [])
          .map((e) => Certification.fromJson(e as Map<String, dynamic>))
          .toList(),
      experiences: (json['experiences'] as List? ?? const [])
          .map((e) => Experience.fromJson(e as Map<String, dynamic>))
          .toList(),
      resumeName: resume['name'] as String?,
    );
  }
}
