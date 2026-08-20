/// A student, company, or coordinator found by people search — the mobile
/// twin of a non-internship row in the web's global search results.
class PersonSearchResult {
  PersonSearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.description,
    required this.badge,
    required this.avatarUrl,
    required this.initials,
    required this.screen,
    required this.screenParams,
  });

  /// 'student', 'company', or 'coordinator'.
  final String type;

  /// The Student/Company/Coordinator row's own id — not the user id.
  final int id;

  final String title;
  final String subtitle;
  final String meta;
  final String description;
  final String? badge;
  final String? avatarUrl;
  final String initials;

  /// Where tapping this result goes, resolved server-side by
  /// ProfileLinkService — the same destination the review author link uses.
  final String? screen;
  final Map<String, dynamic> screenParams;

  bool get isNavigable => screen != null;

  factory PersonSearchResult.fromJson(Map<String, dynamic> json) {
    return PersonSearchResult(
      type: json['type'] as String? ?? 'student',
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      meta: json['meta'] as String? ?? '',
      description: json['description'] as String? ?? '',
      badge: json['badge'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      initials: json['initials'] as String? ?? '?',
      screen: json['screen'] as String?,
      screenParams:
          (json['screen_params'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
