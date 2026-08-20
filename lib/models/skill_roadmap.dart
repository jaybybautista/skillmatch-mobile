/// One stretch of the suggested plan — "Weeks 1-3: Learn the missing
/// skills", etc. Mirrors one entry of the web's `$roadmapSteps` array.
class RoadmapStep {
  RoadmapStep({
    required this.timeframe,
    required this.title,
    required this.description,
    required this.suggestedSkills,
  });

  final String timeframe;
  final String title;
  final String description;
  final List<String> suggestedSkills;

  factory RoadmapStep.fromJson(Map<String, dynamic> json) {
    return RoadmapStep(
      timeframe: json['timeframe'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      suggestedSkills: (json['suggested_skills'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// The skills-vs-market comparison the web's Skill Roadmap page computes:
/// the student's own skills against the top skills demanded across every
/// open internship posting. Same underlying suggestions as the web — this
/// model just also carries [skillDemand], additive data the backend already
/// computed but the plain web page never surfaced.
class SkillRoadmap {
  SkillRoadmap({
    required this.possessedSkills,
    required this.suggestedSkills,
    required this.trendingSkills,
    required this.skillDemand,
    required this.steps,
  });

  final List<String> possessedSkills;
  final List<String> suggestedSkills;
  final List<String> trendingSkills;

  /// Skill label -> how many open postings ask for it.
  final Map<String, int> skillDemand;
  final List<RoadmapStep> steps;

  /// How many of the market's top trending skills the student already has,
  /// as a 0-1 fraction — purely a presentational summary of the same
  /// possessed/trending sets, not a new comparison.
  double get masteryFraction => trendingSkills.isEmpty
      ? 0
      : possessedSkills.length / trendingSkills.length;

  factory SkillRoadmap.fromJson(Map<String, dynamic> json) {
    return SkillRoadmap(
      possessedSkills: (json['possessed_skills'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      suggestedSkills: (json['suggested_skills'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      trendingSkills: (json['trending_skills'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      skillDemand: (json['skill_demand'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toInt())),
      steps: (json['steps'] as List? ?? const [])
          .map((e) => RoadmapStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
