/// Lightweight entry for the resume list screen.
class ResumeSummary {
  ResumeSummary({required this.id, required this.title, this.updatedAt});

  final int id;
  final String title;
  final String? updatedAt;

  factory ResumeSummary.fromJson(Map<String, dynamic> json) {
    return ResumeSummary(
      id: json['id'] as int,
      title: json['title'] as String,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class ResumeBasicInfo {
  ResumeBasicInfo({
    this.fullName,
    this.address,
    this.zipCode,
    this.phoneNumber,
    this.email,
  });

  final String? fullName;
  final String? address;
  final String? zipCode;
  final String? phoneNumber;
  final String? email;

  factory ResumeBasicInfo.fromJson(Map<String, dynamic> json) {
    return ResumeBasicInfo(
      fullName: json['full_name'] as String?,
      address: json['address'] as String?,
      zipCode: json['zip_code'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
    );
  }
}

class ResumeExperienceEntry {
  ResumeExperienceEntry({
    required this.id,
    required this.sectionId,
    this.jobTitle,
    this.company,
    this.address,
    this.responsibilities,
    this.periodStart,
    this.periodEnd,
  });

  final int id;
  final int sectionId;
  final String? jobTitle;
  final String? company;
  final String? address;
  final String? responsibilities;
  final String? periodStart;
  final String? periodEnd;

  factory ResumeExperienceEntry.fromJson(Map<String, dynamic> json) {
    return ResumeExperienceEntry(
      id: json['id'] as int,
      sectionId: json['section_id'] as int,
      jobTitle: json['job_title'] as String?,
      company: json['company'] as String?,
      address: json['address'] as String?,
      responsibilities: json['responsibilities'] as String?,
      periodStart: json['period_start'] as String?,
      periodEnd: json['period_end'] as String?,
    );
  }
}

class ResumeAchievementEntry {
  ResumeAchievementEntry({
    required this.id,
    required this.sectionId,
    this.title,
    this.category,
    this.location,
    this.dateText,
  });

  final int id;
  final int sectionId;
  final String? title;
  final String? category;
  final String? location;
  final String? dateText;

  factory ResumeAchievementEntry.fromJson(Map<String, dynamic> json) {
    return ResumeAchievementEntry(
      id: json['id'] as int,
      sectionId: json['section_id'] as int,
      title: json['title'] as String?,
      category: json['category'] as String?,
      location: json['location'] as String?,
      dateText: json['date_text'] as String?,
    );
  }
}

class ResumeProjectEntry {
  ResumeProjectEntry({
    required this.id,
    required this.sectionId,
    this.title,
    this.description,
  });

  final int id;
  final int sectionId;
  final String? title;
  final String? description;

  factory ResumeProjectEntry.fromJson(Map<String, dynamic> json) {
    return ResumeProjectEntry(
      id: json['id'] as int,
      sectionId: json['section_id'] as int,
      title: json['title'] as String?,
      description: json['description'] as String?,
    );
  }
}

class ResumeEducationEntry {
  ResumeEducationEntry({
    required this.id,
    required this.sectionId,
    this.degree,
    this.schoolName,
    this.startDate,
    this.endDate,
  });

  final int id;
  final int sectionId;
  final String? degree;
  final String? schoolName;
  final String? startDate;
  final String? endDate;

  factory ResumeEducationEntry.fromJson(Map<String, dynamic> json) {
    return ResumeEducationEntry(
      id: json['id'] as int,
      sectionId: json['section_id'] as int,
      degree: json['degree'] as String?,
      schoolName: json['school_name'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
    );
  }
}

class ResumeSkillEntry {
  ResumeSkillEntry({required this.id, required this.skillName});

  final int id;
  final String skillName;

  factory ResumeSkillEntry.fromJson(Map<String, dynamic> json) {
    return ResumeSkillEntry(
      id: json['id'] as int,
      skillName: json['skill_name'] as String,
    );
  }
}

class ResumeSection {
  ResumeSection({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    this.inputType,
    required this.order,
    this.content,
    this.basicInfo,
    required this.experiences,
    required this.achievements,
    required this.projects,
    required this.education,
    required this.technicalSkills,
    required this.softSkills,
  });

  final int id;
  final String type;
  final String title;
  final String? description;
  final String? inputType;
  final int order;
  final String? content;
  final ResumeBasicInfo? basicInfo;
  final List<ResumeExperienceEntry> experiences;
  final List<ResumeAchievementEntry> achievements;
  final List<ResumeProjectEntry> projects;
  final List<ResumeEducationEntry> education;
  final List<ResumeSkillEntry> technicalSkills;
  final List<ResumeSkillEntry> softSkills;

  /// Whether this section (professional_summary, or a custom text/dropdown/
  /// bullet-point section) is edited as a single free-text field.
  bool get isTextSection => type == 'professional_summary' || type == 'custom';

  factory ResumeSection.fromJson(Map<String, dynamic> json) {
    final skills = json['skills'] as Map<String, dynamic>? ?? const {};

    return ResumeSection(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      inputType: json['input_type'] as String?,
      order: json['order'] as int? ?? 0,
      content: json['content'] as String?,
      basicInfo: json['basic_info'] != null
          ? ResumeBasicInfo.fromJson(json['basic_info'] as Map<String, dynamic>)
          : null,
      experiences: (json['experiences'] as List? ?? [])
          .map((e) => ResumeExperienceEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      achievements: (json['achievements'] as List? ?? [])
          .map(
            (e) => ResumeAchievementEntry.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      projects: (json['projects'] as List? ?? [])
          .map((e) => ResumeProjectEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      education: (json['education'] as List? ?? [])
          .map((e) => ResumeEducationEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      technicalSkills: (skills['technical'] as List? ?? [])
          .map((e) => ResumeSkillEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      softSkills: (skills['soft'] as List? ?? [])
          .map((e) => ResumeSkillEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Resume {
  Resume({required this.id, required this.title, required this.sections});

  final int id;
  final String title;
  final List<ResumeSection> sections;

  factory Resume.fromJson(Map<String, dynamic> json) {
    return Resume(
      id: json['id'] as int,
      title: json['title'] as String,
      sections: (json['sections'] as List? ?? [])
          .map((e) => ResumeSection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
