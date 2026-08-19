/// A single assessment on the company side — shown as a card in
/// [AssessmentLibraryScreen] and authored via [CreateAssessmentScreen].
///
/// TODO: static placeholder data — there is no company-assessments endpoint
/// on the backend yet. Swap for a real fetch/create/update/delete once one
/// exists (mirrors the same caveat on [CompanyPosting]).
class CompanyAssessment {
  const CompanyAssessment({
    required this.title,
    required this.description,
    required this.questionCount,
    required this.timeLimitMinutes,
    required this.submissionCount,
  });

  final String title;
  final String description;
  final int questionCount;
  final int timeLimitMinutes;
  final int submissionCount;
}

const placeholderCompanyAssessments = [
  CompanyAssessment(
    title: 'UI Design Fundamentals',
    description: 'Evaluating core visual principles, accessibility standards, and prototyping speed.',
    questionCount: 24,
    timeLimitMinutes: 45,
    submissionCount: 0,
  ),
  CompanyAssessment(
    title: 'React Basics',
    description: 'Testing hooks, component lifecycle, and state management proficiency.',
    questionCount: 18,
    timeLimitMinutes: 30,
    submissionCount: 0,
  ),
  CompanyAssessment(
    title: 'Python Scripting',
    description: 'Automation focus, data parsing, and efficient logic structures.',
    questionCount: 12,
    timeLimitMinutes: 20,
    submissionCount: 0,
  ),
];
