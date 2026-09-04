/// One remembered search. It is the same `search_histories` row the website's
/// dropdown renders, so a search typed on either platform shows up on both.
///
/// Two shapes share this class. A typed word is plain text with nothing but
/// a [label]. A result the user actually opened carries a picture, a
/// subtitle, and somewhere to go back to.
class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.id,
    required this.kind,
    required this.label,
    this.term,
    this.entityType,
    this.entityId,
    this.subtitle,
    this.imageUrl,
    this.initials,
    this.url,
  });

  final int id;

  /// Either `term` or `entity`. The API decides which, so both platforms
  /// draw the same row the same way.
  final String kind;

  final String label;
  final String? term;
  final String? entityType;
  final int? entityId;
  final String? subtitle;
  final String? imageUrl;
  final String? initials;

  /// Where the opened result lives on the website. Mobile does not follow it
  /// (it routes by [entityType] and [entityId] instead), but it is stored
  /// so one row can serve both platforms.
  final String? url;

  bool get isEntity => kind == 'entity';

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return SearchHistoryEntry(
      id: (json['id'] as num).toInt(),
      kind: json['kind'] as String? ?? 'term',
      label: json['label'] as String? ?? '',
      term: json['term'] as String?,
      entityType: json['entity_type'] as String?,
      entityId: (json['entity_id'] as num?)?.toInt(),
      subtitle: json['subtitle'] as String?,
      imageUrl: json['image_url'] as String?,
      initials: json['initials'] as String?,
      url: json['url'] as String?,
    );
  }
}
