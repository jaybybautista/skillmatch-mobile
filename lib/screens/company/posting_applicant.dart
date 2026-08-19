/// A candidate who applied to a [CompanyPosting] — shown as a card on
/// [PostingApplicantsScreen].
///
/// TODO: static placeholder data — there is no company-applicants endpoint
/// on the backend yet (same caveat as [CompanyPosting]/[CompanyAssessment]).
/// `matchPercent`/`matchReason` stand in for what would eventually be an
/// AI-generated match explanation from the server.
class PostingApplicant {
  PostingApplicant({
    required this.name,
    required this.location,
    required this.skills,
    required this.matchPercent,
    required this.matchReason,
    this.bookmarked = false,
  });

  final String name;
  final String location;
  final List<String> skills;
  final int matchPercent;
  final String matchReason;
  bool bookmarked;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Same placeholder list regardless of which posting it's shown under —
/// there's no per-posting applicants endpoint to distinguish them yet.
List<PostingApplicant> placeholderApplicants() => [
  PostingApplicant(
    name: 'Gwononah Salvi',
    location: 'New York, NY',
    skills: const ['Figma', 'Prototyping', 'User Research'],
    matchPercent: 94,
    matchReason:
        'Gwononah has led 3 end-to-end fintech projects that align perfectly with your current roadmap.',
  ),
  PostingApplicant(
    name: 'Marcus Kaleb',
    location: 'New York, NY',
    skills: const ['Figma', 'Prototyping', 'User Research'],
    matchPercent: 89,
    matchReason:
        'Marcus has shipped 2 consumer-facing design systems and consistently tests high on usability heuristics.',
  ),
  PostingApplicant(
    name: 'Priya Fernandez',
    location: 'Austin, TX',
    skills: const ['Figma', 'Wireframing', 'Accessibility'],
    matchPercent: 82,
    matchReason:
        'Priya specializes in accessible design patterns, matching the WCAG requirements called out in this posting.',
  ),
  PostingApplicant(
    name: 'Daniel Ortiz',
    location: 'Seattle, WA',
    skills: const ['User Research', 'Prototyping'],
    matchPercent: 76,
    matchReason:
        'Daniel has strong user-research fundamentals but limited high-fidelity prototyping experience so far.',
  ),
];
