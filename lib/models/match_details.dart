/// One row of the evaluation matrix: a required skill, the closest skill in
/// the student's profile, how they relate, and the credit that earned.
class MatrixRow {
  const MatrixRow({
    required this.required,
    required this.kind,
    required this.credit,
    this.yours,
    this.reason,
    this.fromAi = false,
  });

  final String required;
  final String? yours;

  /// exact | equivalent | related | missing
  final String kind;
  final int credit;
  final String? reason;

  /// The link was found by the SkillMatch AI model (sentence similarity).
  final bool fromAi;

  factory MatrixRow.fromJson(Map<String, dynamic> json) {
    return MatrixRow(
      required: json['required'] as String? ?? '',
      yours: json['yours'] as String?,
      kind: json['kind'] as String? ?? 'missing',
      credit: (json['credit'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
      fromAi: json['source'] == 'ai',
    );
  }
}

/// One line of the "preferred applicants" check (program / year / campus).
class PreferenceCheck {
  const PreferenceCheck({required this.label, required this.ok, this.wanted, this.yours});

  final String label;
  final bool? ok;
  final String? wanted;
  final String? yours;

  factory PreferenceCheck.fromJson(Map<String, dynamic> json) {
    return PreferenceCheck(
      label: json['label'] as String? ?? '',
      ok: json['ok'] as bool?,
      wanted: json['wanted']?.toString(),
      yours: json['yours']?.toString(),
    );
  }
}

/// A posting's preferred applicants and whether the viewer fits, as
/// `Internship::preferenceFit()` shapes it (the web's "Preferred applicants"
/// box). [fits] is null when the viewer is not a student.
class PreferenceFit {
  const PreferenceFit({required this.summary, required this.fits, required this.checks});

  final String summary;
  final bool? fits;
  final List<PreferenceCheck> checks;

  factory PreferenceFit.fromJson(Map<String, dynamic> json) {
    final checks = json['checks'] as Map<String, dynamic>? ?? const {};
    return PreferenceFit(
      summary: json['summary'] as String? ?? '',
      fits: json['fits'] as bool?,
      checks: [
        for (final c in checks.values) if (c is Map<String, dynamic>) PreferenceCheck.fromJson(c),
      ],
    );
  }
}

/// What `GET /api/internships/{id}/match-details` returns: the same
/// breakdown the web shows in "Why this match" (tier, coverage, evaluation
/// matrix, skills you have / are missing, preferred applicants, AI note).
class MatchDetails {
  const MatchDetails({
    required this.internshipId,
    required this.title,
    required this.tier,
    required this.tierLabel,
    required this.coverageHave,
    required this.coverageTotal,
    required this.coveragePercent,
    required this.summary,
    required this.rows,
    required this.creditSum,
    required this.matrixScore,
    required this.matched,
    required this.missing,
    required this.extra,
    required this.extraMore,
    required this.noSkills,
    required this.kindLabels,
    required this.creditFull,
    required this.creditRelated,
    this.companyName,
    this.score,
    this.scoreNote,
    this.aiNote,
    this.explanation,
    this.explainedAt,
    this.distance,
    this.sameCity = false,
    this.hasMoa = false,
    this.preferenceFits,
    this.preferenceSummary,
    this.preferenceChecks = const [],
  });

  final int internshipId;
  final String title;
  final String? companyName;
  final double? score;
  final String tier;
  final String tierLabel;
  final int coverageHave;
  final int coverageTotal;
  final int coveragePercent;
  final String summary;
  final List<MatrixRow> rows;
  final int creditSum;
  final int matrixScore;
  final List<MatrixRow> matched;
  final List<String> missing;
  final List<String> extra;
  final int extraMore;
  final bool noSkills;
  final Map<String, String> kindLabels;
  final int creditFull;
  final int creditRelated;
  final String? scoreNote;
  final String? aiNote;
  final String? explanation;
  final String? explainedAt;
  final String? distance;
  final bool sameCity;
  final bool hasMoa;

  /// null when the posting has no preferred criteria.
  final bool? preferenceFits;
  final String? preferenceSummary;
  final List<PreferenceCheck> preferenceChecks;

  bool get hasPreference => preferenceSummary != null || preferenceChecks.isNotEmpty;

  factory MatchDetails.fromJson(Map<String, dynamic> json) {
    final coverage = json['coverage'] as Map<String, dynamic>? ?? const {};
    final location = json['location'] as Map<String, dynamic>? ?? const {};
    final pref = json['preference'] as Map<String, dynamic>?;
    final checks = pref?['checks'] as Map<String, dynamic>? ?? const {};

    return MatchDetails(
      internshipId: (json['internship_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Internship',
      companyName: json['company_name'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      tier: json['tier'] as String? ?? 'unscored',
      tierLabel: json['tier_label'] as String? ?? 'Not scored yet',
      coverageHave: (coverage['have'] as num?)?.toInt() ?? 0,
      coverageTotal: (coverage['total'] as num?)?.toInt() ?? 0,
      coveragePercent: (coverage['percent'] as num?)?.toInt() ?? 0,
      summary: json['summary'] as String? ?? '',
      rows: [for (final r in (json['rows'] as List? ?? const [])) MatrixRow.fromJson(r as Map<String, dynamic>)],
      creditSum: (json['credit_sum'] as num?)?.toInt() ?? 0,
      matrixScore: (json['matrix_score'] as num?)?.toInt() ?? 0,
      matched: [for (final r in (json['matched'] as List? ?? const [])) MatrixRow.fromJson(r as Map<String, dynamic>)],
      missing: [for (final s in (json['missing'] as List? ?? const [])) s.toString()],
      extra: [for (final s in (json['extra'] as List? ?? const [])) s.toString()],
      extraMore: (json['extra_more'] as num?)?.toInt() ?? 0,
      noSkills: json['no_skills'] as bool? ?? false,
      kindLabels: {
        for (final e in (json['kind_labels'] as Map<String, dynamic>? ?? const {}).entries) e.key: e.value.toString(),
      },
      creditFull: (json['credit_full'] as num?)?.toInt() ?? 100,
      creditRelated: (json['credit_related'] as num?)?.toInt() ?? 70,
      scoreNote: json['score_note'] as String?,
      aiNote: json['ai_note'] as String?,
      explanation: json['explanation'] as String?,
      explainedAt: json['explained_at'] as String?,
      distance: location['distance'] as String?,
      sameCity: location['same_city'] as bool? ?? false,
      hasMoa: json['moa'] as bool? ?? false,
      preferenceFits: pref?['fits'] as bool?,
      preferenceSummary: pref?['summary'] as String?,
      preferenceChecks: [
        for (final c in checks.values) if (c is Map<String, dynamic>) PreferenceCheck.fromJson(c),
      ],
    );
  }

  MatchDetails withExplanation(String text, String? at) {
    return MatchDetails(
      internshipId: internshipId,
      title: title,
      companyName: companyName,
      score: score,
      tier: tier,
      tierLabel: tierLabel,
      coverageHave: coverageHave,
      coverageTotal: coverageTotal,
      coveragePercent: coveragePercent,
      summary: summary,
      rows: rows,
      creditSum: creditSum,
      matrixScore: matrixScore,
      matched: matched,
      missing: missing,
      extra: extra,
      extraMore: extraMore,
      noSkills: noSkills,
      kindLabels: kindLabels,
      creditFull: creditFull,
      creditRelated: creditRelated,
      scoreNote: scoreNote,
      aiNote: aiNote,
      explanation: text,
      explainedAt: at,
      distance: distance,
      sameCity: sameCity,
      hasMoa: hasMoa,
      preferenceFits: preferenceFits,
      preferenceSummary: preferenceSummary,
      preferenceChecks: preferenceChecks,
    );
  }
}

/// One page of a lazily loaded internship list.
class InternshipPage<T> {
  const InternshipPage({required this.items, required this.hasMore, required this.page});

  final List<T> items;
  final bool hasMore;
  final int page;
}
