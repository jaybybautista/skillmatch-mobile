import '../models/resume.dart';
import '../models/student_profile.dart';

/// Shared between ResumePreviewScreen and the PDF builder so the on-screen
/// preview and the downloaded file never drift apart.
class ResumeHeaderInfo {
  const ResumeHeaderInfo({
    required this.fullName,
    this.email,
    this.phone,
    required this.addressLine,
    this.course,
  });

  final String fullName;
  final String? email;
  final String? phone;
  final String addressLine;
  final String? course;
}

final _emptyBasicInfoSection = ResumeSection(
  id: -1,
  type: 'basic_info',
  title: 'Basic Info',
  order: 0,
  experiences: const [],
  achievements: const [],
  projects: const [],
  education: const [],
  technicalSkills: const [],
  softSkills: const [],
);

/// Mirrors the web's preview.blade.php fallback logic: prefer whatever the
/// resume's own Basic Info section has, falling back to the student's
/// profile (name/email) and course when a field is blank.
ResumeHeaderInfo computeResumeHeader(Resume resume, StudentProfile? profile) {
  final basicInfo = resume.sections
      .firstWhere(
        (s) => s.type == 'basic_info',
        orElse: () => _emptyBasicInfoSection,
      )
      .basicInfo;

  final fullName = (basicInfo?.fullName?.isNotEmpty ?? false)
      ? basicInfo!.fullName!
      : (profile?.name ?? 'Your Name');
  final email = (basicInfo?.email?.isNotEmpty ?? false)
      ? basicInfo!.email!
      : profile?.email;
  final phone = basicInfo?.phoneNumber;
  final addressLine = [
    if (basicInfo?.address?.isNotEmpty ?? false) basicInfo!.address!,
    if (basicInfo?.zipCode?.isNotEmpty ?? false) basicInfo!.zipCode!,
  ].join(', ');

  return ResumeHeaderInfo(
    fullName: fullName,
    email: email,
    phone: phone,
    addressLine: addressLine,
    course: profile?.course,
  );
}

List<ResumeSection> nonBasicInfoSections(Resume resume) {
  return resume.sections.where((s) => s.type != 'basic_info').toList()
    ..sort((a, b) => a.order.compareTo(b.order));
}
