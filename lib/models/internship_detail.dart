class InternshipReview {
  InternshipReview({
    required this.id,
    required this.userName,
    this.avatarUrl,
    required this.rating,
    this.content,
    this.createdAt,
  });

  final int id;
  final String userName;
  final String? avatarUrl;
  final int rating;
  final String? content;
  final String? createdAt;

  factory InternshipReview.fromJson(Map<String, dynamic> json) {
    return InternshipReview(
      id: json['id'] as int,
      userName: json['user_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      rating: json['rating'] as int? ?? 0,
      content: json['content'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// Full internship posting detail — company info, responsibilities, skills,
/// and reviews, exactly as shown on the web's internship detail page.
class InternshipDetail {
  InternshipDetail({
    required this.id,
    required this.title,
    required this.companyName,
    this.companyLogoUrl,
    this.companyAbout,
    this.location,
    required this.slotsAvailable,
    this.matchScore,
    required this.isBookmarked,
    required this.isApplied,
    required this.description,
    this.responsibilities,
    required this.skills,
    required this.reviews,
  });

  final int id;
  final String title;
  final String companyName;
  final String? companyLogoUrl;
  final String? companyAbout;
  final String? location;
  final int slotsAvailable;
  final int? matchScore;
  final bool isBookmarked;
  final bool isApplied;
  final String description;
  final List<String>? responsibilities;
  final List<String> skills;
  final List<InternshipReview> reviews;

  String get companyInitials {
    final trimmed = companyName.trim();
    if (trimmed.isEmpty) return '?';
    final words = trimmed.split(RegExp(r'\s+'));
    return words.take(2).map((w) => w[0]).join().toUpperCase();
  }

  factory InternshipDetail.fromJson(Map<String, dynamic> json) {
    return InternshipDetail(
      id: json['id'] as int,
      title: json['title'] as String,
      companyName: json['company_name'] as String,
      companyLogoUrl: json['company_logo_url'] as String?,
      companyAbout: json['company_about'] as String?,
      location: json['location'] as String?,
      slotsAvailable: json['slots_available'] as int? ?? 0,
      matchScore: json['match_score'] as int?,
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      isApplied: json['is_applied'] as bool? ?? false,
      description: json['description'] as String? ?? '',
      responsibilities: (json['responsibilities'] as List?)?.map((e) => e.toString()).toList(),
      skills: (json['skills'] as List? ?? []).map((e) => e.toString()).toList(),
      reviews: (json['reviews'] as List? ?? []).map((e) => InternshipReview.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
