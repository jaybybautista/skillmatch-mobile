import '../core/json_parse.dart';

/// An internship posting, optionally scored against the current student's
/// skills via the backend's SkillMatchService (the same cosine-similarity AI
/// endpoint — or its local fallback — that powers the web dashboard).
/// The three orderings the web offers on its internships page.
enum InternshipFilter {
  all('all', 'All'),
  topMatches('top_matches', 'Top Matches'),
  proximity('proximity', 'Proximity Based');

  const InternshipFilter(this.value, this.label);

  /// The `filter` query value the API expects.
  final String value;
  final String label;
}

class Internship {
  Internship({
    required this.id,
    required this.title,
    required this.companyName,
    this.companyId,
    this.companyLogoUrl,
    this.companyHasMoa = false,
    this.location,
    required this.slotsAvailable,
    this.availabilityState = 'open',
    this.availabilityLabel = '',
    this.isAccepting = true,
    required this.description,
    this.matchScore,
    this.distanceKm,
    this.distanceLabel,
    this.matchReason,
    required this.matchedSkills,
    required this.missingSkills,
    required this.skills,
    required this.isBookmarked,
    required this.isApplied,
  });

  final int id;
  final String title;
  final String companyName;

  /// The owning company's row id. Used by search to tell a company its own
  /// posting apart from someone else's.
  final int? companyId;
  final String? companyLogoUrl;

  /// The company has a signed Memorandum of Agreement with the school, so
  /// a placement there is officially sanctioned. Shown as a "With MOA" tag.
  final bool companyHasMoa;
  final String? location;
  final int slotsAvailable;

  /// Bukas pa ba ito. Sa server nagmumula ang tatlong ito, hindi kinukuwenta
  /// dito - para iisa ang sagot ng web at ng app.
  ///
  /// [availabilityState] ay open, full o closed. Magkaiba ang huling dalawa:
  /// pwedeng magbukas ulit ang napuno kapag may umatras, pero yung sinarado,
  /// sadyang isinara.
  final String availabilityState;
  final String availabilityLabel;
  final bool isAccepting;

  final String description;
  final int? matchScore;
  final String? matchReason;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final List<String> skills;
  final bool isBookmarked;
  final bool isApplied;

  /// Distance from the student, only computed when the proximity filter is
  /// active — the API skips the geocoding otherwise, as the web does.
  final double? distanceKm;

  /// The API's human-readable form: "Within 1 km", "12.4 km away", …
  final String? distanceLabel;

  String get companyInitials {
    final trimmed = companyName.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));
    return words.take(2).map((w) => w[0]).join().toUpperCase();
  }

  /// What to show as the card's body text: the AI-generated match reason
  /// when a score exists, otherwise the internship's own description.
  String get displayDescription => matchReason ?? description;

  factory Internship.fromJson(Map<String, dynamic> json) {
    return Internship(
      id: json['id'] as int,
      title: json['title'] as String,
      companyName: json['company_name'] as String,
      companyId: asIntOrNull(json['company_id']),
      companyLogoUrl: json['company_logo_url'] as String?,
      companyHasMoa: json['company_has_moa'] as bool? ?? false,
      location: json['location'] as String?,
      slotsAvailable: json['slots_available'] as int? ?? 0,
      availabilityState: json['availability_state'] as String? ?? 'open',
      availabilityLabel: json['availability_label'] as String? ?? '',
      isAccepting: json['is_accepting'] as bool? ?? true,
      description: json['description'] as String? ?? '',
      matchScore: json['match_score'] as int?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      distanceLabel: json['distance_formatted'] as String?,
      matchReason: json['match_reason'] as String?,
      matchedSkills: (json['matched_skills'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      missingSkills: (json['missing_skills'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      skills: (json['skills'] as List? ?? []).map((e) => e.toString()).toList(),
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      isApplied: json['is_applied'] as bool? ?? false,
    );
  }
}
